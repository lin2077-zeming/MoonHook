///|
test "hmac-sha256 RFC 4231 test case 1" {
  let key = Bytes::from_array([
    b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b',
    b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b', b'\x0b',
    b'\x0b', b'\x0b',
  ])
  let digest = @MoonHook.hmac_sha256(key, b"Hi There")
  @test.assert_eq(
    @MoonHook.bytes_to_hex(digest),
    "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
  )
}

///|
test "hmac-sha256 with long key is hashed first" {
  let key = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let digest = @MoonHook.hmac_sha256(key, b"data")
  @test.assert_eq(digest.length(), 32)
}

///|
test "sign and verify payload" {
  let signature = @MoonHook.sign_hmac_sha256("secret", "{\"total\": 99}")
  @test.assert_eq(signature.length(), 64)
  @test.assert_eq(
    @MoonHook.verify_hmac_sha256("secret", "{\"total\": 99}", signature),
    true,
  )
  @test.assert_eq(
    @MoonHook.verify_hmac_sha256("secret", "{\"total\": 100}", signature),
    false,
  )
  @test.assert_eq(
    @MoonHook.verify_hmac_sha256("other", "{\"total\": 99}", signature),
    false,
  )
}

///|
test "constant time comparison" {
  @test.assert_eq(@MoonHook.constant_time_eq("abc", "abc"), true)
  @test.assert_eq(@MoonHook.constant_time_eq("abc", "abd"), false)
  @test.assert_eq(@MoonHook.constant_time_eq("abc", "abcd"), false)
}
