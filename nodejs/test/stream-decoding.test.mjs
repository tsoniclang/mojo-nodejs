import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("base and file streams select one exact binary-or-text read contract", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream } from "node:fs";
import type { Readable } from "node:stream";
import type { Buffer } from "node:buffer";
function text(input: Readable): string {
  input.setEncoding("utf8");
  const chunk: Buffer | string | null = input.read(2);
  return chunk === null ? "end" : typeof chunk === "string" ? chunk : chunk.toString();
}
export function main(): void {
  const input = createReadStream("input", { encoding: "utf8", highWaterMark: 1 });
  const alias = input.setEncoding("utf-8");
  text(alias); text(input);
  input.close();
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(emitted, /set_encoding\(/u);
  assert.match(emitted, /read_sized\(/u);
  assert.match(emitted, /Optional\[/u);
  assert.match(emitted, /Variant\[/u);
});

test("decoding options cannot produce a dishonest binary-only or text-only result", () => {
  for (const statement of [
    "input.setEncoding(3);",
    "const chunk: Buffer | null = input.read();",
    "const chunk: string | null = input.read();",
    "createReadStream('input', { encoding: true });",
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream } from "node:fs";
import type { Buffer } from "node:buffer";
export function main(): void { const input = createReadStream("input"); ${statement} }
` } }), /TypeScript diagnostics:/u, statement);
  }
});
