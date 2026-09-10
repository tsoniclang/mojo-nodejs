import assert from "node:assert/strict";
import test from "node:test";
import { projectArtifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("OS lookup and DNS record operations retain independent callback and promise entrypoints", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { lookup, resolve4, resolve6, reverse } from "node:dns";
import { lookup as lookupAsync, resolve4 as resolve4Async, resolve6 as resolve6Async, reverse as reverseAsync } from "node:dns/promises";
export async function main(): Promise<void> {
  lookup("localhost", (error, address, family) => {});
  resolve4("example.test", (error, values) => {});
  resolve6("example.test", (error, values) => {});
  reverse("127.0.0.1", (error, values) => {});
  const address = await lookupAsync("localhost");
  const family = address.family;
  const ipv4 = await resolve4Async("example.test");
  const ipv6 = await resolve6Async("example.test");
  const hosts = await reverseAsync("127.0.0.1");
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const text = projectArtifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of ["lookup_callback", "resolve4_callback", "resolve6_callback", "reverse_callback", "lookup_async", "resolve4_async", "resolve6_async", "reverse_async"])
    assert.ok(text.includes(operation), operation);
});
