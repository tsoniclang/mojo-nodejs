import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

function compileNode(source) {
  return compileMojo({
    capabilities: [createMojoNodejsCapability()],
    files: { "index.ts": source },
  });
}

test("closed Node parity operations cross the complete target boundary", () => {
  const result = compileNode(`
import assert from "node:assert";
import { Buffer } from "node:buffer";
import process, { argv0, hrtime, memoryUsage, stderr, stdout } from "node:process";

export function main(): void {
  assert(argv0.length >= 0);
  const before = hrtime();
  hrtime(before);
  const memory = memoryUsage();
  memory.rss;
  stdout.write("out");
  stderr.write(Buffer.from("err"));
  process.argv0;
  const source = Buffer.from([0, 1, 2, 3]);
  const target = Buffer.alloc(4);
  source.copy(target);
  source.slice(1, 3);
  source.swap16();
  source.readUInt16BE(0);
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "argument_zero", "hrtime", "hrtime_since", "memory_usage", "stdout", "stderr",
    "buffer_from_numbers", "buffer_alloc", ".copy(", ".slice(", ".swap16(",
    ".read_uint16_be(",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
});

test("bare Node aliases retain canonical provider identities", () => {
  const result = compileNode(`
import { basename } from "path";
export function main(): void { basename("/one/two.txt"); }
`);
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /tsonic_node\.path\.basename/u);
});

test("open stream and dynamic utility lanes fail at their exact boundaries", () => {
  assert.throws(
    () => compileNode(`import { Readable } from "node:stream"; export function main(): void { Readable; }`),
    /Cannot find name 'node:stream'/u,
  );
  assert.throws(
    () => compileNode(`import { watch } from "node:fs"; export function main(): void { watch("."); }`),
    /TS2305/u,
  );
  assert.throws(
    () => compileNode(`import process from "node:process"; export function main(): void { process.stdin; }`),
    /TS2339/u,
  );
  const dynamic = compileNode(`
import { inspect } from "node:util";
export function main(): void { inspect({ value: 1 }); }
`);
  assert.deepEqual(dynamic.artifacts, []);
  assert.deepEqual(dynamic.diagnostics.map(({ code }) => code), [
    "MOJO_CALL_TARGET_UNSUPPORTED",
  ]);
});
