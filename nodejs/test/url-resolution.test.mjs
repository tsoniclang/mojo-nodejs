import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("legacy URL resolution is an exact selected provider operation", () => {
  const result = compileMojo({ target: { id: "mojo", options: { outputType: "lib" } }, capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { resolve as combine } from "node:url";
export function main(): string { return combine("http://example.test/a/b", "../c"); }
` } });
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /\.resolve\(/);
});
