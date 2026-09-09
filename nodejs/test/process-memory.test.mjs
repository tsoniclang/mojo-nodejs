import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("named and default process memory calls retain exact native identities", () => {
  const capability = createMojoNodejsCapability();
  const definition = capability.createTargetContributions({})[0].definition;
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:process");
  assert.ok(module);
  const defaultExport = module.exports.find((entry) => entry.exportKind === "default");
  assert.ok(defaultExport);
  for (const [source, target] of [
    ["availableMemory", "available_memory"],
    ["constrainedMemory", "constrained_memory"],
  ]) {
    const declaration = module.exports.find((entry) => entry.name === source);
    assert.ok(declaration);
    const member = defaultExport.members.find((entry) => entry.name === source);
    assert.ok(member);
    const operations = definition.operations.filter((entry) =>
      entry.exportId === declaration.id ||
      (entry.exportId === defaultExport.id && entry.memberId === member.id));
    assert.equal(operations.length, 2);
    for (const operation of operations) {
      assert.equal(operation.target.name, target);
      assert.deepEqual(operation.target.modulePath, ["tsonic_node", "process"]);
      assert.deepEqual(operation.parameterTypes, []);
      assert.deepEqual(operation.resultType, { kind: "source-primitive", name: "float64" });
    }
  }
});
