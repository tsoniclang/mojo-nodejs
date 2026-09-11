import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("Duplex views compose TCP TLS and compression using provider-stated native relations", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import type { Duplex } from "node:stream";
import type { Socket } from "node:net";
import type { TLSSocket } from "node:tls";
import { createGzip } from "node:zlib";
function send(channel: Duplex): void { channel.write("hello"); channel.end(); }
export function start(socket: Socket, secure: TLSSocket): void {
  send(socket);
  send(secure);
  const compressor = createGzip();
  const view: Duplex = compressor;
  send(view);
  const retained: Duplex[] = [socket, secure, compressor];
  retained[0]?.read();
}
` } });
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /as_duplex\(/);
});
