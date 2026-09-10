import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
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
      assert.equal(relations.length, 1, signature.id);
      assert.equal(relations[0].parameterTypes.length, signature.parameters.length, signature.id);
    }
  }
  for (const name of ["write", "fill", "indexOf", "lastIndexOf", "includes", "allocUnsafe", "allocUnsafeSlow", "of", "isEncoding"]) {
    assert.ok(buffer.members.some((member) => member.name === name), name);
  }
  assert.equal(buffer.members.filter((member) => member.name === "compare").length, 2);
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
  const source = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const operation of ["buffer_from_buffer", "fill_number", "find_string", "last_buffer", "includes_number", "buffer_compare", "buffer_transcode"]) {
    assert.ok(source.includes(operation), operation);
  }
});
