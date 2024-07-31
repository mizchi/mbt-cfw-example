fn fetch(tid : Int) -> Int = "js" "fetch"

pub fn run() -> Unit {
  let id = fetch(1)
  println(id)
  // let json : @json.JsonValue = { "hello": "world" }
  // println(@lib.hello())
  // println(@json.stringify(json))
  ()
}
