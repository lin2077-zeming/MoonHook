///|
test "sha256 empty string" {
  @test.assert_eq(
    @MoonHook.sha256_hex(b""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 abc" {
  @test.assert_eq(
    @MoonHook.sha256_hex(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 multi-word message" {
  @test.assert_eq(
    @MoonHook.sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "sha256 raw digest length" {
  let digest = @MoonHook.sha256(b"abc")
  @test.assert_eq(digest.length(), 32)
}
