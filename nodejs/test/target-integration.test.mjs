import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

function compileNode(source) {
  return compileMojo({
    capabilities: [createMojoNodejsCapability()],
    files: { "index.ts": source },
  });
}

test("closed Node parity operations cross the complete target boundary", () => {
  const result = compileNode(`
import assert from "node:assert";
import { Buffer } from "node:buffer";
import process, { argv0, hrtime, memoryUsage, stderr, stdout } from "node:process";

export function main(): void {
  assert(argv0.length >= 0);
  const before = hrtime();
  hrtime(before);
  const memory = memoryUsage();
  memory.rss;
  stdout.write("out");
  stderr.write(Buffer.from("err"));
  process.argv0;
  const source = Buffer.from([0, 1, 2, 3]);
  const target = Buffer.alloc(4);
  source.copy(target);
  source.slice(1, 3);
  source.swap16();
  source.readUInt16BE(0);
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "argument_zero", "hrtime", "hrtime_since", "memory_usage", "stdout", "stderr",
    "buffer_from_numbers", "buffer_alloc", ".copy(", ".slice(", ".swap16(",
    ".read_uint16_be(",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
});

test("writable process state seals source-nullable to native-optional conversion", () => {
  const result = compileNode(`
import process from "node:process";

export function main(): void {
  process.exitCode = 2;
  process.exitCode = null;
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(source, /tsonic_node\.process\.set_exit_code/u);
  assert.match(source, /Variant\[tsonic_runtime\.Null, Float64\]\(Float64\(2\)\)/u);
  assert.match(source, /\.isa\[Float64\]\(\)/u);
  assert.match(source, /Optional\[Int32\]\(Int32\(/u);
  assert.match(source, /Variant\[tsonic_runtime\.Null, Float64\]\(tsonic_runtime\.Null\(\)\)/u);
  assert.equal(source.match(/tsonic_node\.process\.set_exit_code/gu)?.length, 2);
});

test("provider reads and writes retain source carriers before target ABI conversion", () => {
  const result = compileMojo({
    capabilities: [createMojoNodejsCapability()],
    surfaces: ["js"],
    files: {
      "index.ts": `
import type { int32 } from "@tsonic/core/types.js";
import type { ServerResponse } from "node:http";
import process from "node:process";

export function selectArguments(response: ServerResponse, statusCode: int32): string[] {
  response.statusCode = statusCode;
  return process.argv.slice(2);
}

export function main(): void {}
`,
    },
  });
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(source, /tsonic_node\.http\.ServerResponse/u);
  assert.match(source, /\.set_status_code\(Int32\(/u);
  assert.match(source, /tsonic_node\.process\.arguments\(\)/u);
  assert.match(source, /tsonic_js\.JsArray\[tsonic_js\.JsString\]/u);
  assert.match(source, /\.slice\(Float64\(2\)\)/u);
});

test("bare Node aliases retain canonical provider identities", () => {
  const result = compileNode(`
import { basename } from "path";
export function main(): void { basename("/one/two.txt"); }
`);
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /tsonic_node\.path\.basename/u);
});

test("filesystem promises retain source Promise and native Future contracts", () => {
  const result = compileNode(`
import { Buffer } from "node:buffer";
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";

export async function main(): Promise<void> {
  await mkdir("work", { recursive: true });
  await writeFile("work/value.txt", Buffer.from("value"));
  const bytes = await readFile("work/value.txt");
  bytes.toString();
  const text = await readFile("work/value.txt", "utf8");
  const entries = await readdir("work");
  const metadata = await stat("work/value.txt");
  metadata.isFile();
  await rename("work/value.txt", "work/next.txt");
  if (text.length + entries.length === 0) return;
  await rm("work", { recursive: true, force: true });
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "filesystem_promises.make_directory",
    "filesystem_promises.write_file",
    "filesystem_promises.read_file",
    "filesystem_promises.read_text_file",
    "filesystem_promises.read_directory",
    "filesystem_promises.stat",
    "filesystem_promises.rename_path",
    "filesystem_promises.remove_path",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
  assert.match(source, /await create_raising_task\(/u);
  assert.match(source, /async def __tsonic_async_entry\(\) raises:\n    await create_raising_task\(__tsonic_entry\(\)\)/u);
});

test("long-lived Node callbacks erase closed source errors only at the provider ABI", () => {
  const result = compileNode(`
import { setInterval } from "node:timers";

function read(): string {
  throw new Error("failed");
}

export function main(): void {
  setInterval(() => {
    read();
  }, 10);
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(source, /tsonic_runtime\.erase_callable_error/u);
  assert.match(source, /RaisingCallable/u);
  assert.match(source, /tsonic_node\.timers\.set_interval/u);
});

test("events, streams, readline, and worker channels cross the target boundary", () => {
  const result = compileNode(`
import { EventEmitter, listenerCount } from "node:events";
import type { Readable, Writable } from "node:stream";
import { createInterface } from "node:readline";
import {
  MessageChannel,
  getEnvironmentData,
  isMainThread,
  receiveMessageOnPort,
  setEnvironmentData,
} from "node:worker_threads";

export function connectStreams(input: Readable, output: Writable): void {
  input.pipe(output);
  const lines = createInterface({ input, output, terminal: false, prompt: "> " });
  lines.question("name? ", (answer) => { output.write(answer); });
  lines.close();
}

export function main(): void {
  const emitter = new EventEmitter();
  emitter.on("ready", () => {});
  emitter.emit("ready");
  listenerCount(emitter, "ready");

  const channel = new MessageChannel();
  channel.port2.on("message", (value) => { value; });
  channel.port1.postMessage("payload");
  receiveMessageOnPort(channel.port2);
  setEnvironmentData("mode", "test");
  getEnvironmentData("mode");
  if (!isMainThread) throw new Error("unexpected worker context");
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "events.event_emitter_new",
    ".on_callable(",
    ".emit_callable(",
    "events.listener_count",
    ".pipe_to(",
    "readline.create_interface",
    "worker_threads.message_channel_new",
    ".post_message(",
    "worker_threads.receive_message_on_port",
    "worker_threads.set_environment_data",
    "worker_threads.get_environment_data",
    "worker_threads.is_main_thread",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
});

test("DNS, sockets, TLS, HTTPS, and compression retain their exact target carriers", () => {
  const result = compileNode(`
import { Buffer } from "node:buffer";
import { lookup, resolve4 } from "node:dns";
import { createConnection, createServer as createNetServer, isIP } from "node:net";
import { connect as connectTls, createServer as createTlsServer } from "node:tls";
import { createServer as createHttpsServer, get as httpsGet } from "node:https";
import {
  createGzip,
  gzip,
  gzipSync,
  gunzipSync,
} from "node:zlib";

export function main(): void {
  lookup("localhost", (error, address, family) => { error; address; family; });
  resolve4("localhost", (error, addresses) => { error; addresses; });
  isIP("127.0.0.1");
  const socket = createConnection(443, "localhost", () => {});
  socket.write("hello");
  socket.end();
  const netServer = createNetServer((client) => { client.end("done"); });
  netServer.listen(8080, "127.0.0.1", () => {});
  netServer.close();

  const tls = connectTls({ host: "localhost", port: 443, rejectUnauthorized: true });
  tls.write("hello");
  tls.end();
  const tlsServer = createTlsServer({ key: "key.pem", cert: "cert.pem" }, (client) => { client.end(); });
  tlsServer.listen(8443, "127.0.0.1", () => {});
  tlsServer.close();

  const httpsServer = createHttpsServer({ key: "key.pem", cert: "cert.pem" }, (request, response) => {
    request.url;
    response.end("ok");
  });
  httpsServer.listen(8443, "127.0.0.1", () => {});
  httpsServer.close();
  httpsGet("https://localhost/", (response) => { response.url; });

  const input = Buffer.from("payload");
  const compressed = gzipSync(input, { level: 1, maxOutputLength: 4096 });
  gunzipSync(compressed);
  gzip(input, (error, output) => { error; output.toString(); });
  const stream = createGzip();
  stream.write(input);
  stream.end();
  stream.read();
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "dns.lookup",
    "dns.resolve4",
    "net.create_connection_host_callback",
    "net.create_server_callback",
    "tls.connect",
    "tls.create_server",
    "https.create_server",
    "https.get",
    "zlib.gzip_sync_options",
    "zlib.gunzip_sync",
    "zlib.gzip_callback",
    "zlib.create_gzip",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
});

test("Worker construction rejects at its exact selected source-module boundary", () => {
  const result = compileNode(`
import { Worker } from "node:worker_threads";
export function main(): void { new Worker("./worker.js"); }
`);
  assert.deepEqual(result.artifacts, []);
  assert.deepEqual(result.diagnostics.map(({ code }) => code), [
    "MOJO_NODE_WORKER_SOURCE_MODULE_CONSTRUCTION_UNAVAILABLE",
  ]);
});

test("open resource and dynamic utility lanes fail at their exact boundaries", () => {
  assert.throws(
    () => compileNode(`import { watch } from "node:fs"; export function main(): void { watch("."); }`),
    /TS2305/u,
  );
  assert.throws(
    () => compileNode(`import process from "node:process"; export function main(): void { process.stdin; }`),
    /TS2339/u,
  );
  const dynamic = compileNode(`
import { inspect } from "node:util";
export function main(): void { inspect({ value: 1 }); }
`);
  assert.deepEqual(dynamic.artifacts, []);
  assert.deepEqual(dynamic.diagnostics.map(({ code }) => code), [
    "MOJO_CALL_TARGET_UNSUPPORTED",
  ]);
});
