///|
fn test_identity() -> @madk.AoaIdentity raise @madk.AoaError {
  @madk.AoaIdentity::new(
    manufacturer="madk",
    model="simulator",
    description="MoonBit AOA test",
    version="1",
    uri="https://example.invalid/madk",
    serial="test-serial",
  )
}

///|
test "v1 session performs the handshake and bulk exchange" {
  let fake = @sim.FakeTransport::new(protocol=V1)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  assert_eq(session.state(), Detected)
  assert_eq(session.probe(), V1)
  session.configure(test_identity())
  assert_eq(session.state(), Configured)
  session.start()
  assert_eq(session.state(), Started)
  session.refresh_bulk_endpoints()
  assert_eq(session.state(), BulkReady)
  assert_true(session.supports(Bulk))
  assert_eq(fake.control_log().map(request => request.request()), [
    51, 52, 52, 52, 52, 52, 52, 53,
  ])
  session.write_bulk(b"ping", 100)
  assert_eq(fake.bulk_writes(), [b"ping"])
  fake.queue_bulk_read(b"pong")
  assert_eq(session.read_bulk_exact(4, 100), b"pong")
  assert_true(!session.supports(Hid))
}

///|
test "v2 config enables audio and HID descriptor chunking" {
  let fake = @sim.FakeTransport::new(protocol=V2)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  assert_eq(session.probe(), V2)
  session.configure(test_identity(), audio_mode=Pcm44100Stereo)
  session.start()
  session.refresh_bulk_endpoints()
  assert_eq(session.audio_capability(), Pcm44100Stereo)
  assert_true(session.audio_is_active())
  let device = session.register_hid(identifier=7, descriptor_length=130)
  let not_ready = try {
    session.send_hid_event(device, b"\x00")
    false
  } catch {
    HidDescriptorNotReady(7) => true
    _ => false
  }
  assert_true(not_ready)
  let descriptor = Bytes::make(130, b'\x05')
  session.send_hid_report_descriptor(device, descriptor, packet_size=64)
  assert_eq(fake.hid_descriptor_chunks(7).map(chunk => chunk.length()), [
    64, 64, 2,
  ])
  session.send_hid_event(device, b"\x01\x02")
  assert_eq(fake.hid_events(7), [b"\x01\x02"])
  session.unregister_hid(device)
  assert_eq(fake.control_log().map(request => request.request()), [
    51, 52, 52, 52, 52, 52, 52, 58, 53, 54, 56, 56, 56, 57, 55,
  ])
  let unknown = try {
    session.send_hid_event(device, b"\x03")
    false
  } catch {
    UnknownHid(7) => true
    _ => false
  }
  assert_true(unknown)
}

///|
test "v2 HID control requests do not require bulk endpoints" {
  let fake = @sim.FakeTransport::new_control_only(protocol=V2)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  ignore(session.probe())
  session.configure(test_identity())
  session.start()
  let device = session.register_hid(identifier=9, descriptor_length=2)
  session.send_hid_report_descriptor(device, b"\x05\x01")
  session.send_hid_event(device, b"\x00")
  assert_true(!session.supports(Bulk))
  assert_eq(fake.hid_events(9), [b"\x00"])
}

///|
test "already accessory mode does not infer the protocol from its product id" {
  let fake = @sim.FakeTransport::new_already_accessory()
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  assert_eq(session.state(), BulkReady)
  assert_eq(session.protocol(), None)
  assert_true(session.supports(Bulk))
  assert_true(!session.supports(Hid))
}

///|
test "v1 audio requests degrade as an explicit unsupported feature" {
  let fake = @sim.FakeTransport::new(protocol=V1)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  ignore(session.probe())
  let rejected = try {
    session.set_audio_mode(Pcm44100Stereo)
    false
  } catch {
    UnsupportedFeature(Audio) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(session.audio_capability(), Unsupported)
  session.configure(test_identity())
  session.start()
  assert_eq(fake.control_log().map(request => request.request()), [
    51, 52, 52, 52, 52, 52, 52, 53,
  ])
}

///|
test "bulk failures preserve short transfer, timeout, and disconnect causes" {
  let fake = @sim.FakeTransport::new(protocol=V1)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  ignore(session.probe())
  session.configure(test_identity())
  session.start()
  session.refresh_bulk_endpoints()
  fake.set_next_fault(ShortWrite(2))
  let short_write = try {
    session.write_bulk(b"abcd", 100)
    false
  } catch {
    ShortTransfer(4, 2) => true
    _ => false
  }
  assert_true(short_write)
  fake.queue_bulk_read(b"abcd")
  fake.set_next_fault(ShortRead(1))
  let short_read = try {
    ignore(session.read_bulk_exact(4, 100))
    false
  } catch {
    ShortTransfer(4, 1) => true
    _ => false
  }
  assert_true(short_read)
  fake.set_next_fault(Timeout)
  let timeout = try {
    ignore(session.read_bulk(4, 100))
    false
  } catch {
    Transport(Timeout) => true
    _ => false
  }
  assert_true(timeout)
  fake.disconnect()
  let disconnected = try {
    session.write_bulk(b"x", 100)
    false
  } catch {
    Transport(Disconnected) => true
    _ => false
  }
  assert_true(disconnected)
}

///|
test "close is idempotent and blocks subsequent transfers" {
  let fake = @sim.FakeTransport::new(protocol=V1)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  session.close()
  session.close()
  assert_true(fake.is_closed())
  let rejected = try {
    ignore(session.read_bulk(1, 100))
    false
  } catch {
    InvalidState(_) => true
    _ => false
  }
  assert_true(rejected)
}
