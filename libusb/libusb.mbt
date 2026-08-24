///|
const STATUS_CLOSED : Int = -1002

///|
const STATUS_DISCONNECTED : Int = -1003

///|
const STATUS_TIMEOUT : Int = -1004

///|
const STATUS_NOT_FOUND : Int = -1006

///|
const STATUS_UNSUPPORTED : Int = -1007

///|
const STATUS_RUNTIME_MISSING : Int = -1009

///|
const STATUS_INVALID_ENDPOINT : Int = -1013

///|
const STATUS_INVALID_LENGTH : Int = -1014

///|
fn valid_usb_id(value : Int) -> Bool {
  value >= 0 && value <= 0xFFFF
}

///|
/// An explicit USB allowlist entry. The selector is exact for ordinary
/// devices; `accessory()` allows only the six official AOA accessory PIDs.
pub struct LibusbDeviceSelector {
  priv vendor_id : Int
  priv product_id : Int
  priv accessory_mode : Bool
} derive(Eq, Debug)

///|
pub fn LibusbDeviceSelector::new(
  vendor_id~ : Int,
  product_id~ : Int,
) -> LibusbDeviceSelector raise @transport.TransportError {
  if !valid_usb_id(vendor_id) || !valid_usb_id(product_id) {
    raise @transport.InvalidDeviceInfo(
      "USB selector VID and PID must fit in 16 bits",
    )
  }
  { vendor_id, product_id, accessory_mode: false }
}

///|
/// Selects an Android device already in AOA accessory mode. No other vendor
/// or product IDs are accepted by the native enumerator.
pub fn LibusbDeviceSelector::accessory() -> LibusbDeviceSelector {
  { vendor_id: 0x18D1, product_id: -1, accessory_mode: true }
}

///|
pub fn LibusbDeviceSelector::vendor_id(self : LibusbDeviceSelector) -> Int {
  self.vendor_id
}

///|
pub fn LibusbDeviceSelector::product_id(self : LibusbDeviceSelector) -> Int? {
  if self.accessory_mode {
    None
  } else {
    Some(self.product_id)
  }
}

///|
pub fn LibusbDeviceSelector::is_accessory_mode(
  self : LibusbDeviceSelector,
) -> Bool {
  self.accessory_mode
}

///|
pub struct LibusbTransport {
  priv handle : NativeHandle
}

///|
fn native_error(handle : NativeHandle) -> String {
  @utf8.decode_lossy(native_last_error(handle))
}

///|
fn require_status(
  handle : NativeHandle,
  status : Int,
) -> Unit raise @transport.TransportError {
  if status >= 0 {
    return
  }
  match status {
    STATUS_CLOSED => raise @transport.Closed
    STATUS_DISCONNECTED => raise @transport.Disconnected
    STATUS_TIMEOUT => raise @transport.Timeout
    STATUS_INVALID_LENGTH => raise @transport.InvalidLength(status)
    STATUS_UNSUPPORTED => raise @transport.Failure(native_error(handle))
    STATUS_NOT_FOUND => raise @transport.Failure(native_error(handle))
    STATUS_RUNTIME_MISSING => raise @transport.Failure(native_error(handle))
    _ => raise @transport.Failure(native_error(handle))
  }
}

///|
fn require_endpoint_status(
  handle : NativeHandle,
  endpoint : Int,
  status : Int,
) -> Unit raise @transport.TransportError {
  if status == STATUS_INVALID_ENDPOINT {
    raise @transport.InvalidEndpoint(endpoint)
  }
  require_status(handle, status)
}

///|
fn endpoint_option(value : Int) -> Int? {
  if value < 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn read_info(
  handle : NativeHandle,
) -> @transport.DeviceInfo raise @transport.TransportError {
  let status = native_info(handle)
  require_status(handle, status)
  @transport.DeviceInfo::new(
    vendor_id=native_vendor_id(handle),
    product_id=native_product_id(handle),
    bulk_in_endpoint=endpoint_option(native_bulk_in_endpoint(handle)),
    bulk_out_endpoint=endpoint_option(native_bulk_out_endpoint(handle)),
  )
}

///|
pub fn LibusbTransport::runtime_available() -> Bool {
  native_runtime_available()
}

///|
/// Returns a dependency diagnostic without opening a USB device. A false
/// result means that opening a transport cannot succeed on this host.
pub fn LibusbTransport::runtime_diagnostic() -> String {
  @utf8.decode_lossy(native_runtime_diagnostic())
}

///|
pub fn LibusbTransport::open(
  selector : LibusbDeviceSelector,
) -> LibusbTransport raise @transport.TransportError {
  let handle = native_new()
  let status = native_open(
    handle,
    selector.vendor_id,
    selector.product_id,
    selector.accessory_mode,
  )
  require_status(handle, status)
  { handle, }
}

///|
/// Re-enumerates the allowlisted device. This is useful after a caller has
/// triggered AOA start outside the session wrapper.
pub fn LibusbTransport::refresh(
  self : LibusbTransport,
) -> Unit raise @transport.TransportError {
  require_status(self.handle, native_refresh(self.handle))
}

///|
pub impl @transport.UsbTransport for LibusbTransport with fn info(self) {
  read_info(self.handle)
}

///|
pub impl @transport.UsbTransport for LibusbTransport with fn control(
  self,
  request,
  timeout_ms,
) {
  if timeout_ms <= 0 {
    raise @transport.Failure("control transfer timeout must be positive")
  }
  let length = request.length()
  let data = if request.is_in() {
    Bytes::make(length, b'\x00')
  } else {
    request.data()
  }
  let actual = native_control(
    self.handle,
    request.request_type(),
    request.request(),
    request.value(),
    request.index(),
    data,
    length,
    timeout_ms,
  )
  require_status(self.handle, actual)
  if request.is_in() {
    data.view(end=actual).to_owned()
  } else {
    b""
  }
}

///|
pub impl @transport.UsbTransport for LibusbTransport with fn bulk_write(
  self,
  endpoint,
  payload,
  timeout_ms,
) {
  if endpoint < 0 || endpoint > 0xFF {
    raise @transport.InvalidEndpoint(endpoint)
  }
  if timeout_ms <= 0 {
    raise @transport.Failure("bulk write timeout must be positive")
  }
  let actual = native_bulk_write(
    self.handle,
    endpoint,
    payload,
    payload.length(),
    timeout_ms,
  )
  require_endpoint_status(self.handle, endpoint, actual)
  actual
}

///|
pub impl @transport.UsbTransport for LibusbTransport with fn bulk_read(
  self,
  endpoint,
  max_length,
  timeout_ms,
) {
  if endpoint < 0 || endpoint > 0xFF {
    raise @transport.InvalidEndpoint(endpoint)
  }
  if max_length <= 0 {
    raise @transport.InvalidLength(max_length)
  }
  if timeout_ms <= 0 {
    raise @transport.Failure("bulk read timeout must be positive")
  }
  let data = Bytes::make(max_length, b'\x00')
  let actual = native_bulk_read(
    self.handle,
    endpoint,
    data,
    max_length,
    timeout_ms,
  )
  require_endpoint_status(self.handle, endpoint, actual)
  data.view(end=actual).to_owned()
}

///|
pub impl @transport.UsbTransport for LibusbTransport with fn close(self) {
  require_status(self.handle, native_close(self.handle))
}
