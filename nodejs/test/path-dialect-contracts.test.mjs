import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("path dialect values retain all selected method and module identities", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import path, { posix, win32 as windows } from "node:path";
export function main(): void {
  const selected = path.win32;
  const parts = selected.parse("C:\\\\work\\\\file.txt");
  const joined = selected.join(parts.dir, "assets", "image.png");
  const relative = windows.relative(joined, "C:\\\\work\\\\other");
  const absolute = windows.resolve("C:\\\\work", "..", "assets");
  const namespaced = path.win32.toNamespacedPath(absolute);
  const regular = path.toNamespacedPath("/work");
  const formatted = posix.format({ dir: "/work", name: "file", ext: "txt" });
  const mixed = selected.posix.win32.basename("C:\\\\file.txt", ".txt");
  selected.sep; selected.delimiter; namespaced.length; relative.length; regular.length; formatted.length; mixed.length;
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("path dialects do not accept a different argument contract", () => {
  for (const statement of ["win32.join(42);", "posix.resolve(true);", "win32.parse({});", "win32.sep = '/';"]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { win32, posix } from "node:path";
export function main(): void { ${statement} }
` } }), /TypeScript diagnostics:/u, statement);
  }
});
