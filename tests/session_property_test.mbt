///|
fn session_state_is_configurable(state : @madk.AoaState) -> Bool {
  match state {
    Probed(_) | Configured => true
    _ => false
  }
}

///|
fn session_state_is_detected(state : @madk.AoaState) -> Bool {
  match state {
    Detected => true
    _ => false
  }
}

///|
fn session_state_is_probed(state : @madk.AoaState) -> Bool {
  match state {
    Probed(_) => true
    _ => false
  }
}

///|
fn session_state_is_configured(state : @madk.AoaState) -> Bool {
  match state {
    Configured => true
    _ => false
  }
}

///|
fn session_state_is_started_or_bulk_ready(state : @madk.AoaState) -> Bool {
  match state {
    Started | BulkReady => true
    _ => false
  }
}

///|
fn session_state_is_bulk_ready(state : @madk.AoaState) -> Bool {
  match state {
    BulkReady => true
    _ => false
  }
}

///|
fn session_state_is_closed(state : @madk.AoaState) -> Bool {
  match state {
    Closed => true
    _ => false
  }
}

///|
fn session_sequence_matches_model(
  protocol : @madk.AoaProtocolVersion,
  operations : Array[Int],
) -> Bool raise @madk.AoaError {
  let fake = @sim.FakeTransport::new(protocol~)
  let transport = fake as &@transport.UsbTransport
  let session = @madk.AoaSession::new(transport)
  let mut expected_state : @madk.AoaState = Detected
  let mut expected_protocol : @madk.AoaProtocolVersion? = None
  let mut expected_audio : @madk.AudioMode = Disabled
  let mut expected_audio_active = false
  for raw in operations {
    let action = raw % 9
    let action = if action < 0 { action + 9 } else { action }
    let actual_succeeded = match action {
      0 =>
        try {
          ignore(session.probe())
          true
        } catch {
          _ => false
        }
      1 =>
        try {
          session.configure(test_identity())
          true
        } catch {
          _ => false
        }
      2 =>
        try {
          session.set_audio_mode(Disabled)
          true
        } catch {
          _ => false
        }
      3 =>
        try {
          session.set_audio_mode(Pcm44100Stereo)
          true
        } catch {
          _ => false
        }
      4 =>
        try {
          session.start()
          true
        } catch {
          _ => false
        }
      5 =>
        try {
          session.refresh_bulk_endpoints()
          true
        } catch {
          _ => false
        }
      6 =>
        try {
          session.write_bulk(b"x", 100)
          true
        } catch {
          _ => false
        }
      7 => {
        fake.queue_bulk_read(b"r")
        try {
          ignore(session.read_bulk(1, 100))
          true
        } catch {
          _ => false
        }
      }
      _ =>
        try {
          session.close()
          true
        } catch {
          _ => false
        }
    }
    let expected_succeeded = match action {
      0 => session_state_is_detected(expected_state)
      1 => session_state_is_probed(expected_state)
      2 => session_state_is_configurable(expected_state)
      3 =>
        session_state_is_configurable(expected_state) &&
        (match expected_protocol {
          Some(V2) => true
          _ => false
        })
      4 => session_state_is_configured(expected_state)
      5 => session_state_is_started_or_bulk_ready(expected_state)
      6 => session_state_is_bulk_ready(expected_state)
      7 => session_state_is_bulk_ready(expected_state)
      _ => true
    }
    guard actual_succeeded == expected_succeeded else { return false }
    if expected_succeeded {
      match action {
        0 => {
          expected_protocol = Some(protocol)
          expected_state = Probed(protocol)
        }
        1 => {
          expected_state = Configured
          expected_audio = Disabled
        }
        2 => expected_audio = Disabled
        3 => expected_audio = Pcm44100Stereo
        4 => expected_state = Started
        5 => {
          if expected_state == Started && expected_audio == Pcm44100Stereo {
            expected_audio_active = true
          }
          expected_state = BulkReady
        }
        8 => expected_state = Closed
        _ => ()
      }
    }
    guard session.state() == expected_state else { return false }
    guard session.protocol() == expected_protocol else { return false }
    guard session.audio_mode() == expected_audio else { return false }
    let expected_capability : @madk.AudioCapability = match expected_protocol {
      Some(V2) => Pcm44100Stereo
      _ => Unsupported
    }
    guard session.audio_capability() == expected_capability else {
      return false
    }
    let expected_v2_active = match expected_protocol {
      Some(V2) => expected_state != Closed
      _ => false
    }
    guard session.supports(Bulk) == (expected_state == BulkReady) else {
      return false
    }
    guard session.supports(Hid) == expected_v2_active else { return false }
    guard session.supports(Audio) == expected_v2_active else { return false }
    guard session.audio_is_active() == expected_audio_active else {
      return false
    }
    guard fake.is_closed() == session_state_is_closed(expected_state) else {
      return false
    }
  }
  true
}

