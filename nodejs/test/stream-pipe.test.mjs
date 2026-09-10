import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("file and base stream pipes retain the exact selected destination identity", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream, createWriteStream } from "node:fs";
import type { Readable, Writable } from "node:stream";
import type { ServerResponse } from "node:http";
export function begin(path: string): () => number {
  const source = createReadStream(path);
  const first = createWriteStream(path + '.one');
  const second = createWriteStream(path + '.two');
  const same = source.pipe(first);
  source.pipe(second);
  same.cork();
  first.uncork();
  return (): number => same.bytesWritten + second.bytesWritten;
}
export function nativePipe(source: Readable, output: Writable): Writable {
  return source.pipe(output);
}
export function httpPipe(source: Readable, output: ServerResponse): ServerResponse {
  return source.pipe(output);
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  assert.match(emitted, /pipe_to\(/u);
  assert.match(emitted, /pipe_to_response\(/u);
  assert.doesNotMatch(emitted, /while.*\.read\(/u);
});
