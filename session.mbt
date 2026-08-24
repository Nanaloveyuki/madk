///|
priv struct HidRegistration {
  total_length : Int
  descriptor_ready : Bool
}

///|
pub struct HidDevice {
  priv identifier : Int
} derive(Eq, Debug)

///|
pub fn HidDevice::identifier(self : HidDevice) -> Int {
  self.identifier
}

///|
pub struct AoaSession {
  priv transport : &@transport.UsbTransport
  priv mut info : @transport.DeviceInfo
  priv mut state : AoaState
  priv mut protocol : AoaProtocolVersion?
  priv mut audio_mode : AudioMode
  priv hid_devices : Map[Int, HidRegistration]
}

///|
fn transport_info(
  transport : &@transport.UsbTransport,
) -> @transport.DeviceInfo raise AoaError {
  transport.info() catch {
    error => raise Transport(error)
  }
}

///|
fn transport_control(
  transport : &@transport.UsbTransport,
  request : @transport.ControlTransfer,
  timeout_ms : Int,
) -> Bytes raise AoaError {
  transport.control(request, timeout_ms) catch {
    error => raise Transport(error)
  }
}

///|
fn transport_bulk_write(
  transport : &@transport.UsbTransport,
  endpoint : Int,
  payload : Bytes,
  timeout_ms : Int,
) -> Int raise AoaError {
  transport.bulk_write(endpoint, payload, timeout_ms) catch {
    error => raise Transport(error)
  }
}

///|
fn transport_bulk_read(
  transport : &@transport.UsbTransport,
  endpoint : Int,
  max_length : Int,
  timeout_ms : Int,
) -> Bytes raise AoaError {
  transport.bulk_read(endpoint, max_length, timeout_ms) catch {
    error => raise Transport(error)
  }
}

///|
fn transport_close(transport : &@transport.UsbTransport) -> Unit raise AoaError {
  transport.close() catch {
    error => raise Transport(error)
  }
}

///|
pub fn AoaSession::new(
  transport : &@transport.UsbTransport,
) -> AoaSession raise AoaError {
  let info = transport_info(transport)
  let in_accessory_mode = info.vendor_id() == aoa_vendor_id &&
    is_accessory_product(info.product_id())
  if in_accessory_mode && info.has_bulk_endpoints() {
    {
      transport,
      info,
      state: BulkReady,
      // AOAv2 keeps the AOAv1 accessory product IDs. A device already in
      // accessory mode cannot be classified by PID alone, so do not claim a
      // protocol version that was not negotiated by this session.
      protocol: None,
      audio_mode: Disabled,
      hid_devices: Map([]),
    }
  } else {
    {
      transport,
      info,
      state: Detected,
      protocol: None,
      audio_mode: Disabled,
      hid_devices: Map([]),
    }
  }
}

///|
pub fn AoaSession::state(self : AoaSession) -> AoaState {
  self.state
}

///|
pub fn AoaSession::protocol(self : AoaSession) -> AoaProtocolVersion? {
  self.protocol
}

///|
pub fn AoaSession::device_info(self : AoaSession) -> @transport.DeviceInfo {
  self.info
}

///|
pub fn AoaSession::audio_mode(self : AoaSession) -> AudioMode {
  self.audio_mode
}

///|
pub fn AoaSession::audio_capability(self : AoaSession) -> AudioCapability {
  match self.protocol {
    Some(V2) => Pcm44100Stereo
    _ => Unsupported
  }
}

///|
pub fn AoaSession::audio_is_active(self : AoaSession) -> Bool {
  self.audio_mode == Pcm44100Stereo && product_has_audio(self.info.product_id())
}

///|
pub fn AoaSession::supports(self : AoaSession, feature : AoaFeature) -> Bool {
  match feature {
    Bulk => self.state == BulkReady
    Hid | Audio =>
      match self.protocol {
        Some(V2) => self.state != Closed
        _ => false
      }
  }
}

///|
pub fn AoaSession::probe(
  self : AoaSession,
) -> AoaProtocolVersion raise AoaError {
  match self.state {
    Detected => ()
    _ => raise InvalidState("probe requires the Detected state")
  }
  let request = @transport.ControlTransfer::in_request(
    request_type=usb_vendor_device_in,
    request=accessory_get_protocol,
    value=0,
    index=0,
    length=2,
  ) catch {
    error => raise Transport(error)
  }
  let response = transport_control(
    self.transport,
    request,
    default_control_timeout_ms,
  )
  if response.length() < 2 {
    raise ShortTransfer(2, response.length())
  }
  let wire_value = response[0].to_int() + response[1].to_int() * 256
  let protocol = match wire_value {
    1 => V1
    2 => V2
    _ => raise UnsupportedProtocol(wire_value)
  }
  self.protocol = Some(protocol)
  self.state = Probed(protocol)
  protocol
}

///|
fn encode_identity_field(value : String) -> Bytes {
  let encoded = @utf8.encode(value, bom=false)
  let output : Array[Byte] = []
  for byte in encoded {
    output.push(byte)
  }
  output.push(b'\x00')
  Bytes::from_array(output)
}

