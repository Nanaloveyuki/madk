///|
fn nonnegative_mod(value : Int, modulus : Int) -> Int {
  let remainder = value % modulus
  if remainder < 0 {
    remainder + modulus
  } else {
    remainder
  }
}

///|
fn identity_field_is_valid(value : String) -> Bool {
  let bytes = @utf8.encode(value, bom=false)
  if bytes.length() > 255 {
    return false
  }
  for byte in bytes {
    if byte == b'\x00' {
      return false
    }
  }
  true
}

///|
fn identity_with_field(
  index : Int,
  value : String,
) -> @madk.AoaIdentity raise @madk.AoaError {
  match index {
    0 =>
      @madk.AoaIdentity::new(
        manufacturer=value,
        model="model",
        description="description",
        version="1",
        uri="https://example.invalid/madk",
        serial="serial",
      )
    1 =>
      @madk.AoaIdentity::new(
        manufacturer="manufacturer",
        model=value,
        description="description",
        version="1",
        uri="https://example.invalid/madk",
        serial="serial",
      )
    2 =>
      @madk.AoaIdentity::new(
        manufacturer="manufacturer",
        model="model",
        description=value,
        version="1",
        uri="https://example.invalid/madk",
        serial="serial",
      )
    3 =>
      @madk.AoaIdentity::new(
        manufacturer="manufacturer",
        model="model",
        description="description",
        version=value,
        uri="https://example.invalid/madk",
        serial="serial",
      )
    4 =>
      @madk.AoaIdentity::new(
        manufacturer="manufacturer",
        model="model",
        description="description",
        version="1",
        uri=value,
        serial="serial",
      )
    _ =>
      @madk.AoaIdentity::new(
        manufacturer="manufacturer",
        model="model",
        description="description",
        version="1",
        uri="https://example.invalid/madk",
        serial=value,
      )
  }
}

///|
fn identity_field_value(identity : @madk.AoaIdentity, index : Int) -> String {
  match index {
    0 => identity.manufacturer()
    1 => identity.model()
    2 => identity.description()
    3 => identity.version()
    4 => identity.uri()
    _ => identity.serial()
  }
}

///|
test "quickcheck: valid AOA identity fields round-trip through accessors" {
  @quickcheck.check(
    (value : String) => {
      for index in 0..<6 {
        let identity = identity_with_field(index, value)
        guard identity_field_value(identity, index) == value else {
          return false
        }
      }
      true
    },
    filter=identity_field_is_valid,
    count=250,
    max_size=320,
    discard_ratio=20,
    seed=20260825,
  )
}

///|
test "quickcheck: identity fields reject NUL and overlong UTF-8 values" {
  @quickcheck.check(
    (input : (String, Int)) => {
      let value = input.0
      let index = nonnegative_mod(input.1, 6)
      if identity_field_is_valid(value) {
        try {
          ignore(identity_with_field(index, value))
          true
        } catch {
          _ => false
        }
      } else {
        try {
          ignore(identity_with_field(index, value))
          false
        } catch {
          @madk.InvalidIdentityField(actual) => actual == index
          _ => false
        }
      }
    },
    count=300,
    max_size=320,
    max_shrinks=120,
    seed=20260826,
  )
}
