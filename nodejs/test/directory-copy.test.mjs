import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("directory copy consumes selected standard options and synchronous filters", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { cpSync } from "node:fs";
export function main(): void {
  const options = { recursive: true, force: false, errorOnExist: true, dereference: false, verbatimSymlinks: true, preserveTimestamps: true, mode: 0, filter: (source: string, destination: string) => source !== destination };
  cpSync("source", "destination", options);
}
` } });
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /copy_tree\(/);
});

test("asynchronous copy admits native asynchronous and synchronous predicates", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { cp } from "node:fs/promises";
export async function main(): Promise<void> {
  await cp("source", "first", { recursive: true, filter: async (source: string, destination: string) => source !== destination });
  await cp("source", "second", { filter: (source: string, destination: string) => source !== destination });
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("sync copy rejects asynchronous filters instead of treating a promise as truthy", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { cpSync } from "node:fs";
export function main(): void { cpSync("source", "destination", { filter: async () => true }); }
` } });
  assert.ok(result.diagnostics.some((diagnostic) => diagnostic.category === "error"));
});
