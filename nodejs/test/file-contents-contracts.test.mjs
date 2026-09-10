import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("whole-file sync and promise calls share exact byte and encoding relations", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  for (const asynchronous of [false, true]) {
    const specifier = asynchronous ? "node:fs/promises" : "node:fs";
    const module = definition.modules.find((entry) => entry.moduleSpecifier === specifier);
    for (const [name, count] of [["readFile", 2], ["writeFile", 3], ["appendFile", 3]]) {
      const declaration = module.exports.find((entry) => entry.name === (asynchronous ? name : `${name}Sync`));
      assert.equal(declaration.signatures.length, count);
      for (const signature of declaration.signatures) {
        const rows = definition.operations.filter((entry) =>
          entry.exportId === declaration.id && entry.signatureId === signature.id && entry.memberId === undefined);
        assert.equal(rows.length, 1, signature.id);
        assert.equal(rows[0].parameterTypes.length, signature.parameters.length, signature.id);
        assert.equal(rows[0].raises, true);
        assert.deepEqual(rows[0].target.modulePath, asynchronous
          ? ["tsonic_node", "filesystem", "promises"] : ["tsonic_node", "filesystem"]);
        if (asynchronous) assert.equal(rows[0].resultType.kind, "future");
        const encoding = signature.parameters.find((parameter) => parameter.name === "encoding");
        if (encoding !== undefined) assert.deepEqual(encoding.type, { kind: "string" });
      }
    }
  }
});

test("file encodings are runtime values with selected string versus Buffer results", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import fs, { readFileSync, writeFileSync, appendFileSync } from "node:fs";
import * as files from "node:fs/promises";
export async function main(): Promise<void> {
  const path = "contents.bin";
  const encoding: string = "hex";
  writeFileSync(path, "4100ff", encoding);
  appendFileSync(path, "Qg==", "base64");
  const data = readFileSync(path);
  data.length;
  const text: string = readFileSync(path, encoding);
  fs.writeFileSync(path, text, encoding);
  fs.appendFileSync(path, data);
  await files.writeFile(path, "é", "latin1");
  await files.appendFile(path, "é", "utf16le");
  const bytes = await files.readFile(path);
  const encoded: string = await files.readFile(path, encoding);
  bytes.length;
  encoded.length;
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("file contracts reject invented boolean encodings and result carriers", () => {
  for (const statement of [
    'readFileSync("file", true);',
    'writeFileSync("file", "data", false);',
    'appendFileSync("file", "data", 42);',
    'const text: string = readFileSync("file");',
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
export function main(): void { ${statement} }
` } }), /TypeScript diagnostics:/u, statement);
  }
});
