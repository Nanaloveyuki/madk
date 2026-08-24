///|
pub let aoa_vendor_id : Int = 0x18D1

///|
pub let accessory_product_id : Int = 0x2D00

///|
pub let accessory_adb_product_id : Int = 0x2D01

///|
pub let audio_product_id : Int = 0x2D02

///|
pub let audio_adb_product_id : Int = 0x2D03

///|
pub let accessory_audio_product_id : Int = 0x2D04

///|
pub let accessory_audio_adb_product_id : Int = 0x2D05

///|
pub let usb_vendor_device_in : Int = 0xC0

///|
pub let usb_vendor_device_out : Int = 0x40

///|
pub let accessory_get_protocol : Int = 51

///|
pub let accessory_send_string : Int = 52

///|
pub let accessory_start : Int = 53

///|
pub let accessory_register_hid : Int = 54

///|
pub let accessory_unregister_hid : Int = 55

///|
pub let accessory_set_hid_report_desc : Int = 56

///|
pub let accessory_send_hid_event : Int = 57

///|
pub let accessory_set_audio_mode : Int = 58

///|
pub let default_control_timeout_ms : Int = 1_000

///|
pub(all) enum AoaProtocolVersion {
  V1
  V2
} derive(Eq, Debug)

///|
pub fn AoaProtocolVersion::wire_value(self : AoaProtocolVersion) -> Int {
  match self {
    V1 => 1
    V2 => 2
  }
}

///|
pub(all) enum AoaFeature {
  Bulk
  Hid
  Audio
} derive(Eq, Debug)

///|
pub(all) enum AudioMode {
  Disabled
  Pcm44100Stereo
} derive(Eq, Debug)

///|
pub(all) enum AudioCapability {
  Unsupported
  Pcm44100Stereo
} derive(Eq, Debug)

///|
pub(all) enum AoaState {
  Detected
  Probed(AoaProtocolVersion)
  Configured
  Started
  BulkReady
  Closed
} derive(Eq, Debug)

///|
pub(all) suberror AoaError {
  InvalidState(String)
  InvalidIdentityField(Int)
  UnsupportedProtocol(Int)
  DeviceNotInAccessoryMode(Int)
  MissingBulkEndpoints
  ShortTransfer(Int, Int)
  UnsupportedFeature(AoaFeature)
  InvalidHidId(Int)
  HidAlreadyRegistered(Int)
  UnknownHid(Int)
  InvalidHidDescriptorLength(Int, Int)
  HidDescriptorNotReady(Int)
  Transport(@transport.TransportError)
} derive(Eq, Debug)

///|
pub struct AoaIdentity {
  priv manufacturer : String
  priv model : String
  priv description : String
  priv version : String
  priv uri : String
  priv serial : String
} derive(Eq, Debug)

///|
pub fn AoaIdentity::new(
  manufacturer~ : String,
  model~ : String,
  description~ : String,
  version~ : String,
  uri~ : String,
  serial~ : String,
) -> AoaIdentity raise AoaError {
  validate_identity_field(0, manufacturer)
  validate_identity_field(1, model)
  validate_identity_field(2, description)
  validate_identity_field(3, version)
  validate_identity_field(4, uri)
  validate_identity_field(5, serial)
  { manufacturer, model, description, version, uri, serial }
}

///|
pub fn AoaIdentity::minimal(
  manufacturer~ : String,
  model~ : String,
  version~ : String,
) -> AoaIdentity raise AoaError {
  AoaIdentity::new(
    manufacturer~,
    model~,
    description="",
    version~,
    uri="",
    serial="",
  )
}

///|
fn validate_identity_field(index : Int, value : String) -> Unit raise AoaError {
  let bytes = @utf8.encode(value, bom=false)
  if bytes.length() > 255 {
    raise InvalidIdentityField(index)
  }
  for byte in bytes {
    if byte == b'\x00' {
      raise InvalidIdentityField(index)
    }
  }
}

///|
pub fn AoaIdentity::manufacturer(self : AoaIdentity) -> String {
  self.manufacturer
}

///|
pub fn AoaIdentity::model(self : AoaIdentity) -> String {
  self.model
}

///|
pub fn AoaIdentity::description(self : AoaIdentity) -> String {
  self.description
}

///|
pub fn AoaIdentity::version(self : AoaIdentity) -> String {
  self.version
}

///|
pub fn AoaIdentity::uri(self : AoaIdentity) -> String {
  self.uri
}

///|
pub fn AoaIdentity::serial(self : AoaIdentity) -> String {
  self.serial
}

///|
fn is_accessory_product(product_id : Int) -> Bool {
  product_id == accessory_product_id ||
  product_id == accessory_adb_product_id ||
  product_id == audio_product_id ||
  product_id == audio_adb_product_id ||
  product_id == accessory_audio_product_id ||
  product_id == accessory_audio_adb_product_id
}

///|
fn product_has_audio(product_id : Int) -> Bool {
  product_id == audio_product_id ||
  product_id == audio_adb_product_id ||
  product_id == accessory_audio_product_id ||
  product_id == accessory_audio_adb_product_id
}
