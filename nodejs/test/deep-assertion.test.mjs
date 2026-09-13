import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("deep assertions consume retained closed values and remain distinct from reference equality", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { deepStrictEqual as deep, notStrictEqual } from "node:assert";
import { Buffer } from "node:buffer";
class Counter { value = 1; toJSON(): number { return 99; } }
class OtherCounter { value = 1; }
export function main(): void {
  const first = new Counter();
  const retained: unknown = first;
  first.value = 2;
  const same = new Counter(); same.value = 2;
  deep(retained, same);
  notStrictEqual(first, same);
  deep({ name: "test", values: [1, 2] }, { values: [1, 2], name: "test" });
  deep(Buffer.from("bytes"), Buffer.from("bytes"));
  let rejected = false;
  try { deep(new Counter(), new OtherCounter(), "prototype mismatch"); } catch { rejected = true; }
  deep(rejected, true);
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = projectArtifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /deep_strict_equal\(/u);
  assert.match(output, /deep_strict_equal_with_message\(/u);
  assert.match(output, /not_strict_equal(?:\[|\()/u);
  assert.match(output, /prototype_identity=/u);
  assert.match(output, /buffer_to_js_value\(/u);
});
