///|
fn valid_u8_for_test(value : Int) -> Bool {
  value >= 0 && value <= 255
}

///|
fn valid_u16_for_test(value : Int) -> Bool {
  value >= 0 && value <= 65535
}

///|
fn try_device_info(
  vendor_id : Int,
  product_id : Int,
  bulk_in_endpoint : Int?,
  bulk_out_endpoint : Int?,
) -> @transport.DeviceInfo? {
  Some(
    @transport.DeviceInfo::new(
      vendor_id~,
      product_id~,
      bulk_in_endpoint~,
      bulk_out_endpoint~,
    ),
  ) catch {
    _ => None
  }
}

///|
test "quickcheck: DeviceInfo accepts exactly valid USB descriptor fields" {
  @quickcheck.check(
    (input : (Int, Int, Int, Int, Bool, Bool)) => {
      let vendor_id = input.0
      let product_id = input.1
      let bulk_in_endpoint : Int? = if input.4 { Some(input.2) } else { None }
      let bulk_out_endpoint : Int? = if input.5 { Some(input.3) } else { None }
      let valid_endpoints = (match bulk_in_endpoint {
          Some(endpoint) => valid_u8_for_test(endpoint)
          None => true
        }) &&
        (match bulk_out_endpoint {
          Some(endpoint) => valid_u8_for_test(endpoint)
          None => true
        })
      let valid = valid_u16_for_test(vendor_id) &&
        valid_u16_for_test(product_id) &&
        valid_endpoints
      let result = try_device_info(
        vendor_id, product_id, bulk_in_endpoint, bulk_out_endpoint,
      )
      match result {
        Some(info) =>
          valid &&
          info.vendor_id() == vendor_id &&
          info.product_id() == product_id &&
          info.bulk_in_endpoint() == bulk_in_endpoint &&
          info.bulk_out_endpoint() == bulk_out_endpoint &&
          info.has_bulk_endpoints() ==
          (bulk_in_endpoint is Some(_) && bulk_out_endpoint is Some(_))
        None => !valid
      }
    },
    count=300,
    max_size=70000,
    max_shrinks=100,
    seed=20260827,
  )
}

///|
fn try_in_request(
  request_type : Int,
  request : Int,
  value : Int,
  index : Int,
  length : Int,
) -> @transport.ControlTransfer? {
  Some(
    @transport.ControlTransfer::in_request(
      request_type~,
      request~,
      value~,
      index~,
      length~,
    ),
  ) catch {
    _ => None
  }
}

///|
test "quickcheck: IN control transfers preserve valid wire fields" {
  @quickcheck.check(
    (input : (Int, Int, Int, Int, Int)) => {
      let request_type = input.0
      let request = input.1
      let value = input.2
      let index = input.3
      let length = input.4
      let valid = valid_u8_for_test(request_type) &&
        valid_u8_for_test(request) &&
        valid_u16_for_test(value) &&
        valid_u16_for_test(index) &&
        valid_u16_for_test(length)
      let result = try_in_request(request_type, request, value, index, length)
      match result {
        Some(transfer) =>
          valid &&
          transfer.request_type() == request_type &&
          transfer.request() == request &&
          transfer.value() == value &&
          transfer.index() == index &&
          transfer.length() == length &&
          transfer.data() == b"" &&
          transfer.is_in() == (request_type >= 128)
        None => !valid
      }
    },
    count=300,
    max_size=70000,
    max_shrinks=100,
    seed=20260828,
  )
}

///|
fn boundary_length(seed : Int) -> Int {
  let choices : Array[Int] = [0, 1, 2, 254, 255, 256, 65534, 65535, 65536]
  let remainder = seed % choices.length()
  choices[if remainder < 0 { remainder + choices.length() } else { remainder }]
}

///|
fn try_out_request(
  request_type : Int,
  request : Int,
  value : Int,
  index : Int,
  data : Bytes,
) -> @transport.ControlTransfer? {
  Some(
    @transport.ControlTransfer::out_request(
      request_type~,
      request~,
      value~,
      index~,
      data~,
    ),
  ) catch {
    _ => None
  }
}

///|
test "quickcheck: OUT control transfers enforce the 16-bit payload limit" {
  @quickcheck.check(
    (input : (Int, Int, Int, Int, Int)) => {
      let request_type = input.0
      let request = input.1
      let value = input.2
      let index = input.3
      let data = Bytes::make(boundary_length(input.4), b'\xA5')
      let valid = valid_u8_for_test(request_type) &&
        valid_u8_for_test(request) &&
        valid_u16_for_test(value) &&
        valid_u16_for_test(index) &&
        data.length() <= 65535
      let result = try_out_request(request_type, request, value, index, data)
      match result {
        Some(transfer) =>
          valid &&
          transfer.request_type() == request_type &&
          transfer.request() == request &&
          transfer.value() == value &&
          transfer.index() == index &&
          transfer.length() == data.length() &&
          transfer.data() == data &&
          transfer.is_in() == (request_type >= 128)
        None => !valid
      }
    },
    count=240,
    max_size=70000,
    max_shrinks=100,
    seed=20260829,
  )
}
