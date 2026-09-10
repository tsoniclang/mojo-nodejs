import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("file and base streams select the same encoded completion contracts", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { Buffer } from "node:buffer";
import { createWriteStream } from "node:fs";
import type { Writable } from "node:stream";
export function writeAll(path: string, selected: string | Buffer, encoding?: string): () => number {
  let completed = 0;
  const output = createWriteStream(path);
  const callback = (): void => { completed += 1; };
  output.cork();
  output.write("e9", "hex", callback);
  output.write(Buffer.from("bytes"), "ignored", callback);
  output.write(selected, encoding, callback);
  output.write("text", callback);
  output.write(Buffer.from("bytes"), callback);
  output.end(undefined, undefined, callback);
  return (): number => completed;
}
export function base(output: Writable, selected: string | Buffer | undefined, callback?: () => void): void {
  output.write("e9", "hex");
  output.write(Buffer.from("x"), undefined);
  output.end(selected, undefined, callback);
}` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const target of ["write_string_encoded", "write_buffer_encoded", "write_value_encoded",
    "write_string_callback", "write_buffer_callback", "end_empty_encoded", "end_value_encoded"]) {
    assert.ok(emitted.includes(target), target);
  }
});

test("stream overloads reject invalid chunks, encoding and completion values", () => {
  for (const call of ["write(1)", "write('text', 5)", "write('text', 'utf8', false)",
    "end({}, 'utf8')", "end(undefined, true)"]) {
    assert.throws(() => compileMojo({
      capabilities: [capability],
      files: { "index.ts": `import { createWriteStream } from "node:fs";
export function invalid(path: string): void { createWriteStream(path).${call}; }` },
    }), /TS(?:2345|2769)/, call);
  }
});

test("stream completion errors and lifecycle listeners retain their selected carriers", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { createWriteStream } from "node:fs";
import type { Writable } from "node:stream";
export function observe(path: string): () => string {
  let trace = "";
  const output = createWriteStream(path, { flags: "r" });
  const alias: Writable = output;
  const failed = (error: Error): void => { trace += error.message; };
  output.on("error", failed);
  alias.once("close", (): void => { trace += "closed"; });
  output.on("finish", (): void => { trace += "finished"; });
  output.write("text", error => { trace += error === undefined ? "ok" : error.message; });
  output.end(error => { trace += error === undefined ? "ended" : error.name; });
  alias.off("error", failed);
  return (): string => trace;
}` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const target of ["write_string_callback", "end_callback", "on_error", "once_empty", "off_error", "TsError"]) {
    assert.ok(emitted.includes(target), target);
  }
});

test("stream lifecycle listeners reject wrong selected payloads", () => {
  for (const call of [
    `on("error", (error: number): void => {})`,
    `on("finish", (value: string): void => {})`,
    `write("text", (error: number): void => {})`,
    `end((error: string): void => {})`,
  ]) {
    assert.throws(() => compileMojo({
      capabilities: [capability],
      files: { "index.ts": `import { createWriteStream } from "node:fs";
export function invalid(path: string): void { createWriteStream(path).${call}; }` },
    }), /TS(?:2345|2769)/, call);
  }
});
