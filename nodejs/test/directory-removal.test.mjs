import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("directory removal retains exact named, default and namespace identities", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import fs, { rmdirSync as remove } from "node:fs";
import * as filesystem from "node:fs";
import promises, { rmdir } from "node:fs/promises";
export function direct(path: string): void {
  remove(path);
  fs.rmdirSync(path);
  filesystem.rmdirSync(path);
}
export async function deferred(path: string): Promise<void> {
  await rmdir(path);
  await promises.rmdir(path);
}
export function main(): void {}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = projectArtifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /remove_directory\(/u);
  assert.doesNotMatch(output, /remove_path(?:_default)?\(/u);
});

test("directory removal does not admit wrong path types or recursive compatibility options", () => {
  for (const call of ["rmdirSync(3)", "rmdirSync('path', { recursive: true })"]) {
    assert.throws(() => compileMojo({ capabilities: [capability], files: {
      "index.ts": `import { rmdirSync } from 'node:fs'; export function main(): void { ${call}; }`,
    } }), /TypeScript diagnostics:/u);
  }
});
