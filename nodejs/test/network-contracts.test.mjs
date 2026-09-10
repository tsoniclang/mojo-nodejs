import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("TCP source options, closed callback payloads and nullable reads select exact native contracts", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import net, { createServer } from "node:net";
export function main(): void {
  const server = createServer({ allowHalfOpen: true, pauseOnConnect: true }, socket => {
    socket.on("data", chunk => { socket.write(chunk); });
    socket.once("end", () => { socket.end(); });
    socket.on("error", error => { error.message.length; });
    socket.on("close", hadError => { const failed: boolean = hadError; });
    const chunk = socket.read();
    if (chunk !== null) { chunk.toString(); }
    socket.setNoDelay().pause().resume().isPaused();
  });
  server.listen(0, "127.0.0.1", () => {
    const address = server.address();
    if (address !== null) {
      const client = net.createConnection({ port: address.port, host: "127.0.0.1", noDelay: true, timeout: 1.5 }, () => {});
      client.setTimeout(0, () => {});
      client.once("drain", () => { client.end("done"); });
    }
  });
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("TCP listener payloads cannot be selected through an unrelated event signature", () => {
  for (const source of [
    'socket.on("data", (chunk: number) => {});',
    'socket.on("close", (hadError: string) => {});',
    'socket.on("error", (error: number) => {});',
    'socket.setTimeout("not a number");',
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createConnection } from "node:net";
export function main(): void { const socket = createConnection(80); ${source} }
` } }), /TypeScript diagnostics:/u, source);
  }
});

test("network event declaration identities own each native relation", () => {
  const definition = createMojoNodejsCapability().createTargetContributions({})[0].definition;
  const module = definition.modules.find((entry) => entry.moduleSpecifier === "node:net");
  for (const name of ["Socket", "Server"]) {
    const owner = module.exports.find((entry) => entry.name === name);
    for (const member of owner.members.filter((entry) => ["on", "once", "off"].includes(entry.name))) {
      for (const signature of member.signatures) {
        const relations = definition.operations.filter((entry) => entry.exportId === owner.id && entry.memberId === member.id && entry.signatureId === signature.id);
        assert.equal(relations.length, 1, signature.id);
        assert.equal(relations[0].parameterTypes[1].parameters.length, signature.parameters[1].type.parameters.length);
      }
    }
  }
});
