import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
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
  const recovered = saved as Buffer;
  recovered[1] = 7;
  console.log(recovered.toString(), Object.is(recovered, buffer));
  try { (clone as Buffer).toString(); } catch { console.log("not a Buffer"); }
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(emitted, /buffer_to_js_value\(/u);
  assert.match(emitted, /buffer_is_buffer\(/u);
  assert.match(emitted, /buffer_from_js_value\(/u);
  assert.doesNotMatch(emitted, /js_value_from_object_entries\(/u);
});

test("selected Buffer extraction is retained through a nullable union and conditional region", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { Buffer as Bytes } from "node:buffer";
function recover(value: unknown, use: boolean): Bytes | undefined {
  return use ? value as Bytes : undefined;
}
export function main(): void {
  const bytes = Bytes.from("ok");
  const found = recover(bytes, true);
  if (found !== undefined) console.log(found.toString());
  recover({ type: "Buffer", data: [1] }, false);
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(emitted, /buffer_from_js_value\(/u);
  assert.doesNotMatch(emitted, /unsafe_bitcast\[.*Buffer/u);
});

test("same-spelled source classes cannot acquire the provider Buffer factory", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
class Buffer { value = 3; }
export function main(): void { const value: unknown = new Buffer(); console.log(value); }
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  assert.doesNotMatch(emitted, /buffer_to_js_value\(/u);
  assert.match(emitted, /js_value_from_source_object\(/u);
});
