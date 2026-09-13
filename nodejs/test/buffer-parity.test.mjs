import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();
const definition = capability.createTargetContributions({})[0].definition;

test("Buffer overloads retain exact argument carriers and separate static/instance identities", () => {
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:buffer");
  const buffer = module.exports.find((entry) => entry.name === "Buffer");
  const identities = new Set();
  for (const member of buffer.members) {
    assert.equal(identities.has(member.id), false, member.id);
    identities.add(member.id);
    for (const signature of member.signatures ?? []) {
      const relations = definition.operations.filter((entry) => entry.exportId === buffer.id && entry.memberId === member.id && entry.signatureId === signature.id);
      assert.equal(relations.length, member.kind === "indexer" ? 2 : 1, signature.id);
      const reads = relations.filter((entry) => entry.operationKind !== "index-set");
      assert.equal(reads.length, 1, signature.id);
      assert.equal(reads[0].parameterTypes.length, signature.parameters.length, signature.id);
      if (member.kind === "indexer") {
        const writes = relations.filter((entry) => entry.operationKind === "index-set");
        assert.equal(writes.length, 1);
        assert.equal(writes[0].parameterTypes.length, signature.parameters.length + 1);
        assert.deepEqual(writes[0].parameterTypes.at(-1), reads[0].resultType);
        assert.equal(writes[0].resultType.kind, "unit");
      }
    }
  }
  for (const name of ["write", "fill", "indexOf", "lastIndexOf", "includes", "allocUnsafe", "allocUnsafeSlow", "of", "isEncoding"]) {
    assert.ok(buffer.members.some((member) => member.name === name), name);
  }
  assert.equal(buffer.members.filter((member) => member.name === "compare").length, 2);
});

test("Buffer numeric indexing retains selected absence, mutation and alias contracts", () => {
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { Buffer } from 'node:buffer';
export function main(): void {
  const bytes = Buffer.from('abc');
  const view = bytes.subarray(1);
  view[0] = 258;
  view[1] = undefined;
  const selected: number | undefined = bytes[1];
  if (selected !== undefined) bytes[0] = selected;
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const output = projectArtifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(output, /\.get_index\(/u);
  assert.match(output, /\.set_index\(/u);
});

test("Buffer constructors, aliasing writes, numeric validation and searches are target-selected in a full session", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { Buffer, isAscii, isUtf8, transcode } from "node:buffer";

export function main(): void {
  const first = Buffer.alloc(12, "ab");
  const clone = Buffer.from(first);
  const view = first.subarray(2, 8);
  view.write("é", 0, 2, "utf8");
  view.write("aaaa", "hex");
  view.fill(255, 2, 4);
  view.fill("ff", 0, 2, "hex");
  first.copy(first, 1, 0, 10);
  first.indexOf("ab", 0, "utf8");
  first.lastIndexOf(Buffer.from("ab"));
  first.includes(255);
  Buffer.compare(first, clone);
  first.compare(clone);
  Buffer.isEncoding("utf16le");
  Buffer.byteLength(clone);
  Buffer.concat([first, clone], 10);
  Buffer.of(1, 2, 257);
  isAscii(first);
  isUtf8(first);
  transcode(first, "utf8", "latin1");
  clone.writeInt8(-128, 1);
  clone.readInt8(1);
  clone.toString("hex", 0, 2);
}
` },
  });
  assert.deepEqual(result.diagnostics, []);
  const source = projectArtifactTexts(result).map((entry) => entry.text).join("\n");
  for (const operation of ["buffer_from_buffer", "fill_number", "find_string", "last_buffer", "includes_number", "buffer_compare", "buffer_transcode"]) {
    assert.ok(source.includes(operation), operation);
  }
});
