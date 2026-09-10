import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("base and file streams retain source-selected optional read size", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { createReadStream } from "node:fs";
import type { Readable } from "node:stream";
export function base(source: Readable, size?: number): string {
  const chunk = source.read(size);
  return chunk === null ? "" : typeof chunk === "string" ? chunk : chunk.toString();
}
export function ranged(path: string): string {
  const source = createReadStream(path, { start: 2, end: 6, highWaterMark: 2 });
  const chunk = source.read(3);
  source.close();
  return chunk === null ? "" : typeof chunk === "string" ? chunk : chunk.toString();
}` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.ok(emitted.includes("read_sized"));
});

test("binary read sizes cannot be silently reconstructed from unrelated carriers", () => {
  for (const value of ["'3'", "true", "{}", "null"]) {
    assert.throws(() => compileMojo({
      capabilities: [capability],
      files: { "index.ts": `import { createReadStream } from "node:fs";
export function invalid(path: string): void { createReadStream(path).read(${value}); }` },
    }), /TS(?:2345|2769)/, value);
  }
});