///|
test "quickcheck: V1 session operations follow the reference state model" {
  @quickcheck.check(
    (operations : Array[Int]) => session_sequence_matches_model(V1, operations),
    count=240,
    max_size=90,
    max_shrinks=120,
    seed=20260830,
  )
}

///|
test "quickcheck: V2 session operations follow the reference state model" {
  @quickcheck.check(
    (operations : Array[Int]) => session_sequence_matches_model(V2, operations),
    count=240,
    max_size=90,
    max_shrinks=120,
    seed=20260831,
  )
}

///|
fn choose_boundary(seed : Int, choices : Array[Int]) -> Int {
  let remainder = seed % choices.length()
  choices[if remainder < 0 { remainder + choices.length() } else { remainder }]
}

///|
fn expected_descriptor_chunks(
  descriptor : Bytes,
  packet_size : Int,
) -> Array[Bytes] {
  let expected : Array[Bytes] = []
  let mut offset = 0
  while offset < descriptor.length() {
    let end = if offset + packet_size < descriptor.length() {
      offset + packet_size
    } else {
      descriptor.length()
    }
    let chunk : Array[Byte] = []
    for i in offset..<end {
      chunk.push(descriptor[i])
    }
    expected.push(Bytes::from_array(chunk))
    offset = end
  }
  expected
}

///|
fn concatenate_chunks(chunks : Array[Bytes]) -> Bytes {
  let bytes : Array[Byte] = []
  for chunk in chunks {
    bytes.append(chunk.to_array())
  }
  Bytes::from_array(bytes)
}

///|
test "quickcheck: HID descriptor chunks replay the independent slicing model" {
  @quickcheck.check(
    (input : (Int, Int)) => {
      let descriptor_length = choose_boundary(input.0, [
        1, 2, 3, 63, 64, 65, 127, 128, 129, 255, 256,
      ])
      let packet_size = choose_boundary(input.1, [
        1, 2, 3, 7, 16, 63, 64, 65, 127, 128,
      ])
      let descriptor = Bytes::makei(descriptor_length, i => (i % 251).to_byte())
      let expected = expected_descriptor_chunks(descriptor, packet_size)
      let fake = @sim.FakeTransport::new_control_only(protocol=V2)
      let transport = fake as &@transport.UsbTransport
      let session = @madk.AoaSession::new(transport)
      ignore(session.probe())
      session.configure(test_identity())
      session.start()
      let device = session.register_hid(identifier=7, descriptor_length~)
      session.send_hid_report_descriptor(device, descriptor, packet_size~)
      let chunks = fake.hid_descriptor_chunks(7)
      guard chunks == expected else { return false }
      guard concatenate_chunks(chunks) == descriptor else { return false }
      let descriptor_requests = fake
        .control_log()
        .filter(request => {
          request.request() == @madk.accessory_set_hid_report_desc
        })
      guard descriptor_requests.length() == expected.length() else {
        return false
      }
      let mut offset = 0
      for i, request in descriptor_requests {
        guard request.value() == 7 && request.index() == offset else {
          return false
        }
        guard request.data() == expected[i] else { return false }
        offset += expected[i].length()
      }
      session.send_hid_event(device, b"\x00")
      fake.hid_events(7) == [b"\x00"]
    },
    count=260,
    max_size=256,
    max_shrinks=100,
    seed=20260832,
  )
}
