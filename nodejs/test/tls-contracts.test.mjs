import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("TLS declarations preserve duplex events, idle timers and negotiated result alternatives", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import tls from "node:tls";
export function main(): void {
  const server = tls.createServer({ key: "key", cert: "certificate", allowHalfOpen: true, handshakeTimeout: 2500 });
  server.on("tlsClientError", (error, socket) => { error.message.length; socket.destroy(); });
  server.on("secureConnection", socket => {
    socket.on("data", chunk => { socket.write(chunk); });
    socket.once("end", () => { socket.end("complete"); });
    socket.on("error", error => { error.message.length; });
    socket.on("close", hadError => { const failed: boolean = hadError; });
    const chunk = socket.read();
    if (chunk !== null) { chunk.toString(); }
    socket.setNoDelay().pause().resume().isPaused();
  });
  server.listen(0, "127.0.0.1");
  const address = server.address();
  if (address !== null) {
    const client = tls.connect({ port: address.port, host: "localhost", allowHalfOpen: true, timeout: 1.5 });
    client.once("secureConnect", () => { client.end("request"); });
    client.setTimeout(0, () => {});
    const protocol = client.alpnProtocol;
    if (typeof protocol === "string") { protocol.length; }
    const servername = client.servername;
    if (typeof servername === "string") { servername.length; }
  }
}
` } });
  assert.deepEqual(result.diagnostics, []);
});

test("TLS rejects mismatched events and never treats absence as an undefined Buffer", () => {
  for (const expression of [
    'socket.on("data", (chunk: number) => {});',
    'socket.once("close", (error: string) => {});',
    'socket.setTimeout("slow");',
    'const text: string = socket.alpnProtocol;',
    'const name: string = socket.servername;',
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { connect } from "node:tls";
export function main(): void { const socket = connect({ port: 443 }); ${expression} }
` } }), /TypeScript diagnostics:/u, expression);
  }
});
