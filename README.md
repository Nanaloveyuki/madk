# madk

`madk` is a MoonBit implementation of the Android Open Accessory (AOA)
protocol for accessory-side USB hosts.

The project is intentionally split into a portable protocol core and optional
transport adapters:

- `aoa` contains the protocol state machine and public protocol types;
- `transport` defines the USB host/device boundary;
- `sim` provides deterministic protocol simulation and failure injection;
- `libusb` provides the first native USB backend;
- `examples/android` is a small Android application for phone-based testing.

The Android Open Accessory protocol is not the Android USB host API. An
accessory is the USB host, while the Android device enters accessory mode.
The protocol starts with device detection and negotiation, followed by
identity strings, accessory-mode startup, and bulk endpoint communication.

## Current scope

- AOAv1 generic accessory communication;
- AOAv2 HID registration, report descriptors, and input events;
- AOAv2 audio-mode negotiation with explicit unsupported-feature handling;
- native libusb transport on supported desktop hosts;
- a deterministic simulator for tests without USB hardware;
- a WIT contract for a future WASI host implementation.

WASI is an integration boundary, not a USB driver. A WASI component cannot
access Android USB APIs or libusb without a host-provided capability. The WIT
file in this repository defines that boundary but does not select or embed a
WASI runtime yet.

## Development

The portable packages can be checked and tested without a connected Android
device:

```text
moon fmt --check
moon check --target native --deny-warn
moon test --target native --deny-warn
```

The libusb backend requires a development installation of libusb 1.0. The
Android fixture requires Android SDK and Gradle. A real phone is required for
AOA handshake, bulk, and HID acceptance tests; simulator tests do not require
hardware.

## License

`madk` is distributed under the MIT License. See [LICENSE](LICENSE).
