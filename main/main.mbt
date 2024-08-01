extern "wasm" fn load8_ffi(pos : Int) -> Int =
  #|(func (param $pos i32) (result i32) (i32.load8_u (local.get $pos)))

extern "wasm" fn store8_ffi(pos : Int, value : Int) =
  #|(func (param $pos i32) (param $value i32) (i32.store8 (local.get $pos) (local.get $value)))

fn store_bytes(bytes : Bytes) -> Unit {
  let byte_length = bytes.length()
  for i = 0; i < byte_length; i = i + 1 {
    store8_ffi(i, bytes[i].to_int())
  }
}

pub fn read_buffer(len : Int) -> Bytes {
  let bytes = Bytes::new(len)
  for i = 0; i < len; i = i + 1 {
    bytes[i] = load8_ffi(i).to_byte()
  }
  bytes
}

// JavaScript's TextEncoder.encode
pub fn encode_string(s : String) -> Bytes {
  let result = []
  for i = 0; i < s.length(); i = i + 1 {
    let char = s[i]
    let code = char.to_int()
    if code < 0x80 {
      result.push(code)
    } else if code < 0x800 {
      result.push((0xC0).lor(code.lsr(6)))
      result.push((0x80).lor(code.land(0x3F)))
    } else if code < 0x10000 {
      result.push((0xE0).lor(code.lsr(12)))
      result.push((0x80).lor(code.lsr(6).land(0x3F)))
      result.push((0x80).lor(code.land(0x3F)))
    } else {
      result.push((0xF0).lor(code.lsr(18)))
      result.push((0x80).lor(code.lsr(12).land(0x3F)))
      result.push((0x80).lor(code.lsr(6).land(0x3F)))
      result.push((0x80).lor(code.land(0x3F)))
    }
  }
  let bytes = Bytes::new(result.length())
  for i = 0; i < result.length(); i = i + 1 {
    bytes[i] = result[i].to_byte()
  }
  bytes
}

pub fn decode_string(bytes : Bytes) -> String {
  let mut result = ""
  let mut i = 0
  while i < bytes.length() {
    let byte = bytes[i].to_int()
    if byte < 0x80 {
      // 1 byte character
      result += Char::from_int(byte).to_string()
      i += 1
    } else if byte < 0xE0 {
      // 2 byte character
      let code = byte.lsl(6).land(0x7FF) + bytes[i + 1].to_int().land(0x3F)
      result += Char::from_int(code).to_string()
      i += 2
    } else if byte < 0xF0 {
      // 3 byte character
      let code = byte.lsl(12).land(0xFFFF) + bytes[i + 1].to_int().lsl(6).land(
          0xFFF,
        ) + bytes[i + 2].to_int().land(0x3F)
      result += Char::from_int(code).to_string()
      i += 3
    } else {
      // 4 byte character
      let code = byte.lsl(18).land(0x1FFFFF) + bytes[i + 1].to_int().lsl(12).land(
          0x3FFFF,
        ) + bytes[i + 2].to_int().lsl(6).land(0xFFF) + bytes[i + 3].to_int().land(
          0x3F,
        )
      result += Char::from_int(code).to_string()
      i += 4
    }
  }
  result
}

fn js_fetch(offset : Int) -> Int = "js" "fetch"

fn fetch(
  url : String,
  init : @json.JsonValue
) -> @json.JsonValue!@json.ParseError {
  let req : @json.JsonValue = {
    "url": @json.JsonValue::String(url),
    "init": init,
  }
  let req_bytes = encode_string(req.stringify())
  store_bytes(req_bytes)
  let res_len = js_fetch(req_bytes.length())
  let bytes = read_buffer(res_len)
  let s = decode_string(bytes)
  let json = @json.parse!(s)
  json
}

pub fn run() -> Unit!@json.ParseError {
  let res = fetch!(
    "https://jsonplaceholder.typicode.com/todos/1",
    { "method": "GET", "headers": { "Content-Type": "application/json" } },
  )
  println(res)
  ()
}

pub fn handle() -> Int {
  // let res = fetch!(
  //   "https://jsonplaceholder.typicode.com/todos/1",
  //   { "method": "GET", "headers": { "Content-Type": "application/json" } },
  // )

  let res : @json.JsonValue = {
    "body": "Hello, World!",
    "init": {
      "status": 200,
      "statusText": "OK",
      "headers": { "Content-Type": "text/plain" },
    },
  }
  let encoded = encode_string(res.stringify())
  store_bytes(encoded)
  encoded.length()
  // println(res)
  // ()
}
