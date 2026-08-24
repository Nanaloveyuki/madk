///|
priv type NativeHandle

///|
extern "C" fn native_new() -> NativeHandle = "madk_libusb_new"

///|
#borrow(handle)
extern "C" fn native_open(
  handle : NativeHandle,
  vendor_id : Int,
  product_id : Int,
  accessory_mode : Bool,
) -> Int = "madk_libusb_open"

///|
#borrow(handle)
extern "C" fn native_info(handle : NativeHandle) -> Int = "madk_libusb_info"

///|
#borrow(handle)
extern "C" fn native_refresh(handle : NativeHandle) -> Int = "madk_libusb_refresh"

///|
#borrow(handle)
extern "C" fn native_vendor_id(handle : NativeHandle) -> Int = "madk_libusb_vendor_id"

///|
#borrow(handle)
extern "C" fn native_product_id(handle : NativeHandle) -> Int = "madk_libusb_product_id"

///|
#borrow(handle)
extern "C" fn native_bulk_in_endpoint(handle : NativeHandle) -> Int = "madk_libusb_bulk_in_endpoint"

///|
#borrow(handle)
extern "C" fn native_bulk_out_endpoint(handle : NativeHandle) -> Int = "madk_libusb_bulk_out_endpoint"

///|
#borrow(handle, data)
extern "C" fn native_control(
  handle : NativeHandle,
  request_type : Int,
  request : Int,
  value : Int,
  index : Int,
  data : Bytes,
  length : Int,
  timeout_ms : Int,
) -> Int = "madk_libusb_control"

///|
#borrow(handle, data)
extern "C" fn native_bulk_write(
  handle : NativeHandle,
  endpoint : Int,
  data : Bytes,
  length : Int,
  timeout_ms : Int,
) -> Int = "madk_libusb_bulk_write"

///|
#borrow(handle, data)
extern "C" fn native_bulk_read(
  handle : NativeHandle,
  endpoint : Int,
  data : Bytes,
  length : Int,
  timeout_ms : Int,
) -> Int = "madk_libusb_bulk_read"

///|
#borrow(handle)
extern "C" fn native_close(handle : NativeHandle) -> Int = "madk_libusb_close"

///|
#borrow(handle)
extern "C" fn native_last_error(handle : NativeHandle) -> Bytes = "madk_libusb_last_error"

///|
extern "C" fn native_runtime_available() -> Bool = "madk_libusb_runtime_available"

///|
extern "C" fn native_runtime_diagnostic() -> Bytes = "madk_libusb_runtime_diagnostic"
