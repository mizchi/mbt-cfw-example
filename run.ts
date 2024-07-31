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
    fetch: new Suspending(async (id: number) => {
      const res = await fetch(`https://jsonplaceholder.typicode.com/todos/${id}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await res.json();
      return data.userId;
    }),
    fetch1: new Suspending(async (id: number) => {
      const res = await fetch(`https://jsonplaceholder.typicode.com/todos/${id}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await res.json();
      const mem = new Uint8Array(memory.buffer);
      const offset = mem.byteLength;
      const bytes = new TextEncoder().encode(JSON.stringify(data));
      mem.set(bytes, offset);
      return offset;
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

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch(new URL("./target/wasm-gc/release/build/main/main.wasm", import.meta.url)),
  imports,
);
memory = exports['moonbit.memory'] as WebAssembly.Memory;
// @ts-ignore
const run = promising(exports.run);
run();
flush();
