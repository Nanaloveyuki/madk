///|
test "selector requires an explicit valid VID and PID" {
  let rejected = try {
    ignore(LibusbDeviceSelector::new(vendor_id=0x18D1, product_id=0x10000))
    false
  } catch {
    @transport.InvalidDeviceInfo(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "accessory selector is restricted to the official AOA vendor" {
  let selector = LibusbDeviceSelector::accessory()
  assert_true(selector.is_accessory_mode())
  assert_eq(selector.vendor_id(), 0x18D1)
  assert_eq(selector.product_id(), None)
}

///|
test "runtime probe reports a diagnostic without opening USB" {
  let diagnostic = LibusbTransport::runtime_diagnostic()
  assert_true(!diagnostic.is_empty())
  ignore(LibusbTransport::runtime_available())
}
