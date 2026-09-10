import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();

test("native filesystem checking never requires an undeclared JS Date", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { statSync } from "node:fs";
export function main(): void { const stats = statSync("index.ts"); stats.mtimeMs; stats.isFile(); }
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("Date-bearing filesystem members are selected only with the JS source surface", () => {
  const source = `
import { statSync } from "node:fs";
export function main(): void { const stats = statSync("index.ts"); stats.mtime.getTime(); stats.atime.toISOString(); }
`;
  const positive = compileMojo({ capabilities: [capability], surfaces: ["js"], files: { "index.ts": source } });
  assert.deepEqual(positive.diagnostics, []);
  const native = compileMojo({ capabilities: [capability], files: { "index.ts": source } });
  assert.ok(native.diagnostics.length > 0);
  assert.ok(native.diagnostics.some((entry) => entry.message.includes("mtime") || entry.message.includes("atime")));
});

test("default module projections never reuse a named export's signature identity", () => {
  const definition = capability.createTargetContributions({ selectedSurfaceIds: ["js"] })[0].definition;
  const identities = new Set();
  for (const module of definition.modules) {
    for (const exported of module.exports) {
      for (const owner of [exported, ...(exported.members ?? [])]) {
        for (const signature of owner.signatures ?? []) {
          assert.equal(identities.has(signature.id), false, signature.id);
          identities.add(signature.id);
        }
      }
    }
  }
});