///|
fn AoaSession::send_identity_field(
  self : AoaSession,
  index : Int,
  value : String,
) -> Unit raise AoaError {
  let request = @transport.ControlTransfer::out_request(
    request_type=usb_vendor_device_out,
    request=accessory_send_string,
    value=0,
    index~,
    data=encode_identity_field(value),
  ) catch {
    error => raise Transport(error)
  }
  ignore(transport_control(self.transport, request, default_control_timeout_ms))
}

///|
fn AoaSession::set_audio_mode_internal(
  self : AoaSession,
  mode : AudioMode,
) -> Unit raise AoaError {
  let should_send = match mode {
    Disabled =>
      match self.protocol {
        Some(V2) => true
        _ => false
      }
    Pcm44100Stereo =>
      match self.protocol {
        Some(V2) => true
        _ => raise UnsupportedFeature(Audio)
      }
  }
  if should_send {
    let value = match mode {
      Disabled => 0
      Pcm44100Stereo => 1
    }
    let request = @transport.ControlTransfer::out_request(
      request_type=usb_vendor_device_out,
      request=accessory_set_audio_mode,
      value~,
      index=0,
      data=b"",
    ) catch {
      error => raise Transport(error)
    }
    ignore(
      transport_control(self.transport, request, default_control_timeout_ms),
    )
  }
  self.audio_mode = mode
}

///|
pub fn AoaSession::configure(
  self : AoaSession,
  identity : AoaIdentity,
  audio_mode? : AudioMode = Disabled,
) -> Unit raise AoaError {
  match self.state {
    Probed(_) => ()
    _ => raise InvalidState("configure requires the Probed state")
  }
  self.send_identity_field(0, identity.manufacturer())
  self.send_identity_field(1, identity.model())
  self.send_identity_field(2, identity.description())
  self.send_identity_field(3, identity.version())
  self.send_identity_field(4, identity.uri())
  self.send_identity_field(5, identity.serial())
  self.set_audio_mode_internal(audio_mode)
  self.state = Configured
}

///|
pub fn AoaSession::set_audio_mode(
  self : AoaSession,
  mode : AudioMode,
) -> Unit raise AoaError {
  match self.state {
    Probed(_) | Configured => ()
    _ =>
      raise InvalidState("audio mode must be selected before accessory start")
  }
  self.set_audio_mode_internal(mode)
}

///|
pub fn AoaSession::start(self : AoaSession) -> Unit raise AoaError {
  match self.state {
    Configured => ()
    _ => raise InvalidState("start requires the Configured state")
  }
  let request = @transport.ControlTransfer::out_request(
    request_type=usb_vendor_device_out,
    request=accessory_start,
    value=0,
    index=0,
    data=b"",
  ) catch {
    error => raise Transport(error)
  }
  ignore(transport_control(self.transport, request, default_control_timeout_ms))
  self.state = Started
}

///|
pub fn AoaSession::refresh_bulk_endpoints(
  self : AoaSession,
) -> Unit raise AoaError {
  match self.state {
    Started => ()
    BulkReady => return
    _ => raise InvalidState("bulk endpoints can only be refreshed after start")
  }
  let info = transport_info(self.transport)
  if info.vendor_id() != aoa_vendor_id ||
    !is_accessory_product(info.product_id()) {
    raise DeviceNotInAccessoryMode(info.product_id())
  }
  if !info.has_bulk_endpoints() {
    raise MissingBulkEndpoints
  }
  self.info = info
  self.state = BulkReady
}

///|
fn AoaSession::require_bulk_ready(self : AoaSession) -> Unit raise AoaError {
  if self.state != BulkReady {
    raise InvalidState("bulk transfer requires the BulkReady state")
  }
}

///|
pub fn AoaSession::write_bulk(
  self : AoaSession,
  payload : Bytes,
  timeout_ms : Int,
) -> Unit raise AoaError {
  self.require_bulk_ready()
  if timeout_ms <= 0 {
    raise InvalidState("bulk write timeout must be positive")
  }
  let endpoint = match self.info.bulk_out_endpoint() {
    Some(endpoint) => endpoint
    None => raise MissingBulkEndpoints
  }
  let actual = transport_bulk_write(
    self.transport,
    endpoint,
    payload,
    timeout_ms,
  )
  if actual != payload.length() {
    raise ShortTransfer(payload.length(), actual)
  }
}

///|
pub fn AoaSession::read_bulk(
  self : AoaSession,
  max_length : Int,
  timeout_ms : Int,
) -> Bytes raise AoaError {
  self.require_bulk_ready()
  if max_length <= 0 || timeout_ms <= 0 {
    raise InvalidState("bulk read length and timeout must be positive")
  }
  let endpoint = match self.info.bulk_in_endpoint() {
    Some(endpoint) => endpoint
    None => raise MissingBulkEndpoints
  }
  let result = transport_bulk_read(
    self.transport,
    endpoint,
    max_length,
    timeout_ms,
  )
  if result.length() > max_length {
    raise ShortTransfer(max_length, result.length())
  }
  result
}

