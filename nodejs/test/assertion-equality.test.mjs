import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("Node equality assertions retain exact source-number and reference carriers", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { strictEqual as same, notStrictEqual as different } from "node:assert";
import { Buffer } from "node:buffer";
export function main(): void {
  same(Number.NaN, Number.NaN);
  different(-0, 0);
  same(1, 1);
  const bytes = Buffer.from("bytes");
  const retained = bytes;
  same(bytes, retained);
  different(bytes, Buffer.from("bytes"));
  let caught = false;
  try { same(-0, 0, "different zeros"); } catch { caught = true; }
  same(caught, true);
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = projectArtifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /strict_equal(?:\[|\()/u);
  assert.match(output, /not_strict_equal(?:\[|\()/u);
  assert.doesNotMatch(output, /buffer_to_js_value\(/u);
});
