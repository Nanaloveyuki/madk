# Contributing to madk

This guide is for contributors changing the MoonBit protocol core, transport
adapters, native bindings, tests, or the Android fixture. User-facing usage
belongs in [README.md](README.md) and the focused documents under `docs/`.

## Development environment

- MoonBit compiler release `0.10.9+6e6c44045`, selected by [`.moon-version`](.moon-version);
- a native C toolchain for the `native` target;
- Git and a working network connection for MoonBit dependencies;
- JDK 17, Android SDK, and Gradle 9.6.1 for the Android fixture;
- libusb 1.0 and a host USB permission/driver setup for physical tests.

Check the selected toolchain before debugging a compiler or API issue:

```sh
moon version --all
```

The toolchain release should be `0.10.9+6e6c44045`, and its `moonc` line should
report the same exact version. The build identifier is part of the published
MoonBit installer artifact. Do not silently switch the repository back to the
`latest` channel to work around a failure. Record a deliberate toolchain
upgrade as a separate change.

## Repository boundaries

| Path | Responsibility |
| --- | --- |
| `protocol.mbt`, `session.mbt` | transport-independent AOA state machine and public protocol API |
| `transport/` | USB control and bulk transfer abstractions |
| `sim/` | deterministic simulator and failure injection for tests |
| `libusb/` | native libusb adapter and runtime diagnostics |
| `wit/` | host capability contract for a future WASI integration |
| `examples/android/` | Android-side fixture for physical AOA acceptance tests |
| `docs/` | protocol, WASI-boundary, and maintainer-facing documentation |

Keep platform details inside adapters. The protocol core must not depend on
libusb, Android Java APIs, file descriptors, or a specific WASI runtime. The
WIT contract is an integration boundary; it is not an embedded USB driver.

## Local validation

Run the smallest relevant set while iterating. Before opening a PR, run:

```sh
moon fmt --check
moon check --target native --deny-warn
moon test --target native --deny-warn
moon check --target all --deny-warn
```

For the Android fixture:

```sh
cd examples/android
gradle :app:assembleDebug --no-daemon
```

If a public MoonBit API changes, run `moon info` and review the generated
`pkg.generated.mbti` diff. Do not hand-edit generated interface files. Keep
physical USB logs, APKs, native libraries, screenshots, and temporary probes
under ignored paths such as `tmp/`; do not commit them.

## Physical AOA testing

The Android fixture does not perform the AOA handshake. A host test must:

1. select an explicitly allowlisted Android USB device;
2. negotiate the AOA protocol and send the accessory identity;
3. start accessory mode and handle USB re-enumeration;
4. verify bulk traffic, then close the session cleanly.

On Windows, bind WinUSB only to the Android Accessory interface. Keep the ADB
interface on its existing driver. A running ADB service can hold a composite
device interface and prevent libusb from opening the device; stop that service
for a libusb probe when necessary.

Physical HID and audio behavior is not covered by the normal simulator suite.
When changing those paths, document the device, driver, and focused acceptance
result in the pull request rather than in the user README.

## Pull requests

1. Start from an up-to-date `main` branch and create a focused branch.
2. Preserve package boundaries and keep generated files owned by their inputs.
3. Add or update focused tests and documentation for behavior changes.
4. Run the validation commands above and include the actual results in the PR.
5. Wait for all validation jobs to pass before merging.

Use squash merge for a focused change. Public API or protocol changes must
state compatibility impact, migration needs, and any untested platform paths.

## Compatibility and releases

madk is pre-1.0. Public MoonBit APIs, the WIT contract, and adapter behavior may
change between releases. A toolchain upgrade must be explicit and must update
`.moon-version`, CI validation, and the contributor documentation together.
