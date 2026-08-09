///|
/// Pure MoonBit SHA-256 implementation used for webhook signatures and
/// idempotency keys. No foreign function calls are involved.

///|
fn rotr(value : UInt, shift : Int) -> UInt {
  (value >> shift) | (value << (32 - shift))
}

///|
fn to_uint_be(bytes : Array[Byte], offset : Int) -> UInt {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn sha256_pad(data : Bytes) -> Array[Byte] {
  let len = data.length()
  let bit_len = (len * 8).to_uint64()
  let padded = data.to_array()
  padded.push(b'\x80')
  while padded.length() % 64 != 56 {
    padded.push(b'\x00')
  }
  let bit_bytes = bit_len.to_be_bytes().to_array()
  for byte in bit_bytes {
    padded.push(byte)
  }
  padded
}

///|
fn sha256_k() -> Array[UInt] {
  [
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
    0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
    0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
    0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
    0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
    0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
  ]
}

///|
fn sha256_init() -> Array[UInt] {
  [
    0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU, 0x9b05688cU,
    0x1f83d9abU, 0x5be0cd19U,
  ]
}

///|
/// Computes the raw 32-byte SHA-256 digest of `data`.
pub fn sha256(data : Bytes) -> Array[Byte] {
  let padded = sha256_pad(data)
  let h = sha256_init()
  let k = sha256_k()
  let chunk_count = padded.length() / 64
  for chunk in 0..<chunk_count {
    let w = Array::make(64, 0U)
    let offset = chunk * 64
    for i in 0..<16 {
      w[i] = to_uint_be(padded, offset + i * 4)
    }
    for i in 16..<64 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut h7 = h[7]
    for i in 0..<64 {
      let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ ((e ^ 0xffffffffU) & g)
      let temp1 = h7 + s1 + ch + k[i] + w[i]
      let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = s0 + maj
      h7 = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    }
    h[0] = h[0] + a
    h[1] = h[1] + b
    h[2] = h[2] + c
    h[3] = h[3] + d
    h[4] = h[4] + e
    h[5] = h[5] + f
    h[6] = h[6] + g
    h[7] = h[7] + h7
  }
  let digest = Array::make(32, b'\x00')
  for i in 0..<8 {
    let word = h[i]
    digest[i * 4] = (word >> 24).to_byte()
    digest[i * 4 + 1] = (word >> 16).to_byte()
    digest[i * 4 + 2] = (word >> 8).to_byte()
    digest[i * 4 + 3] = word.to_byte()
  }
  digest
}

///|
fn hex_digits() -> Array[String] {
  [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
}

///|
fn byte_to_hex(byte : Byte) -> String {
  let digits = hex_digits()
  let value = byte.to_uint()
  digits[(value >> 4).reinterpret_as_int()] +
  digits[(value & 0x0fU).reinterpret_as_int()]
}

///|
pub fn bytes_to_hex(bytes : Array[Byte]) -> String {
  let mut out = ""
  for byte in bytes {
    out = out + byte_to_hex(byte)
  }
  out
}

///|
/// Computes the lowercase hex SHA-256 digest of `data`.
pub fn sha256_hex(data : Bytes) -> String {
  bytes_to_hex(sha256(data))
}
