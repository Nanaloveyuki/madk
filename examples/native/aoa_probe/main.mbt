///|
const MAX_FRAME_BYTES : Int = 64 * 1024

///|
struct ProbeOptions {
  selector : @libusb.LibusbDeviceSelector
  timeout_ms : Int
  echo : String
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => values.get(0)
    None => None
  }
}

///|
fn flag_enabled(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(value) => value
    None => false
  }
}

///|
fn required_value(matches : @argparse.Matches, name : String) -> String {
  match first_value(matches, name) {
    Some(value) => value
    None => @abort.abort("missing required option --\{name}")
  }
}

///|
fn parse_number(name : String, value : String) -> Int {
  try {
    if value.has_prefix("0x") || value.has_prefix("0X") {
      @string.parse_int(value[2:], base=16)
    } else {
      @string.parse_int(value, base=10)
    }
  } catch {
    _ => @abort.abort("invalid numeric value for --\{name}: \{value}")
  }
}

///|
fn parse_options() -> ProbeOptions {
  let command = @argparse.Command(
    "madk-aoa-probe",
    about="Negotiate Android Open Accessory mode and verify fixture frames.",
    flags=[
      @argparse.FlagArg(
        "accessory",
        about="Open an Android device already in AOA accessory mode.",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "vid",
        about="Normal-mode USB vendor ID, decimal or 0x-prefixed hex.",
      ),
      @argparse.OptionArg(
        "pid",
        about="Normal-mode USB product ID, decimal or 0x-prefixed hex.",
      ),
      @argparse.OptionArg(
        "timeout",
        default_values=["5000"],
        about="Control and bulk transfer timeout in milliseconds.",
      ),
      @argparse.OptionArg(
        "echo",
        default_values=["echo-from-host"],
        about="Payload used for the fixture echo frame.",
      ),
    ],
  )
  let matches = command.parse() catch {
    error => @abort.abort(error.to_string())
  }
  let selector = if flag_enabled(matches, "accessory") {
    @libusb.LibusbDeviceSelector::accessory()
  } else {
    let vendor_id = parse_number("vid", required_value(matches, "vid"))
    let product_id = parse_number("pid", required_value(matches, "pid"))
    @libusb.LibusbDeviceSelector::new(vendor_id~, product_id~) catch {
      error => @abort.abort("invalid USB selector: \{Repr(error)}")
    }
  }
  let timeout_ms = parse_number(
    "timeout",
    first_value(matches, "timeout").unwrap(),
  )
  if timeout_ms <= 0 {
    @abort.abort("--timeout must be positive")
  }
  { selector, timeout_ms, echo: first_value(matches, "echo").unwrap() }
}

///|
fn fixture_identity() -> @madk.AoaIdentity raise @madk.AoaError {
  @madk.AoaIdentity::new(
    manufacturer="madk",
    model="madk-fixture",
    description="madk Android Open Accessory fixture",
    version="1",
    uri="https://example.invalid/madk",
    serial="native-probe",
  )
}

///|
fn frame(body : String) -> Bytes {
  let payload = @utf8.encode(body, bom=false)
  let output = @buffer.Buffer::Buffer(size_hint=4 + payload.length())
  output.write_int_be(payload.length())
  output.write_bytes(payload[:])
  output.to_bytes()
}

///|
fn read_frame(
  session : @madk.AoaSession,
  timeout_ms : Int,
) -> String raise @madk.AoaError {
  let header = session.read_bulk_exact(4, timeout_ms)
  let length = header[0].to_int() * 16_777_216 +
    header[1].to_int() * 65_536 +
    header[2].to_int() * 256 +
    header[3].to_int()
  if length <= 0 || length > MAX_FRAME_BYTES {
    raise @madk.InvalidState("invalid fixture frame length: \{length}")
  }
  @utf8.decode_lossy(session.read_bulk_exact(length, timeout_ms))
}

///|
fn exchange(
  session : @madk.AoaSession,
  body : String,
  expected : String,
  timeout_ms : Int,
) -> Unit raise @madk.AoaError {
  session.write_bulk(frame(body), timeout_ms)
  let actual = read_frame(session, timeout_ms)
  if actual != expected {
    raise @madk.InvalidState(
      "fixture response mismatch: expected '\{expected}', got '\{actual}'",
    )
  }
  println("frame ok: \{body} -> \{actual}")
}

///|
fn run_session(
  session : @madk.AoaSession,
  options : ProbeOptions,
) -> Unit raise @madk.AoaError {
  if session.state() == @madk.BulkReady {
    println("device is already in AOA accessory mode")
  } else {
    let protocol = session.probe()
    println("AOA protocol: \{Repr(protocol)}")
    session.configure(fixture_identity())
    session.start()
    println("AOA start requested; waiting for accessory re-enumeration")
    session.refresh_bulk_endpoints()
  }
  let info = session.device_info()
  println(
    "accessory device: VID=0x\{info.vendor_id().to_string(radix=16)}, " +
    "PID=0x\{info.product_id().to_string(radix=16)}",
  )
  exchange(
    session,
    "status",
    "status:connected;protocol=host-negotiated",
    options.timeout_ms,
  )
  exchange(session, options.echo, "echo:\{options.echo}", options.timeout_ms)
}

///|
fn run(options : ProbeOptions) -> Unit raise @madk.AoaError {
  if !@libusb.LibusbTransport::runtime_available() {
    @abort.abort(
      "libusb runtime unavailable: \{@libusb.LibusbTransport::runtime_diagnostic()}",
    )
  }
  println("libusb: \{@libusb.LibusbTransport::runtime_diagnostic()}")
  let transport = @libusb.LibusbTransport::open(options.selector) catch {
    error => raise @madk.Transport(error)
  }
  let session = @madk.AoaSession::new(transport as &@transport.UsbTransport)
  run_session(session, options)
  session.close()
  println("AOA probe completed successfully")
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 {
    println(
      "Use --help for usage. Normal mode requires --vid and --pid; " +
      "--accessory opens an already re-enumerated AOA device.",
    )
    return
  }
  let options = parse_options()
  run(options) catch {
    error => @abort.abort("AOA probe failed: \{Repr(error)}")
  }
}
