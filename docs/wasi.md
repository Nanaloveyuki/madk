# WASI Boundary

The portable AOA state machine must not depend on libusb, Android Java objects,
file descriptors, or a particular WASI runtime.

The future WASI component receives a host capability with these operations:

- enumerate and open an approved USB device;
- issue bounded control-in and control-out transfers;
- read and write bounded bulk data with timeouts;
- close the device and observe disconnects.

The host owns USB permissions, device allowlisting, endpoint discovery, native
handles, cancellation, and resource cleanup. A WASI guest never receives a
raw pointer or an unrestricted filesystem/network capability.

The v1 WIT file is only an interface contract. It does not claim that MoonBit's
current `wasm` or `wasm-gc` targets are WASI targets, and it does not embed
Wasmtime, WasmEdge, or another runtime.
