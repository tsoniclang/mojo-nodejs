import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

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
