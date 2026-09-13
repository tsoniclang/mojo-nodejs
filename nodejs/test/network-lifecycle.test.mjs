import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

for (const moduleSpecifier of ["node:http", "node:https", "node:tls"]) {
  test(`${moduleSpecifier} server listen shares exact options and backlog overloads`, () => {
    const result = compileMojo({ target: { id: "mojo", options: { outputType: "lib" } }, capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import type { Server } from "${moduleSpecifier}";
export function start(server: Server): void {
  server.listen({ port: 0, host: "127.0.0.1", backlog: 8 });
  server.listen({ port: 0, backlog: 16 }, () => {});
  server.listen(0);
  server.listen(0, "127.0.0.1");
  server.listen(0, 8);
  server.listen(0, "127.0.0.1", 8, () => {});
}
` } });
    assert.deepEqual(result.diagnostics, []);
    const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
    for (const operation of ["listen_options", "listen_backlog", "listen_host_backlog"]) assert.ok(emitted.includes(`${operation}(`), operation);
  });
}

test("socket construction, connect aliases, peer metadata and listen backlog have exact operations", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { Socket, createServer } from "node:net";
export function main(): void {
  const server = createServer();
  server.listen({ port: 0, host: "127.0.0.1", backlog: 8 });
  const socket = new Socket();
  const alias = socket;
  socket.once("connect", () => { alias.remoteAddress; alias.remotePort; });
  alias.connect(8080, "localhost");
  socket.connecting;
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of ["socket_new", "connect_port_host", "remote_address", "remote_port", "connecting", "listen_options"]) assert.ok(emitted.includes(`${operation}(`), operation);
});
