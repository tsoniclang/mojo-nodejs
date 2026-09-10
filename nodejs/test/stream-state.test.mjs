import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("file streams inherit exact independently observable stream state", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { createReadStream, createWriteStream } from "node:fs";
export function state(path: string): boolean {
  const options = { highWaterMark: 3 };
  const output = createWriteStream(path, options);
  options.highWaterMark = 99;
  const initial = output.writable && !output.writableEnded;
  output.cork();
  const accepted = output.write("abc");
  output.close();
  const complete = output.writableEnded && !output.writable;
  const input = createReadStream(path);
  input.close();
  return initial && !accepted && complete && !input.readable && !input.readableEnded;
}` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const name of ["high_water_mark", "readable_ended", "writable_ended"]) {
    assert.ok(emitted.includes(name), name);
  }
});

test("stream completion properties are not user-writable controls", () => {
  for (const expression of [
    "createReadStream(path).readable = true",
    "createReadStream(path).readableEnded = true",
    "createWriteStream(path).writable = true",
    "createWriteStream(path).writableEnded = true",
  ]) {
    assert.throws(() => compileMojo({
      capabilities: [capability],
      files: { "index.ts": `import { createReadStream, createWriteStream } from "node:fs"; export function invalid(path: string): void { ${expression}; }` },
    }), /TS2540/);
  }
});
