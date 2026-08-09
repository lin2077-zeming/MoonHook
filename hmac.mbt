///|
/// HMAC-SHA256 keyed hash used to sign webhook payloads. Implemented on top
/// of the pure MoonBit SHA-256, following RFC 2104.
pub fn hmac_sha256(key : Bytes, message : Bytes) -> Array[Byte] {
  let block_size = 64
  let normalized_key = if key.length() > block_size {
    Bytes::from_array(sha256(key))
  } else {
    key
  }
  let key_arr = normalized_key.to_array()
  let key_block = Array::make(block_size, b'\x00')
  for i in 0..<key_arr.length() {
    key_block[i] = key_arr[i]
  }
  let ipad = Array::make(block_size, b'\x00')
  let opad = Array::make(block_size, b'\x00')
  for i in 0..<block_size {
    ipad[i] = key_block[i] ^ b'\x36'
    opad[i] = key_block[i] ^ b'\x5c'
  }
  let inner_input = Bytes::from_array(ipad) + message
  let inner_digest = Bytes::from_array(sha256(inner_input))
  let outer_input = Bytes::from_array(opad) + inner_digest
  sha256(outer_input)
}

///|
/// Signs a payload string with HMAC-SHA256 and returns the lowercase hex
/// signature that can be sent in a `X-MoonHook-Signature` header.
pub fn sign_hmac_sha256(secret : String, payload : String) -> String {
  bytes_to_hex(hmac_sha256(@utf8.encode(secret), @utf8.encode(payload)))
}

///|
pub fn verify_hmac_sha256(
  secret : String,
  payload : String,
  signature : String,
) -> Bool {
  constant_time_eq(sign_hmac_sha256(secret, payload), signature)
}

///|
/// Compares two signature strings in constant time to avoid leaking the
/// expected digest through early-exit comparisons.
pub fn constant_time_eq(left : String, right : String) -> Bool {
  let left_arr = @utf8.encode(left).to_array()
  let right_arr = @utf8.encode(right).to_array()
  if left_arr.length() != right_arr.length() {
    false
  } else {
    let mut diff = 0U
    for i in 0..<left_arr.length() {
      diff = diff | (left_arr[i].to_uint() ^ right_arr[i].to_uint())
    }
    diff == 0U
  }
}
