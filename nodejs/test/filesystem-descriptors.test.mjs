import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";

const definition = createMojoNodejsCapability().createTargetContributions({ selectedSurfaceIds: ["js"] })[0].definition;
const sourceModule = (specifier) => definition.modules.find((entry) => entry.moduleSpecifier === specifier);
const declaration = (specifier, name) => sourceModule(specifier).exports.find((entry) => entry.name === name);

test("filesystem descriptor operations have one selected relation per overload", () => {
  for (const name of ["openSync", "closeSync", "fstatSync", "readSync", "writeSync", "accessSync", "chmodSync", "truncateSync", "readlinkSync"]) {
    const selected = declaration("node:fs", name);
    assert.ok(selected, name);
    for (const signature of selected.signatures) {
      const rows = definition.operations.filter((entry) => entry.exportId === selected.id && entry.signatureId === signature.id);
      assert.equal(rows.length, 1, signature.id);
      assert.equal(rows[0].parameterTypes.length, signature.parameters.length, signature.id);
      assert.equal(rows[0].raises, true, signature.id);
      assert.deepEqual(rows[0].target.modulePath, ["tsonic_node", "filesystem"]);
    }
  }
});

test("filesystem promise operations retain asynchronous result and error contracts", () => {
  for (const name of ["access", "chmod", "truncate", "readlink"]) {
    const selected = declaration("node:fs/promises", name);
    for (const signature of selected.signatures) {
      const row = definition.operations.find((entry) => entry.exportId === selected.id && entry.signatureId === signature.id);
      assert.equal(signature.returnType.name, "Promise");
      assert.equal(row.resultType.kind, "future");
      assert.equal(row.resultType.raises, true);
      assert.deepEqual(row.target.modulePath, ["tsonic_node", "filesystem", "promises"]);
    }
  }
});

test("filesystem timestamps and retry options have exact read and write projections", () => {
  const selected = declaration("node:fs", "Stats");
  for (const name of ["atime", "atimeMs", "mtime", "mtimeMs", "ctime", "ctimeMs", "birthtime", "birthtimeMs"]) {
    const member = selected.members.find((entry) => entry.name === name);
    assert.ok(member, name);
    const rows = definition.operations.filter((entry) => entry.exportId === selected.id && entry.memberId === member.id);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].operationKind, "property");
  }
  const options = declaration("node:fs", "RmOptions");
  for (const name of ["maxRetries", "retryDelay"]) {
    const member = options.members.find((entry) => entry.name === name);
    assert.equal(member.optional, true);
    assert.notEqual(member.readonly, true);
    assert.equal(definition.operations.filter((entry) => entry.exportId === options.id && entry.memberId === member.id).length, 2);
  }
});

test("default module objects reuse exact named-operation signatures without fallback selection", () => {
  for (const specifier of ["node:fs", "node:fs/promises", "node:crypto", "node:os", "node:url"]) {
    const module = sourceModule(specifier);
    const selected = module.exports.find((entry) => entry.exportKind === "default");
    assert.ok(selected, specifier);
    for (const member of selected.members) {
      const original = module.exports.find((entry) => entry.name === member.name);
      assert.ok(original, member.id);
      assert.notEqual(member.id, original.id);
      const signatures = member.signatures ?? [];
      const sourceSignatures = original.signatures ?? [];
      assert.equal(signatures.length, sourceSignatures.length);
      for (const [index, signature] of signatures.entries()) {
        const source = sourceSignatures[index];
        assert.notEqual(signature.id, source.id);
        assert.deepEqual({ ...signature, id: source.id }, source);
      }
      const sourceRows = definition.operations.filter((entry) => entry.exportId === original.id && entry.memberId === undefined);
      const memberRows = definition.operations.filter((entry) => entry.exportId === selected.id && entry.memberId === member.id);
      assert.equal(memberRows.length, sourceRows.length);
      for (const row of memberRows) {
        const position = signatures.findIndex((signature) => signature.id === row.signatureId);
        const sourceId = row.signatureId === undefined ? undefined : sourceSignatures[position].id;
        const source = sourceRows.find((entry) => entry.signatureId === sourceId);
        assert.deepEqual(row.target, source.target);
        assert.deepEqual(row.parameterTypes, source.parameterTypes);
        assert.deepEqual(row.resultType, source.resultType);
      }
    }
  }
});
