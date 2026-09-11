import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("process outputs use the canonical writable source and native contract", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import process from "node:process";
import type { Writable } from "node:stream";
function write(output: Writable): void { output.write("hello", "utf8", (error) => { error; }); }
export function main(): void {
  const output = process.stdout;
  const same = process.stdout;
  output.cork();
  write(same);
  output.uncork();
  output.once("finish", () => {});
  output.writableEnded; output.writableCorked; output.fd; output.isTTY;
  output.setDefaultEncoding("utf16le");
  output.writableFinished; output.writableAborted; output.writableHighWaterMark;
  output.writableLength; output.writableNeedDrain; output.writableObjectMode;
  output.destroyed; output.closed; output.errored;
  same.destroy(new Error("cancelled"));
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(emitted, /Writable/u);
  assert.doesNotMatch(emitted, /ProcessWriteStream/u);
});

test("stream lifecycle source contracts reject fabricated error values", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import process from "node:process";
export function main(): void { process.stdout.destroy("not an Error"); }
` } });
  assert.ok(result.diagnostics.length > 0);
  assert.equal(result.artifacts.length, 0);
});
