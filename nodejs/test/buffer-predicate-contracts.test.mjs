import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("Buffer predicate exposes exact generic named and static relations", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:buffer");
  const buffer = module.exports.find((entry) => entry.name === "Buffer");
  const member = buffer.members.find((entry) => entry.name === "isBuffer");
  const named = module.exports.find((entry) => entry.name === "isBuffer");
  assert.equal(member.static, true);
  for (const [declaration, exportId, memberId] of [
    [member, buffer.id, member.id], [named, named.id, undefined],
  ]) {
    assert.equal(declaration.signatures.length, 1);
    const signature = declaration.signatures[0];
    assert.deepEqual(signature.typeParameters, [{ name: "T" }]);
    assert.equal(signature.parameters[0].type.kind, "type-parameter");
    const rows = definition.operations.filter((entry) => entry.exportId === exportId &&
      entry.memberId === memberId && entry.signatureId === signature.id);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].target.name, "buffer_is_buffer");
    assert.equal(rows[0].target.genericParameters[0].name, "T");
    assert.equal(rows[0].target.genericParameters[0].position, "inferred");
    assert.equal(rows[0].target.arguments[0].convention, "imm");
    assert.deepEqual(rows[0].resultType, { kind: "source-primitive", name: "bool" });
  }
});

test("Buffer predicate accepts closed unions and rejects shape-based identity", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], surfaces: ["js"], files: {
    "index.ts": `
import buffers, { Buffer, isBuffer as checkBuffer } from "node:buffer";
export function selected(value: Buffer | string, maybe: Buffer | undefined): boolean {
  return Buffer.isBuffer(value) || checkBuffer(maybe);
}
export function generic<T>(value: T): boolean { return checkBuffer(value); }
export function main(): void {
  const bytes = Buffer.from("bytes");
  Buffer.isBuffer(bytes);
  Buffer.isBuffer(bytes.subarray(1));
  Buffer.isBuffer("bytes");
  Buffer.isBuffer(0);
  Buffer.isBuffer(false);
  Buffer.isBuffer(null);
  Buffer.isBuffer(undefined);
  Buffer.isBuffer([1, 2]);
  Buffer.isBuffer({ length: 5 });
  buffers.isBuffer("bytes");
  generic(bytes);
  generic("bytes");
  selected(bytes, undefined);
}
`,
  } });
  assert.deepEqual(result.diagnostics, []);
});
