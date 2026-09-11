import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("TLS and HTTPS retain explicit context, credentials and independent security controls", () => {
  const result = compileMojo({ target: { id: "mojo", options: { outputType: "lib" } }, capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createSecureContext as makeContext, connect, createServer } from "node:tls";
import { request, createServer as createHttpsServer } from "node:https";
import type { Buffer } from "node:buffer";
export function configure(key: string, cert: string, pfx: Buffer): void {
  const context = makeContext({ key, cert, passphrase: "secret", ca: [cert], minVersion: "TLSv1.2", maxVersion: "TLSv1.3" });
  const alias = context;
  connect({ host: "localhost", port: 443, secureContext: alias, rejectUnauthorized: true });
  connect({ key, cert, ca: [cert], passphrase: "secret", minVersion: "TLSv1.3", rejectUnauthorized: false });
  createServer({ pfx, passphrase: "secret", ca: [cert], requestCert: true, rejectUnauthorized: true, minVersion: "TLSv1.2", maxVersion: "TLSv1.2" });
  createHttpsServer({ pfx, passphrase: "secret", maxVersion: "TLSv1.3" }, (req, res) => { res.end("secure"); });
  request({ hostname: "localhost", secureContext: context, rejectUnauthorized: true }).end();
  makeContext();
}
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const name of ["create_secure_context", "secure_context", "passphrase", "request_cert", "min_version", "max_version"]) assert.ok(emitted.includes(name), name);
});

test("opaque TLS contexts cannot be fabricated from ordinary records", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { connect } from "node:tls";
export function main(): void { connect({ secureContext: {} }); }
` } });
  assert.ok(result.diagnostics.length > 0);
  assert.equal(result.artifacts.length, 0);
});
