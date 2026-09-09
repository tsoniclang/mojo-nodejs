import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("file and generic readable streams publish null, not undefined", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  for (const [specifier, name] of [["node:stream", "Readable"], ["node:fs", "ReadStream"]]) {
    const module = definition.modules.find((entry) => entry.moduleSpecifier === specifier);
    const owner = module.exports.find((entry) => entry.name === name);
    const member = owner.members.find((entry) => entry.name === "read");
    assert.equal(member.signatures.length, 1);
    const signature = member.signatures[0];
    assert.equal(signature.returnType.kind, "union");
    assert.equal(signature.returnType.types.some((type) => type.kind === "null"), true);
    assert.equal(signature.returnType.types.some((type) => type.kind === "undefined"), false);
    const rows = definition.operations.filter((entry) => entry.exportId === owner.id &&
      entry.memberId === member.id && entry.signatureId === signature.id);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].resultType.kind, "optional");
  }
});

test("source null narrowing and inherited writable cork count retain exact operations", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { Readable, Writable } from "node:stream";
import { createReadStream, createWriteStream } from "node:fs";
function present(input: Readable): string {
  const chunk = input.read();
  return chunk === null ? "empty" : chunk.toString();
}
function cork(output: Writable): number {
  output.cork(); output.cork(); output.uncork();
  return output.writableCorked;
}
export function main(): void {
  const input = createReadStream("input");
  const chunk = input.read();
  if (chunk !== null) chunk.toString();
  present(input);
  const output = createWriteStream("output");
  cork(output);
  const depth: number = output.writableCorked;
  output.end();
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("stream read does not invent undefined and cork counts are read-only", () => {
  for (const statement of [
    "const chunk: Buffer | undefined = input.read();",
    "output.writableCorked = 2;",
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { Buffer } from "node:buffer";
import { createReadStream, createWriteStream } from "node:fs";
export function main(): void {
  const input = createReadStream("input");
  const output = createWriteStream("output");
  ${statement}
}
` } }), /TypeScript diagnostics:/u);
  }
});
