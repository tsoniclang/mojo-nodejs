import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("util.format consumes its exact closed rest-list operation, including aliases", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { format as display } from "node:util";
export function main(): void {
  const port = display("%s:%d", "port", 80);
  const empty = display();
  const values = display("%O", { port: 80, enabled: true });
  port; empty; values;
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(emitted, /util_format/u);
  assert.match(emitted, /format\(/u);
  assert.match(emitted, /JsValue/u);
});
