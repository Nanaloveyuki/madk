# AOA Design

## Topology

`madk` targets the accessory side of Android Open Accessory. The accessory is
the USB host. The Android phone is the USB device and, after a successful
handshake, exposes bulk endpoints to the Android application selected by the
accessory identity.

The protocol session owns this sequence:

1. enumerate and identify the connected Android device;
2. query the supported AOA protocol version;
3. send manufacturer, model, description, version, URI, and serial strings;
4. optionally request AOAv2 audio mode before starting accessory mode;
5. start accessory mode;
6. re-enumerate the device and open the accessory bulk endpoints;
7. exchange application-defined bytes until disconnect or close.

The implementation must reject unknown USB devices before sending AOA vendor
requests. The expected Android vendor ID and accessory product IDs are part of
the detection policy, not a substitute for explicit device selection.

## AOAv2

AOAv2 HID support is part of the v1 API. The session must support HID register,
unregister, report-descriptor transfer, and input-event transfer. Large report
descriptors are split into ordered control requests.

AOAv2 audio negotiation is exposed as a capability. Android devices that do
not provide the deprecated audio feature return a stable unsupported result;
audio support is not required for the ordinary phone bulk/HID acceptance path.

## Application bytes

AOA provides a USB transport, not an application message format. The Android
example uses a test-only length-prefixed echo framing so that short reads,
short writes, and reconnect behavior are observable. The public core does not
force this framing on applications.

## Failure model

The session reports invalid device, unsupported protocol, invalid state,
timeout, short transfer, disconnect, unsupported feature, and transport
failures separately. Closing an already closed session is idempotent.

HID is an AOAv2 control-request feature and does not require the bulk
application interface. A device may therefore support HID while the session
has no bulk endpoints. Bulk operations remain gated on `BulkReady`.
