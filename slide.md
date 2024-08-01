---
marp: true
theme: gaia
class:
  - invert
---

# JSPI + Moonbit で作る Worker

mizchi | Workers Tech Talk

----

## JavaScript Promise Interface (JSPI)

- WebAssembly 側でJSの非同期関数を呼ぶ仕様
- 非同期関数の呼び出しを含む wasm の関数を、 async function として実行
- WebAssembly側では特殊な対応の必要なし
- (現時点では) chrome://flags から JSPI を有効化する必要あり

---

## JSPI: Example

```js
// imports 提供側
const imports = { js: {
  update: new WebAssembly.Suspending(async () => 1)
}};
// 呼び出し側
const { instance } = await WebAssembly.instantiate(..., imports);
const run = WebAssembly.promising(instance.exports.run);
console.log(await run());
```

----

## JSPI の呼び出しルール

- 非同期関数を new WebAssembly.Suspending(async_func) でラップ
- 非同期関数の呼び出しを含む関数を WebAssembly.promising でラップ
- 関数の呼び出し
  - Suspending化された関数呼び出しで WebAssembly VM が停止
  - ホストの非同期関数を実行
  - WebAssembly が再開

---

## Moonbit 

- Rust 風のシンタックスを持つ WebAssembly ターゲットの言語
- wasm に最適化されてるので、出力サイズが小さい
- 豊富な表現力 + GC で Better TypeScript みたいな書き味

```rust
struct Point {
  x: Int
  y: Int
} derive(Debug)
fn distance(self: Point, other: Point) -> Double {
  sqrt((self.x * other.x + self.y * other.y).to_double())
}
```
(細かい言語機能については略)

---

## Moonbit + JSPI で CF Worker を書きたい

- 利点
  - 豊富な言語表現力
  - 小さい wasm 出力サイズ
- 問題
  - async/await やジェネレータのような非同期・継続がない
- => JSPI と組み合わせればいけるのでは？
  - (結論から言うと Workers では動いてない)

コード全体
https://github.com/mizchi/mbt-cfw-example

----

## Moonbit+JSPI: Moonbit 側

```rust
fn fetchUserId(id : Int) -> Int = "js" "fetchUserId"

pub fn run() -> Unit {
  let id = fetchUserId(1)
  println(id)
  ()
}
```

- `imports.js.fetch` をバインディングする
- 一旦数値のみを入出力

----

## Moonbit + JSPI: JS側

```js
const imports = {
  js: {
    fetchUserId: new Suspending(async (id: number) => {
      const res = await fetch(`https://jsonplaceholder.typicode.com/todos/${id}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await res.json();
      return data.userId;
    }),
  }
};
```

Suspending 化して非同期関数で fetch を叩く

---

### Deno での実行

```bash
$ deno run -A --v8-flags=--experimental-wasm-jspi run.ts
```

```js
const obj = await WebAssembly.instantiate(...);
obj.exports.run();
```

- `--v8-flags=--experimental-wasm-jspi` が必要

---

### 現時点の課題

- 数値の入出力しかできないので楽しくない
- 共有メモリに Uint8Array化したJSONを書き込んで、相互に読み出せばいいのでは

----

## JS

- fetch 前に共有メモリに入力を取り出す
- fetch 後に共有メモリに出力を書き込む

```js
    fetch: new Suspending(async (len: number) => {
      // read memory with offset
      const mem = new Uint8Array(memory.buffer);
      const req = JSON.parse(new TextDecoder().decode(mem.slice(0, len)));
      const res = await fetch(req.url, req.init);
      // write memory with response
      const data = await res.json();
      const bytes = new TextEncoder().encode(JSON.stringify(data));
      mem.set(bytes);
      return bytes.byteLength;
    }),
```

----

Moonbit 側でラップした関数を作って呼び出す

```rust
fn js_fetch(offset : Int) -> Int = "js" "fetch"
fn fetch(
  url : String,
  init : @json.JsonValue
) -> @json.JsonValue!@json.ParseError {
  // ...
  @json.parse!(s)
}
pub fn run() -> Unit!@json.ParseError {
  let res = fetch!(
    "https://jsonplaceholder.typicode.com/todos/1",
    { "method": "GET", "headers": { "Content-Type": "application/json" } },
  )
  println(res)
  ()
}
```

----

### Workers (予定)

```js
const handle = promising(instance.exports.handle)
export default {
  async fetch(request: Request) {
    const bytes = new TextEncoder().encode(JSON.stringify(request));
    const mem = new Uint8Array(memory.buffer);
    mem.set(bytes);
    const res = await handle(mem.byteLength);
    return new Response(res.body, res.init);
  }
}
```

- Cloudflare Workers に JSPI サポートがない!!!!
- ジェネレータ的な振る舞いをする関数を作れば継続を表現できるが...

---

## まとめ

- JSPI 安定化/Cloudflare のサポート待ち
- WebAssembly: JS Host 以外のStop/Resume を一般化してほしい
- Moonbit:
  - 何かしらの継続や async/await がほしい(ずっと言ってる)
  - 数値以外の構造化データの入出力がほしい
    - component-model

---

## 参考

- https://zenn.dev/mizchi/articles/introduce-moonbit
- wasm で非同期関数を呼び出す JSPI を試す https://zenn.dev/mizchi/scraps/cf710ccf0f890e