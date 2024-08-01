// deno run --allow-read --v8-flags=--experimental-wasm-jspi run.ts
let memory: WebAssembly.Memory;

const [log, flush] = (() => {
  let buffer: number[] = [];
  function flush() {
    if (buffer.length > 0) {
      console.log(new TextDecoder("utf-16").decode(new Uint16Array(buffer).valueOf()));
      buffer = [];
    }
  }
  function log(ch: number) {
    if (ch == '\n'.charCodeAt(0)) { flush(); }
    else if (ch == '\r'.charCodeAt(0)) { /* noop */ }
    else { buffer.push(ch); }
  }
  return [log, flush]
})();

const { promising, Suspending } = WebAssembly as any;

const imports = {
  js: {
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

  },
  spectest: { print_char: log },
  js_string: {
    new: (offset: number, length: number) => {
      const bytes = new Uint16Array(memory.buffer, offset, length);
      const string = new TextDecoder("utf-16").decode(bytes);
      return string
    },
    empty: () => { return "" },
    log: (string: string) => { console.log(string) },
    append: (s1: string, s2: string) => { return (s1 + s2) },
  }
};

const obj = await WebAssembly.instantiateStreaming(
  fetch(new URL("./target/wasm-gc/release/build/main/main.wasm", import.meta.url)),
  imports,
);

const exports = obj.instance.exports as any;
memory = exports.memory as WebAssembly.Memory;
// @ts-ignore
const run = promising(exports.run);
await run();
flush();

// handle
const responseLen = exports.handle();
const mem = new Uint8Array(memory.buffer);
const res = JSON.parse(new TextDecoder().decode(mem.slice(0, responseLen)));
console.log(new Response(res.body, res.init));

// export function handle() {
//   return new Response("Hello World", {
//     headers: { "content-type": "text/plain" },
//   });
// }