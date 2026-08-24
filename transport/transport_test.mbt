///|
test "control transfers expose the USB setup fields" {
  let request = ControlTransfer::in_request(
    request_type=0xC0,
    request=51,
    value=0,
    index=0,
    length=2,
  )
  assert_true(request.is_in())
  assert_eq(request.request_type(), 0xC0)
  assert_eq(request.request(), 51)
  assert_eq(request.value(), 0)
  assert_eq(request.index(), 0)
  assert_eq(request.length(), 2)
  assert_eq(request.data(), b"")
}

///|
test "transport constructors reject invalid USB fields" {
  let invalid_request = try {
    ignore(
      ControlTransfer::in_request(
        request_type=0xC0,
        request=51,
        value=0,
        index=0,
        length=65536,
      ),
    )
    false
  } catch {
    InvalidLength(65536) => true
    _ => false
  }
  assert_true(invalid_request)
  let invalid_endpoint = try {
    ignore(
      DeviceInfo::new(
        vendor_id=1,
        product_id=2,
        bulk_in_endpoint=Some(256),
        bulk_out_endpoint=None,
      ),
    )
    false
  } catch {
    InvalidEndpoint(256) => true
    _ => false
  }
  assert_true(invalid_endpoint)
}
