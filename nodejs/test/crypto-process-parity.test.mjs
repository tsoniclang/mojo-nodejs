import assert from "node:assert/strict";
import test from "node:test";
import { createMojoNodejsCapability } from "../../dist/index.js";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";

test("cryptographic identities preserve binary overloads, result carriers and errors", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  for (const name of ["Hash", "Hmac"]) {
    const identity = `node:crypto::${name}`;
    const operations = definition.operations.filter((operation) => operation.exportId === identity);
    assert.equal(operations.length, 4);
    assert.ok(operations.every((operation) => operation.raises === true));
    assert.equal(operations.find((operation) => operation.signatureId === `${identity}.digest()`).resultType.id, "tsonic.mojo.node.Buffer");
    for (const suffix of ["string", "buffer"]) {
      assert.equal(operations.find((operation) => operation.signatureId === `${identity}.update(${suffix})`).resultType.id, `tsonic.mojo.node.${name}`);
    }
  }
});

test("crypto and process exports cross the complete selected-provider boundary", () => {
  const result = compileMojo({
    capabilities: [createMojoNodejsCapability()],
    files: { "index.ts": `
      import { createHash, createHmac, randomBytes, randomUUID } from "node:crypto";
      import process, { stdin, version } from "node:process";
      export function main(): void {
        const bytes = randomBytes(16);
        createHmac("sha256", bytes).update(bytes).digest();
        createHmac("sha256", "key").update("data").digest("hex");
        createHash("sha512").update(bytes).digest();
        randomUUID();
        stdin.isPaused();
        process.stdin.isPaused();
        version; process.version;
      }
    ` },
  });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const name of ["create_hmac", "random_bytes", "random_uuid", "update_buffer", "update_string", "stdin", "version"]) {
    assert.ok(emitted.includes(name), name);
  }
});
