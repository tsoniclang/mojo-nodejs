import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts as artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
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

test("nonliteral options snapshot exact fields rather than reinterpreting source storage", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream, createWriteStream } from "node:fs";
function identity<T>(value: T): T { return value; }
export function main(): void {
  const options = { start: 1, highWaterMark: 2, unrelated: 3 };
  const alias = options;
  createReadStream("input", alias);
  options.highWaterMark = 99;
  createWriteStream("output", identity({ highWaterMark: undefined, encoding: "utf16le" }));
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(emitted, /record_snapshot\.high_water_mark =/u);
  assert.match(emitted, /record_snapshot\.start =/u);
  assert.doesNotMatch(emitted, /record_snapshot\.unrelated =/u);
  assert.match(emitted, /record_snapshot_2\.encoding =/u);
});

test("provider snapshots select exact getter implementations and propagate their errors", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createWriteStream } from "node:fs";
class Options {
  calls: number = 0;
  get highWaterMark(): number { this.calls++; if (this.calls > 1) throw new Error("read twice"); return 3; }
}
export function main(): void {
  const options = new Options();
  try { createWriteStream("output", options); } catch (error) { throw error; }
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(emitted, /record_source\._get_high_water_mark\(/u);
  assert.match(emitted, /record_snapshot\.high_water_mark =/u);
});

test("provider record field values retain source type checking", () => {
  assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream } from "node:fs";
export function main(): void { const options = { highWaterMark: "wrong" }; createReadStream("input", options); }
` } }), /TypeScript diagnostics:/u);
});
