///|
pub(all) suberror TransportError {
  InvalidDeviceInfo(String)
  InvalidControlRequest(String)
  InvalidEndpoint(Int)
  InvalidLength(Int)
  Timeout
  Disconnected
  Closed
  ShortTransfer(Int, Int)
  UnsupportedRequest(Int)
  Failure(String)
} derive(Eq, Debug)

///|
fn valid_u8(value : Int) -> Bool {
  value >= 0 && value <= 255
}

///|
fn valid_u16(value : Int) -> Bool {
  value >= 0 && value <= 65535
}

///|
pub struct DeviceInfo {
  priv vendor_id : Int
  priv product_id : Int
  priv bulk_in_endpoint : Int?
  priv bulk_out_endpoint : Int?
} derive(Eq, Debug)

///|
pub fn DeviceInfo::new(
  vendor_id~ : Int,
  product_id~ : Int,
  bulk_in_endpoint~ : Int?,
  bulk_out_endpoint~ : Int?,
) -> DeviceInfo raise TransportError {
  if !valid_u16(vendor_id) || !valid_u16(product_id) {
    raise InvalidDeviceInfo("USB vendor and product IDs must fit in 16 bits")
  }
  match bulk_in_endpoint {
    Some(endpoint) if !valid_u8(endpoint) => raise InvalidEndpoint(endpoint)
    _ => ()
  }
  match bulk_out_endpoint {
    Some(endpoint) if !valid_u8(endpoint) => raise InvalidEndpoint(endpoint)
    _ => ()
  }
  { vendor_id, product_id, bulk_in_endpoint, bulk_out_endpoint }
}

///|
pub fn DeviceInfo::vendor_id(self : DeviceInfo) -> Int {
  self.vendor_id
}

///|
pub fn DeviceInfo::product_id(self : DeviceInfo) -> Int {
  self.product_id
}

///|
pub fn DeviceInfo::bulk_in_endpoint(self : DeviceInfo) -> Int? {
  self.bulk_in_endpoint
}

///|
pub fn DeviceInfo::bulk_out_endpoint(self : DeviceInfo) -> Int? {
  self.bulk_out_endpoint
}

///|
pub fn DeviceInfo::has_bulk_endpoints(self : DeviceInfo) -> Bool {
  self.bulk_in_endpoint is Some(_) && self.bulk_out_endpoint is Some(_)
}

///|
pub struct ControlTransfer {
  priv request_type : Int
  priv request : Int
  priv value : Int
  priv index : Int
  priv length : Int
  priv data : Bytes
} derive(Eq, Debug)

///|
pub fn ControlTransfer::in_request(
  request_type~ : Int,
  request~ : Int,
  value~ : Int,
  index~ : Int,
  length~ : Int,
) -> ControlTransfer raise TransportError {
  validate_control_header(request_type, request, value, index)
  if length < 0 || length > 65535 {
    raise InvalidLength(length)
  }
  { request_type, request, value, index, length, data: b"" }
}

///|
pub fn ControlTransfer::out_request(
  request_type~ : Int,
  request~ : Int,
  value~ : Int,
  index~ : Int,
  data~ : Bytes,
) -> ControlTransfer raise TransportError {
  validate_control_header(request_type, request, value, index)
  if data.length() > 65535 {
    raise InvalidLength(data.length())
  }
  { request_type, request, value, index, length: data.length(), data }
}

///|
fn validate_control_header(
  request_type : Int,
  request : Int,
  value : Int,
  index : Int,
) -> Unit raise TransportError {
  if !valid_u8(request_type) {
    raise InvalidControlRequest("request type must fit in one byte")
  }
  if !valid_u8(request) {
    raise InvalidControlRequest("request must fit in one byte")
  }
  if !valid_u16(value) || !valid_u16(index) {
    raise InvalidControlRequest("value and index must fit in 16 bits")
  }
}

///|
pub fn ControlTransfer::request_type(self : ControlTransfer) -> Int {
  self.request_type
}

///|
pub fn ControlTransfer::request(self : ControlTransfer) -> Int {
  self.request
}

///|
pub fn ControlTransfer::value(self : ControlTransfer) -> Int {
  self.value
}

///|
pub fn ControlTransfer::index(self : ControlTransfer) -> Int {
  self.index
}

///|
pub fn ControlTransfer::length(self : ControlTransfer) -> Int {
  self.length
}

///|
pub fn ControlTransfer::data(self : ControlTransfer) -> Bytes {
  self.data
}

///|
pub fn ControlTransfer::is_in(self : ControlTransfer) -> Bool {
  self.request_type >= 128
}

///|
pub(open) trait UsbTransport {
  fn info(Self) -> DeviceInfo raise TransportError
  fn control(Self, ControlTransfer, Int) -> Bytes raise TransportError
  fn bulk_write(Self, Int, Bytes, Int) -> Int raise TransportError
  fn bulk_read(Self, Int, Int, Int) -> Bytes raise TransportError
  fn close(Self) -> Unit raise TransportError
}
