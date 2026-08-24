///|
pub(all) enum FakeFault {
  Timeout
  Disconnected
  ShortWrite(Int)
  ShortRead(Int)
} derive(Eq, Debug)

///|
priv struct FakeState {
  mut info : @transport.DeviceInfo
  protocol : @madk.AoaProtocolVersion
  mut audio_mode : @madk.AudioMode
  mut bulk_enabled : Bool
  mut closed : Bool
  mut disconnected : Bool
  mut fault : FakeFault?
  control_log : Array[@transport.ControlTransfer]
  bulk_writes : Array[Bytes]
  mut bulk_reads : Array[Bytes]
  hid_descriptors : Map[Int, Array[Bytes]]
  hid_events : Map[Int, Array[Bytes]]
}

///|
pub struct FakeTransport {
  priv state : Ref[FakeState]
}

///|
fn initial_device_info() -> @transport.DeviceInfo {
  @transport.DeviceInfo::new(
    vendor_id=0x1234,
    product_id=1,
    bulk_in_endpoint=None,
    bulk_out_endpoint=None,
  ) catch {
    _ => abort("invalid simulator device descriptor")
  }
}

///|
fn accessory_device_info(
  protocol : @madk.AoaProtocolVersion,
  audio_mode : @madk.AudioMode,
  bulk_enabled : Bool,
) -> @transport.DeviceInfo {
  let product_id = match protocol {
    V1 => @madk.accessory_product_id
    V2 =>
      match audio_mode {
        Disabled => @madk.accessory_product_id
        Pcm44100Stereo => @madk.accessory_audio_product_id
      }
  }
  @transport.DeviceInfo::new(
    vendor_id=@madk.aoa_vendor_id,
    product_id~,
    bulk_in_endpoint=if bulk_enabled { Some(0x81) } else { None },
    bulk_out_endpoint=if bulk_enabled { Some(0x02) } else { None },
  ) catch {
    _ => abort("invalid simulator accessory descriptor")
  }
}

///|
pub fn FakeTransport::new(
  protocol~ : @madk.AoaProtocolVersion,
) -> FakeTransport {
  {
    state: Ref({
      info: initial_device_info(),
      protocol,
      audio_mode: Disabled,
      bulk_enabled: true,
      closed: false,
      disconnected: false,
      fault: None,
      control_log: [],
      bulk_writes: [],
      bulk_reads: [],
      hid_descriptors: Map([]),
      hid_events: Map([]),
    }),
  }
}

///|
/// Creates an AOAv2 control-only device. This models HID-capable accessory
/// mode without an application bulk interface.
pub fn FakeTransport::new_control_only(
  protocol~ : @madk.AoaProtocolVersion,
) -> FakeTransport {
  let fake = FakeTransport::new(protocol~)
  fake.state.val.bulk_enabled = false
  fake
}

///|
/// Creates a device that is already in accessory mode. The session must not
/// infer the negotiated protocol from the product ID.
pub fn FakeTransport::new_already_accessory() -> FakeTransport {
  let fake = FakeTransport::new(protocol=V2)
  fake.state.val.info = accessory_device_info(V2, Disabled, true)
  fake
}

///|
pub fn FakeTransport::set_next_fault(
  self : FakeTransport,
  fault : FakeFault,
) -> Unit {
  self.state.val.fault = Some(fault)
}

///|
pub fn FakeTransport::disconnect(self : FakeTransport) -> Unit {
  self.state.val.disconnected = true
}

///|
pub fn FakeTransport::queue_bulk_read(
  self : FakeTransport,
  payload : Bytes,
) -> Unit {
  self.state.val.bulk_reads.push(payload)
}

///|
pub fn FakeTransport::control_log(
  self : FakeTransport,
) -> Array[@transport.ControlTransfer] {
  self.state.val.control_log
}

///|
pub fn FakeTransport::bulk_writes(self : FakeTransport) -> Array[Bytes] {
  self.state.val.bulk_writes
}

///|
pub fn FakeTransport::hid_descriptor_chunks(
  self : FakeTransport,
  identifier : Int,
) -> Array[Bytes] {
  match self.state.val.hid_descriptors.get(identifier) {
    Some(chunks) => chunks
    None => []
  }
}

///|
pub fn FakeTransport::hid_events(
  self : FakeTransport,
  identifier : Int,
) -> Array[Bytes] {
  match self.state.val.hid_events.get(identifier) {
    Some(events) => events
    None => []
  }
}

///|
pub fn FakeTransport::is_closed(self : FakeTransport) -> Bool {
  self.state.val.closed
}

///|
fn FakeTransport::ensure_open(
  self : FakeTransport,
) -> Unit raise @transport.TransportError {
  if self.state.val.closed {
    raise Closed
  }
  if self.state.val.disconnected {
    raise Disconnected
  }
}

