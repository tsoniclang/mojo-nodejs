import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("mixed listener arities and emitted payloads remain independent selected contracts", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { EventEmitter } from "node:events";
import { MessageChannel } from "node:worker_threads";
export function main(): void {
  const emitter = new EventEmitter();
  emitter.on("event", () => {});
  emitter.once("event", (value: any) => {});
  emitter.prependListener("event", (first: any, second: any) => {});
  emitter.prependOnceListener("event", (first: any, second: any, third: any) => {});
  emitter.emit("event", 42);
  emitter.emit("event");
  emitter.removeAllListeners("event");
  const channel = new MessageChannel();
  channel.port2.on("message", () => { channel.port1.close(); channel.port2.close(); });
  channel.port1.postMessage(42);
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of ["on_callable", "once_callable1", "prepend_callable2", "prepend_once_callable3", "emit_callable1", "remove_all_listeners_for"])
    assert.ok(output.includes(operation), operation);
});
