import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("readable event evidence retains typed chunks and inherited stream identity", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { Buffer } from "node:buffer";
import { createReadStream, createWriteStream } from "node:fs";
import type { Readable } from "node:stream";
export function observe(path: string): () => string {
  let trace = "";
  const input = createReadStream(path);
  const alias: Readable = input;
  const listener = (chunk: Buffer | string): void => {
    trace += typeof chunk === "string" ? chunk : chunk.toString();
  };
  input.on("data", listener);
  alias.once("data", listener);
  alias.off("data", listener);
  input.on("error", error => { trace += error.message; });
  alias.on("end", () => { trace += "end"; });
  input.once("close", () => { trace += "close"; });
  input.pipe(createWriteStream(path + ".copy"));
  return (): string => trace;
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const operation of ["on_data", "once_data", "off_data", "on_error", "on_empty", "once_empty", "pipe_to"]) {
    assert.ok(emitted.includes(operation), operation);
  }
});

test("readable notifications are independent of data consumption", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { createReadStream } from "node:fs";
export function notifications(path: string): void {
  const input = createReadStream(path);
  input.on("readable", (): void => { input.read(); });
  input.on("pause", (): void => {});
  input.on("resume", (): void => {});
  input.pause();
  input.resume();
}` } });
  assert.deepEqual(result.diagnostics, []);
});

test("readable listeners reject wrong payloads and foreign writable events", () => {
  for (const expression of [
    `on("data", (value: number): void => {})`,
    `on("error", (value: string): void => {})`,
    `on("end", (value: string): void => {})`,
    `on("finish", (): void => {})`,
  ]) {
    assert.throws(() => compileMojo({ capabilities: [capability], files: {
      "index.ts": `import { createReadStream } from "node:fs";
export function invalid(path: string): void { createReadStream(path).${expression}; }`,
    } }), /TS(?:2345|2769)/, expression);
  }
});
