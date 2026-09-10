import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";
import { withNodeModuleObjects } from "../../dist/provider/module-objects.js";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";

test("ordinary default module objects project the same exact named signatures", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  for (const moduleSpecifier of ["node:child_process", "node:dns", "node:dns/promises", "node:https", "node:net", "node:readline", "node:tls", "node:worker_threads", "node:zlib"]) {
    const module = definition.modules.find((entry) => entry.moduleSpecifier === moduleSpecifier);
    const object = module.exports.find((entry) => entry.exportKind === "default");
    assert.ok(object, moduleSpecifier);
    for (const declaration of module.exports.filter((entry) => entry.kind === "function")) {
      const member = object.members.find((entry) => entry.name === declaration.name);
      assert.ok(member, `${moduleSpecifier}:${declaration.name}`);
      for (const sourceSignature of declaration.signatures) {
        const signature = member.signatures.find((entry) => entry.id === `${member.id}#${sourceSignature.id}`);
        assert.ok(signature, sourceSignature.id);
        assert.notEqual(signature.id, sourceSignature.id);
        assert.deepEqual(signature.parameters, sourceSignature.parameters);
        for (const named of definition.operations.filter((entry) => entry.exportId === declaration.id && entry.signatureId === sourceSignature.id)) {
          const projected = definition.operations.find((entry) => entry.exportId === object.id && entry.memberId === member.id && entry.signatureId === signature.id);
          assert.ok(projected, signature.id);
          assert.deepEqual(projected.target, named.target);
          assert.deepEqual(projected.parameterTypes, named.parameterTypes);
          assert.deepEqual(projected.resultType, named.resultType);
        }
      }
    }
  }
});

test("module projection rejects an operation with an undeclared signature", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  const original = definition.modules.find((entry) => entry.moduleSpecifier === "node:dns");
  const module = { ...original, exports: original.exports.filter((entry) => entry.exportKind !== "default") };
  const operation = definition.operations.find((entry) => entry.exportId === "node:dns::lookup");
  assert.throws(() => withNodeModuleObjects({
    ...definition, modules: [module], operations: [{ ...operation, signatureId: "unrelated.signature" }],
  }), /undeclared signature 'unrelated\.signature'/u);
});

test("default module calls compile through their exact named operation contracts", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import dns from "node:dns";
import zlib from "node:zlib";
import net from "node:net";
import workers from "node:worker_threads";
import { Buffer } from "node:buffer";
import path, { sep } from "node:path";
export function main(): void {
  dns.lookup("127.0.0.1", (error, address, family) => {
    if (address !== undefined) { address.length; }
  });
  zlib.gunzipSync(zlib.gzipSync(Buffer.from("module"))).toString();
  net.isIPv4("127.0.0.1");
  const mainThread = workers.isMainThread;
  const sameSeparator = path.sep === sep;
}
` } });
  assert.deepEqual(result.diagnostics, []);
});
