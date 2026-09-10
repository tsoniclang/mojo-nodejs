import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("Buffer erasure uses the selected provider factory through assignments and closed containers", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { Buffer } from "node:buffer";
function retain(value: unknown): unknown { return value; }
export function main(): void {
  const buffer = Buffer.from([1, 2, 3]);
  const saved: unknown = buffer;
  const repeated = retain(buffer);
  const values: unknown[] = [buffer, repeated];
  const selected: Buffer | string = buffer.length > 0 ? buffer : "empty";
  const union: unknown = selected;
  buffer[0] = 9;
  console.log(Buffer.isBuffer(saved), Buffer.isBuffer(values[0]), Buffer.isBuffer(union));
  JSON.stringify(saved); JSON.stringify(values);
  const clone = structuredClone(saved);
  console.log(Buffer.isBuffer(clone), Object.is(saved, repeated));
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(emitted, /buffer_to_js_value\(/u);
  assert.match(emitted, /buffer_is_buffer\(/u);
  assert.doesNotMatch(emitted, /js_value_from_object_entries\(/u);
});

test("same-spelled source classes cannot acquire the provider Buffer factory", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
class Buffer { value = 3; }
export function main(): void { const value: unknown = new Buffer(); console.log(value); }
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.doesNotMatch(emitted, /buffer_to_js_value\(/u);
  assert.match(emitted, /js_value_from_source_object\(/u);
});
