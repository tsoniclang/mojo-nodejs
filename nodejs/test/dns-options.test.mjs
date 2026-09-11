import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("DNS all/family/one lookup overloads select exact native result and callback shapes", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { lookup, ADDRCONFIG } from "node:dns";
import { lookup as query } from "node:dns/promises";
export async function main(): Promise<void> {
  lookup("localhost", { all: true, family: 4, order: "ipv4first" }, (error, addresses) => { if (addresses) addresses[0].family; });
  lookup("localhost", 4, (error, address, family) => { address; family; });
  lookup("localhost", { hints: ADDRCONFIG }, (error, address, family) => { address; family; });
  const many = await query("localhost", { all: true });
  many[0].address;
  const one = await query("localhost", { family: "IPv4" });
  one.family;
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of ["lookup_all_callback", "lookup_family_callback", "lookup_one_callback", "lookup_all_async", "lookup_one_async"]) assert.ok(emitted.includes(`${operation}(`), operation);
});
