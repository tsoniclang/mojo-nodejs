import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("glob calls retain named, default and dialect provider identities", () => {
  const result = compileMojo({
    capabilities: [createMojoNodejsCapability()],
    files: { "index.ts": `
import path, { matchesGlob as accepts, posix, win32 } from "node:path";
export function match(file: string, pattern: string): boolean {
  return accepts(file, pattern) && path.matchesGlob(file, pattern)
    && posix.matchesGlob(file, pattern) && win32.matchesGlob(file, pattern);
}
export function local(): boolean {
  const matchesGlob = (left: number, right: number): boolean => left === right;
  return matchesGlob(3, 3);
}
export function main(): void { match("file.txt", "*.txt"); local(); }` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  assert.ok(emitted.includes("matches_glob"));
});

test("glob path and pattern require native strings on every public route", () => {
  for (const expression of ["matchesGlob(3, '*')", "path.matchesGlob('x', false)", "win32.matchesGlob({}, '*')", "posix.matchesGlob('x')"]) {
    assert.throws(() => compileMojo({
      capabilities: [createMojoNodejsCapability()],
      files: { "index.ts": `import path, { matchesGlob, win32, posix } from 'node:path';
export function invalid(): void { ${expression}; }` },
    }), /TypeScript diagnostics:/u, expression);
  }
});
