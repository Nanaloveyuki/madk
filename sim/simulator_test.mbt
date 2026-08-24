///|
test "fake transport answers protocol and enters accessory mode" {
  let fake = FakeTransport::new(protocol=V2)
  let transport = fake as &@transport.UsbTransport
  let get_protocol = @transport.ControlTransfer::in_request(
    request_type=@madk.usb_vendor_device_in,
    request=@madk.accessory_get_protocol,
    value=0,
    index=0,
    length=2,
  )
  assert_eq(
    transport.control(get_protocol, 100),
    Bytes::from_array([b'\x02', b'\x00']),
  )
  let start = @transport.ControlTransfer::out_request(
    request_type=@madk.usb_vendor_device_out,
    request=@madk.accessory_start,
    value=0,
    index=0,
    data=b"",
  )
  ignore(transport.control(start, 100))
  let info = transport.info()
  assert_eq(info.vendor_id(), @madk.aoa_vendor_id)
  assert_eq(info.product_id(), @madk.accessory_product_id)
  assert_true(info.has_bulk_endpoints())
}

///|
test "fake transport can script short writes, short reads, and timeouts" {
  let fake = FakeTransport::new(protocol=V1)
  let transport = fake as &@transport.UsbTransport
  let start = @transport.ControlTransfer::out_request(
    request_type=@madk.usb_vendor_device_out,
    request=@madk.accessory_start,
    value=0,
    index=0,
    data=b"",
  )
  ignore(transport.control(start, 100))
  fake.set_next_fault(ShortWrite(1))
  assert_eq(transport.bulk_write(0x02, b"abcd", 100), 1)
  fake.queue_bulk_read(b"abcd")
  fake.set_next_fault(ShortRead(2))
  assert_eq(transport.bulk_read(0x81, 4, 100), b"ab")
  fake.set_next_fault(Timeout)
  let timed_out = try {
    ignore(transport.bulk_read(0x81, 4, 100))
    false
  } catch {
    Timeout => true
    _ => false
  }
  assert_true(timed_out)
}
