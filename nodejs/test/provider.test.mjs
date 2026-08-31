import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("Node capability closes source, target, and runtime contracts together", () => {
  const capability = createMojoNodejsCapability();
  assert.equal(capability.kind, "target-capability");
  assert.equal(capability.targetId, "mojo");
  assert.equal(capability.id, "@tsonic/mojo-nodejs");
  assert.ok(Object.isFrozen(capability));

  const contributions = capability.createTargetContributions({});
  assert.equal(contributions.length, 1);
  const definition = contributions[0].definition;
  assert.ok(Object.isFrozen(definition));
  assert.deepEqual(
    definition.modules.map((module) => module.moduleSpecifier),
    ["node:buffer", "node:fs", "node:os", "node:path", "node:process"],
  );
  assert.equal(
    definition.operations.filter((operation) => operation.exportId === "node:path::basename").length,
    2,
  );
  assert.equal(
    definition.operations.find((operation) => operation.exportId === "node:fs::existsSync")?.raises,
    undefined,
  );
  assert.equal(
    definition.operations.find((operation) => operation.exportId === "node:fs::readFileSync" && operation.signatureId?.endsWith("path,encoding)"))?.raises,
    true,
  );

  const runtime = capability.runtimeContributions({}).references;
  assert.equal(runtime.length, 1);
  assert.equal(runtime[0].kind, "mojo-package-path");
  assert.equal(runtime[0].attributes.packageName, "tsonic_node");
  assert.match(runtime[0].include, /\/mojo-nodejs\/mojo$/u);
});

test("Node aliases materialize the canonical declaration identities", () => {
  const capability = createMojoNodejsCapability();
  let provider;
  const extension = capability.sourceCompilerContributions({}).extensions[0];
  extension.initialize({
    registerSourceDeclarationProvider(value) {
      provider = value;
    },
  });
  assert.equal(provider.ownsModule("path").kind, "owned");
  const resolution = provider.resolveModule("path", {});
  assert.equal(resolution.kind, "virtual");
  const model = provider.getDeclarationModel(resolution, {});
  assert.equal(model.moduleSpecifier, "path");
  assert.ok(model.exports.some((entry) => entry.id === "node:path::normalize"));
});
