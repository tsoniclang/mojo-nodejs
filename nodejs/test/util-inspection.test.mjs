import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("Node inspection consumes exact selected values through all import forms", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [capability], files: { "index.ts": `
import util, { inspect as describe } from "node:util";
import * as tools from "node:util";
import { Buffer } from "node:buffer";
class Counter { count = 1; toJSON(): string { return "not inspection"; } }
export function main(): void {
  const counter = new Counter();
  const saved: unknown = counter;
  counter.count = 2;
  console.log(describe(saved), util.inspect(counter), tools.inspect([counter]));
  console.log(describe(Buffer.from("ok")));
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /inspect\(/u);
  assert.match(output, /js_value_from_source_object\(/u);
  assert.match(output, /buffer_to_js_value\(/u);
  assert.doesNotMatch(output, /js_value_from_object_entries\(/u);
});

test("a same-spelled local inspector retains its project call", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [capability], files: { "index.ts": `
import { inspect as nativeInspect } from "node:util";
function inspect(value: number): number { return value + 1; }
export function main(): void { console.log(nativeInspect(inspect(2))); }
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /def inspect\(/u);
  assert.match(output, /tsonic_node.*util/u);
});

test("unmodeled inspection options are not silently ignored", () => {
  assert.throws(() => compileMojo({ surfaces: ["js"], capabilities: [capability], files: {
    "index.ts": `import { inspect } from 'node:util'; export function main(): void { inspect(1, { depth: 0 }); }`,
  } }), /TypeScript diagnostics:/u);
});
