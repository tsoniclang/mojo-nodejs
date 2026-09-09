import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

const capability = createMojoNodejsCapability();
const definition = capability.createTargetContributions({})[0].definition;

test("HTTP and HTTPS have exact request options, callbacks, headers and consuming response contracts", () => {
  for (const moduleSpecifier of ["node:http", "node:https"]) {
    const module = definition.modules.find((entry) => entry.moduleSpecifier === moduleSpecifier);
    for (const name of ["request", "get"]) {
      const declaration = module.exports.find((entry) => entry.name === name);
      assert.equal(declaration.signatures.length, 4);
      for (const signature of declaration.signatures) {
        const rows = definition.operations.filter((row) => row.exportId === declaration.id && row.signatureId === signature.id);
        assert.equal(rows.length, 1, signature.id);
        assert.equal(rows[0].parameterTypes.length, signature.parameters.length);
        assert.equal(rows[0].raises, true);
      }
    }
    const client = module.exports.find((entry) => entry.name === "ClientRequest");
    for (const name of ["write", "end", "destroy", "setHeader", "removeHeader", "path", "method", "host", "protocol"]) {
      const member = client.members.find((entry) => entry.name === name);
      assert.ok(member, `${moduleSpecifier}.${name}`);
      const rows = definition.operations.filter((row) => row.exportId === client.id && row.memberId === member.id);
      assert.equal(rows.length, member.signatures?.length ?? 1, member.id);
    }
  }
});

test("path extraction and formatting retain distinct optional-input and parsed-result contracts", () => {
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:path");
  for (const name of ["ParsedPath", "FormatInputPathObject"]) {
    const declaration = module.exports.find((entry) => entry.name === name);
    for (const member of declaration.members) {
      assert.equal(member.optional === true, name === "FormatInputPathObject");
      assert.equal(member.readonly, false);
      const rows = definition.operations.filter((row) => row.exportId === declaration.id && row.memberId === member.id);
      assert.equal(rows.length, 2);
    }
  }
});

test("HTTP and path operations cross the complete checking, analysis and planning boundary", () => {
  const result = compileMojo({
    capabilities: [capability],
    files: { "index.ts": `
import { request } from "node:http";
import { Buffer } from "node:buffer";
import { parse, format, delimiter } from "node:path";

export function main(): void {
  const parsed = parse("./site/../file.md");
  parsed.name = "renamed";
  format(parsed);
  format({ dir: "/tmp", name: "page", ext: "html" });
  const client = request({ hostname: "localhost", port: 18101, path: "/echo", method: "POST" }, response => {
    response.statusCode;
    response.read();
  });
  client.setHeader("Content-Type", "application/octet-stream");
  client.write(Buffer.from(delimiter));
  client.end();
}
` },
  });
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(source, /format_path/u);
  assert.match(source, /set_header/u);
  assert.match(source, /write_buffer/u);
});
