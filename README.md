# madk

`madk` is a MoonBit toolkit for hosts that communicate with Android devices
through the Android Open Accessory (AOA) protocol.

The project keeps the protocol state machine independent from USB and platform
details. Native USB access is provided by an optional libusb adapter; a
simulator is available for deterministic tests.

## Status

madk is pre-1.0 software. Public MoonBit APIs, the WIT contract, and transport
adapter behavior may change between releases.

## What it provides

- AOA v1 accessory negotiation and bulk transport;
- AOAv2 HID registration, descriptor transfer, and input events;
- AOAv2 audio-mode negotiation with explicit capability errors;
- transport interfaces for control and bulk transfers;
- a deterministic simulator with failure injection;
- a native libusb transport with runtime diagnostics;
- an Android fixture application for physical AOA acceptance tests;
- a WIT host-capability contract for a future WASI integration.

## Package layout

| Path | Purpose |
| --- | --- |
| `protocol.mbt`, `session.mbt` | portable AOA protocol state machine |
| `transport/` | transport interfaces and shared transfer types |
| `sim/` | deterministic simulator and tests |
| `libusb/` | native libusb adapter |
| `wit/` | WASI host capability contract |
| `examples/android/` | Android-side test fixture |
| `docs/` | protocol and integration-boundary notes |

## WASI boundary

WASI is an integration boundary, not a USB driver. A WASI component cannot
access Android USB APIs or libusb directly. The host must provide a capability
for device selection, control transfers, bulk transfers, timeouts, disconnects,
and cleanup.

The current WIT file defines that host contract but does not embed a WASI
runtime or provide a complete WASI adapter. See [`docs/wasi.md`](docs/wasi.md).

## Requirements

- MoonBit compiler release `0.10.9+6e6c44045`, selected by [`.moon-version`](.moon-version);
- a native C toolchain for native builds;
- libusb 1.0 runtime and host USB permissions for physical native USB tests;
- JDK 17, Android SDK, and Gradle 9.6.1 for the Android fixture.

The pinned release bundles MoonBit compiler `moonc 0.10.9+6e6c44045`. The
repository pins the exact release identifier because MoonBit is still evolving
and compiler/API changes must be deliberate. Do not replace the version with
the `latest` channel in local or CI setup.

## Build and test

The portable core and simulator do not require an Android device:

```sh
moon fmt --check
moon check --target native --deny-warn
moon test --target native --deny-warn
moon check --target all --deny-warn
```

Build the Android fixture with:

```sh
cd examples/android
gradle :app:assembleDebug --no-daemon
```

The Android application does not perform the AOA handshake. A host must
negotiate AOA, start accessory mode, handle USB re-enumeration, and then use
the fixture's length-prefixed test frames. Physical Windows tests may require
WinUSB on the Android Accessory interface and may require stopping a conflicting
ADB service before opening the composite device with libusb.

## Documentation

- [AOA design and protocol behavior](docs/aoa.md)
- [WASI boundary](docs/wasi.md)
- [Contributor guide](CONTRIBUTING.md)

## License

madk is distributed under the [MIT License](LICENSE).