///|
fn FakeTransport::take_fault(self : FakeTransport) -> FakeFault? {
  let fault = self.state.val.fault
  self.state.val.fault = None
  fault
}

///|
fn copy_prefix(payload : Bytes, length : Int) -> Bytes {
  payload.view(start=0, end=length).to_owned()
}

///|
fn FakeTransport::record_hid_descriptor(
  self : FakeTransport,
  identifier : Int,
  payload : Bytes,
) -> Unit {
  let chunks = self.state.val.hid_descriptors.get_or_init(identifier, () => [])
  chunks.push(payload)
}

///|
fn FakeTransport::record_hid_event(
  self : FakeTransport,
  identifier : Int,
  payload : Bytes,
) -> Unit {
  let events = self.state.val.hid_events.get_or_init(identifier, () => [])
  events.push(payload)
}

///|
pub impl @transport.UsbTransport for FakeTransport with fn info(self) {
  self.ensure_open()
  self.state.val.info
}

///|
pub impl @transport.UsbTransport for FakeTransport with fn control(
  self,
  request,
  _timeout_ms,
) {
  self.ensure_open()
  self.state.val.control_log.push(request)
  match self.take_fault() {
    Some(Timeout) => raise Timeout
    Some(Disconnected) => raise Disconnected
    Some(ShortRead(_)) | Some(ShortWrite(_)) => b""
    None => {
      let request_code = request.request()
      if request_code == @madk.accessory_get_protocol {
        Bytes::from_array([
          request_protocol_byte(self.state.val.protocol),
          b'\x00',
        ])
      } else if request_code == @madk.accessory_send_string {
        b""
      } else if request_code == @madk.accessory_set_audio_mode {
        self.state.val.audio_mode = if request.value() == 1 {
          Pcm44100Stereo
        } else {
          Disabled
        }
        b""
      } else if request_code == @madk.accessory_start {
        self.state.val.info = accessory_device_info(
          self.state.val.protocol,
          self.state.val.audio_mode,
          self.state.val.bulk_enabled,
        )
        b""
      } else if request_code == @madk.accessory_register_hid {
        b""
      } else if request_code == @madk.accessory_unregister_hid {
        b""
      } else if request_code == @madk.accessory_set_hid_report_desc {
        self.record_hid_descriptor(request.value(), request.data())
        b""
      } else if request_code == @madk.accessory_send_hid_event {
        self.record_hid_event(request.value(), request.data())
        b""
      } else {
        raise UnsupportedRequest(request_code)
      }
    }
  }
}

///|
fn request_protocol_byte(protocol : @madk.AoaProtocolVersion) -> Byte {
  protocol.wire_value().to_byte()
}

///|
pub impl @transport.UsbTransport for FakeTransport with fn bulk_write(
  self,
  endpoint,
  payload,
  _timeout_ms,
) {
  self.ensure_open()
  match self.state.val.info.bulk_out_endpoint() {
    Some(expected) if endpoint == expected => ()
    _ => raise InvalidEndpoint(endpoint)
  }
  match self.take_fault() {
    Some(Timeout) => raise Timeout
    Some(Disconnected) => raise Disconnected
    Some(ShortWrite(length)) => {
      let actual = if length < payload.length() {
        length
      } else {
        payload.length()
      }
      self.state.val.bulk_writes.push(copy_prefix(payload, actual))
      actual
    }
    Some(ShortRead(_)) | None => {
      self.state.val.bulk_writes.push(payload)
      payload.length()
    }
  }
}

///|
pub impl @transport.UsbTransport for FakeTransport with fn bulk_read(
  self,
  endpoint,
  max_length,
  _timeout_ms,
) {
  self.ensure_open()
  if max_length <= 0 {
    raise InvalidLength(max_length)
  }
  match self.state.val.info.bulk_in_endpoint() {
    Some(expected) if endpoint == expected => ()
    _ => raise InvalidEndpoint(endpoint)
  }
  let payload = match self.state.val.bulk_reads.get(0) {
    Some(payload) => payload
    None => raise Timeout
  }
  self.state.val.bulk_reads = self.state.val.bulk_reads[1:].to_owned()
  let limit = match self.take_fault() {
    Some(Timeout) => raise Timeout
    Some(Disconnected) => raise Disconnected
    Some(ShortRead(length)) =>
      if length < max_length {
        length
      } else {
        max_length
      }
    Some(ShortWrite(length)) =>
      if length < max_length {
        length
      } else {
        max_length
      }
    None => max_length
  }
  let actual = if payload.length() < limit { payload.length() } else { limit }
  copy_prefix(payload, actual)
}

///|
pub impl @transport.UsbTransport for FakeTransport with fn close(self) {
  if !self.state.val.closed {
    self.state.val.closed = true
  }
}
