import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();
const definition = capability.createTargetContributions({})[0].definition;

test("Buffer allocation controls have exact distinct static relations and effects", () => {
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:buffer");
  const buffer = module.exports.find((entry) => entry.name === "Buffer");
  const poolSize = buffer.members.find((entry) => entry.name === "poolSize");
  assert.equal(poolSize.static, true);
  assert.equal(poolSize.readonly, false);
  const relations = definition.operations.filter((entry) => entry.memberId === poolSize.id);
  assert.deepEqual(relations.map((entry) => [entry.operationKind, entry.target.kind, entry.target.name]), [
    ["property", "function-read", "buffer_pool_size"],
    ["property-set", "function-write", "set_buffer_pool_size"],
  ]);
  for (const [name, target] of [
    ["allocUnsafe", "buffer_alloc_unsafe"],
    ["allocUnsafeSlow", "buffer_alloc_unsafe_slow"],
  ]) {
    const member = buffer.members.find((entry) => entry.name === name);
    const selected = definition.operations.filter((entry) => entry.memberId === member.id);
    assert.equal(selected.length, 1);
    assert.equal(selected[0].target.name, target);
    assert.equal(selected[0].raises, true);
  }
  const from = buffer.members.find((entry) => entry.name === "from");
  assert.ok(definition.operations.filter((entry) => entry.memberId === from.id).every((entry) => entry.raises === true));
});

test("Buffer allocation property, effects and alias comparisons survive the source boundary", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { Buffer as Bytes } from "node:buffer";
export function allocate(size: number): boolean {
  const original = Bytes.poolSize;
  try {
    Bytes.poolSize = 64;
    Bytes.poolSize += 64;
    const buffer = Bytes.allocUnsafe(size);
    const alias = buffer;
    const view = buffer.subarray();
    const slow = Bytes.allocUnsafeSlow(size);
    const copied = Bytes.from(buffer);
    const independent = Bytes.alloc(size);
    return alias === buffer && view !== buffer && slow !== buffer &&
      copied !== buffer && independent !== buffer;
  } finally {
    Bytes.poolSize = original;
  }
}` },
  });
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const name of ["buffer_pool_size", "set_buffer_pool_size", "buffer_alloc_unsafe", "buffer_alloc_unsafe_slow", "buffer_from_buffer"]) {
    assert.ok(source.includes(name), name);
  }
});

test("Buffer pool settings remain numeric and length stays read-only", () => {
  for (const [expression, diagnostic] of [
    ['Buffer.poolSize = "64"', /TS2322/],
    ['Buffer.alloc(1).length = 2', /TS2540/],
  ]) {
    assert.throws(() => compileMojo({
      capabilities: [capability],
      files: { "index.ts": `import { Buffer } from "node:buffer"; export function invalid(): void { ${expression}; }` },
    }), diagnostic);
  }
});
