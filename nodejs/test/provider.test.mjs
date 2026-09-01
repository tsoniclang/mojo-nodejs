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
    [
      "node:assert",
      "node:buffer",
      "node:child_process",
      "node:crypto",
      "node:fs",
      "node:http",
      "node:os",
      "node:path",
      "node:process",
      "node:timers",
      "node:util",
      "node:url",
    ],
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
  assert.equal(
    definition.operations.find((operation) => operation.exportId === "node:crypto::createHash")?.target.kind,
    "function-call",
  );
  assert.equal(
    definition.operations.find((operation) => operation.exportId === "node:child_process::spawnSync")?.raises,
    true,
  );
  assert.equal(
    definition.operations.find((operation) => operation.exportId === "node:url::parse")?.resultType.id,
    "tsonic.mojo.node.LegacyUrl",
  );
  assert.equal(
    definition.operations.some((operation) => operation.exportId === "node:util::getSystemErrorName"),
    false,
  );
  const createServer = definition.operations.find((operation) =>
    operation.exportId === "node:http::createServer");
  assert.equal(createServer?.parameterTypes?.[0]?.kind, "callable");
  assert.equal(createServer?.parameterTypes?.[0]?.raises, true);
  assert.deepEqual(
    createServer?.parameterTypes?.[0]?.parameters.map(({ type }) => type.id),
    ["tsonic.mojo.node.HttpIncomingMessage", "tsonic.mojo.node.HttpServerResponse"],
  );
  const setInterval = definition.operations.find((operation) =>
    operation.exportId === "node:timers::setInterval");
  assert.equal(setInterval?.parameterTypes?.[0]?.kind, "callable");
  assert.equal(setInterval?.resultType.id, "tsonic.mojo.node.Timeout");
  assert.deepEqual(
    definition.binaryEpilogues.map(({ id, raises }) => [id, raises === true]),
    [["node-event-loop", true], ["node-process-exit-code", false]],
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
