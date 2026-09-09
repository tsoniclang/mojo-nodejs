import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";

const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
const module = (name) => definition.modules.find((entry) => entry.moduleSpecifier === name);
const declaration = (specifier, name) => module(specifier).exports.find((entry) => entry.name === name);

test("file factories use the existing stream carriers with explicit native options", () => {
  for (const [name, className, streamName] of [
    ["createReadStream", "ReadStream", "Readable"],
    ["createWriteStream", "WriteStream", "Writable"],
  ]) {
    const factory = declaration("node:fs", name);
    const carrier = definition.types.find((entry) => entry.exportId === declaration("node:fs", className).id);
    const stream = definition.types.find((entry) => entry.exportId === declaration("node:stream", streamName).id);
    assert.deepEqual(carrier.targetType, stream.targetType);
    for (const signature of factory.signatures) {
      const selected = definition.operations.filter((entry) => entry.exportId === factory.id && entry.signatureId === signature.id);
      assert.equal(selected.length, 1);
      assert.equal(selected[0].raises, true);
      assert.deepEqual(selected[0].target.modulePath, ["tsonic_node", "filesystem"]);
      assert.deepEqual(selected[0].resultType, stream.targetType);
    }
  }
});

test("watch callbacks and ownership carry exact source-selected contracts", () => {
  const watch = declaration("node:fs", "watch");
  const selected = definition.operations.find((entry) => entry.exportId === watch.id && entry.signatureId.endsWith("path,listener)"));
  assert.equal(selected.parameterTypes[1].kind, "callable");
  assert.equal(selected.parameterTypes[1].parameters[1].type.kind, "optional");
  const watcher = declaration("node:fs", "StatWatcher");
  assert.deepEqual(watcher.members.map((member) => member.name), ["close", "ref", "unref", "hasRef"]);
  const watchFile = declaration("node:fs", "watchFile");
  for (const signature of watchFile.signatures) {
    const operation = definition.operations.find((entry) => entry.exportId === watchFile.id && entry.signatureId === signature.id);
    assert.equal(operation.resultType.name, "FSWatcher");
    assert.equal(operation.raises, true);
  }
});

test("modern URL operations have no missing, unsupported, or guessed relation", () => {
  for (const name of ["URL", "URLSearchParams"]) {
    const source = declaration("node:url", name);
    for (const member of source.members) {
      const operations = definition.operations.filter((entry) => entry.exportId === source.id && entry.memberId === member.id);
      assert.notEqual(operations.length, 0, member.id);
      for (const signature of member.signatures ?? []) {
        assert.equal(operations.filter((entry) => entry.signatureId === signature.id).length, 1, signature.id);
      }
      assert.equal(operations.some((entry) => entry.target.kind === "unsupported"), false, member.id);
    }
  }
  const format = declaration("node:url", "format");
  assert.equal(format.signatures.length, 3);
  for (const signature of format.signatures) {
    assert.equal(definition.operations.filter((entry) => entry.exportId === format.id && entry.signatureId === signature.id).length, 1);
  }
});
