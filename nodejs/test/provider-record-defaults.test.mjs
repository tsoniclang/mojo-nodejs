import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("provider struct-default literals preserve omitted fields and authored evaluation order", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream } from "node:fs";
function selected(value: number): number { return value; }
export function main(): void {
  createReadStream("input", { start: selected(1), highWaterMark: selected(2) });
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).find(({ text }) => text.includes("create_read_stream("))?.text;
  assert.ok(emitted);
  assert.match(emitted, /= ReadStreamOptions\(\)/u);
  assert.match(emitted, /_provider_record\.start =/u);
  assert.match(emitted, /_provider_record\.high_water_mark =/u);
  assert.doesNotMatch(emitted, /ReadStreamOptions\(\s*(?:start|high_water_mark)=/u);
  assert.ok(emitted.indexOf("selected(Float64(1))") < emitted.indexOf("selected(Float64(2))"));
  assert.doesNotMatch(emitted, /_provider_record\.(?:encoding|flags|mode|end) =/u);
});
