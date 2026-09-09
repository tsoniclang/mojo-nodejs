import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("DNS error completions use absent outputs and success callbacks retain exact outputs", () => {
  const capability = createMojoNodejsCapability();
  const result = compileMojo({ capabilities: [capability], files: { "index.ts": `
import { lookup, reverse } from "node:dns";
export function main(): void {
  lookup("127.0.0.1", (error, address, family) => {
    if (address !== undefined && family !== undefined) {
      address.length;
      const ipv4 = family === 4;
    }
  });
  reverse("invalid-address", (error, addresses) => {
    if (addresses !== undefined) { addresses.length; }
  });
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const definition = capability.createTargetContributions({})[0].definition;
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:dns");
  const lookup = module.exports.find((entry) => entry.name === "lookup");
  for (const parameter of lookup.signatures[0].parameters[1].type.parameters.slice(1)) {
    assert.equal(parameter.type.kind, "union");
    assert.ok(parameter.type.types.some((entry) => entry.kind === "undefined"));
  }
});
