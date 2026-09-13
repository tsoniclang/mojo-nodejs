import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("assert.fail uses exact source Error throwing for all three selected overloads", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { fail as reject } from "node:assert";
export function main(): void {
  try { reject(); } catch (error) { const selected = error as Error; selected.message; }
  try { reject("unreachable"); } catch (error) { const selected = error as Error; selected.name; }
  try { reject(new Error("retained")); } catch (error) { const selected = error as Error; selected.stack; }
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(emitted, /fail_error\(/u);
  assert.match(emitted, /fail\("unreachable"\)/u);
});

test("assert.fail does not accept arbitrary native error-like objects", () => {
  assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { fail } from "node:assert";
export function main(): void { fail(42); }
` } }), /TypeScript diagnostics:/u);
});