///|
pub fn AoaSession::read_bulk_exact(
  self : AoaSession,
  length : Int,
  timeout_ms : Int,
) -> Bytes raise AoaError {
  let result = self.read_bulk(length, timeout_ms)
  if result.length() != length {
    raise ShortTransfer(length, result.length())
  }
  result
}

///|
fn AoaSession::require_v2(
  self : AoaSession,
  feature : AoaFeature,
) -> Unit raise AoaError {
  match self.protocol {
    Some(V2) => ()
    _ => raise UnsupportedFeature(feature)
  }
}

///|
fn AoaSession::require_hid_ready(self : AoaSession) -> Unit raise AoaError {
  self.require_v2(Hid)
  match self.state {
    Started | BulkReady => ()
    _ => raise InvalidState("HID control requests require accessory mode")
  }
}

///|
pub fn AoaSession::register_hid(
  self : AoaSession,
  identifier~ : Int,
  descriptor_length~ : Int,
) -> HidDevice raise AoaError {
  self.require_hid_ready()
  if identifier < 0 || identifier > 65535 {
    raise InvalidHidId(identifier)
  }
  if descriptor_length <= 0 || descriptor_length > 65535 {
    raise InvalidHidDescriptorLength(descriptor_length, descriptor_length)
  }
  if self.hid_devices.contains(identifier) {
    raise HidAlreadyRegistered(identifier)
  }
  let request = @transport.ControlTransfer::out_request(
    request_type=usb_vendor_device_out,
    request=accessory_register_hid,
    value=identifier,
    index=descriptor_length,
    data=b"",
  ) catch {
    error => raise Transport(error)
  }
  ignore(transport_control(self.transport, request, default_control_timeout_ms))
  self.hid_devices[identifier] = {
    total_length: descriptor_length,
    descriptor_ready: false,
  }
  { identifier, }
}

///|
fn descriptor_chunk(descriptor : Bytes, start : Int, end : Int) -> Bytes {
  descriptor.view(start~, end~).to_owned()
}

///|
pub fn AoaSession::send_hid_report_descriptor(
  self : AoaSession,
  device : HidDevice,
  descriptor : Bytes,
  packet_size? : Int = 64,
) -> Unit raise AoaError {
  self.require_hid_ready()
  if packet_size <= 0 || packet_size > 65535 {
    raise InvalidState("HID descriptor packet size must fit in 1..65535")
  }
  let registration = match self.hid_devices.get(device.identifier) {
    Some(registration) => registration
    None => raise UnknownHid(device.identifier)
  }
  if descriptor.length() != registration.total_length {
    raise InvalidHidDescriptorLength(
      registration.total_length,
      descriptor.length(),
    )
  }
  let mut offset = 0
  while offset < descriptor.length() {
    let end = if offset + packet_size < descriptor.length() {
      offset + packet_size
    } else {
      descriptor.length()
    }
    let request = @transport.ControlTransfer::out_request(
      request_type=usb_vendor_device_out,
      request=accessory_set_hid_report_desc,
      value=device.identifier,
      index=offset,
      data=descriptor_chunk(descriptor, offset, end),
    ) catch {
      error => raise Transport(error)
    }
    ignore(
      transport_control(self.transport, request, default_control_timeout_ms),
    )
    offset = end
  }
  self.hid_devices[device.identifier] = {
    total_length: registration.total_length,
    descriptor_ready: true,
  }
}

///|
pub fn AoaSession::send_hid_event(
  self : AoaSession,
  device : HidDevice,
  report : Bytes,
) -> Unit raise AoaError {
  self.require_hid_ready()
  let registration = match self.hid_devices.get(device.identifier) {
    Some(registration) => registration
    None => raise UnknownHid(device.identifier)
  }
  if !registration.descriptor_ready {
    raise HidDescriptorNotReady(device.identifier)
  }
  let request = @transport.ControlTransfer::out_request(
    request_type=usb_vendor_device_out,
    request=accessory_send_hid_event,
    value=device.identifier,
    index=0,
    data=report,
  ) catch {
    error => raise Transport(error)
  }
  ignore(transport_control(self.transport, request, default_control_timeout_ms))
}

///|
pub fn AoaSession::unregister_hid(
  self : AoaSession,
  device : HidDevice,
) -> Unit raise AoaError {
  self.require_hid_ready()
  if !self.hid_devices.contains(device.identifier) {
    raise UnknownHid(device.identifier)
  }
  let request = @transport.ControlTransfer::out_request(
    request_type=usb_vendor_device_out,
    request=accessory_unregister_hid,
    value=device.identifier,
    index=0,
    data=b"",
  ) catch {
    error => raise Transport(error)
  }
  ignore(transport_control(self.transport, request, default_control_timeout_ms))
  self.hid_devices.remove(device.identifier)
}

///|
pub fn AoaSession::close(self : AoaSession) -> Unit raise AoaError {
  if self.state == Closed {
    return
  }
  transport_close(self.transport)
  self.state = Closed
  self.hid_devices.clear()
}
