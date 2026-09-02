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

test("writable process state seals source-nullable to native-optional conversion", () => {
  const result = compileNode(`
import process from "node:process";

export function main(): void {
  process.exitCode = 2;
  process.exitCode = null;
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  assert.match(source, /tsonic_node\.process\.set_exit_code/u);
  assert.match(source, /Variant\[tsonic_runtime\.Null, Float64\]\(Float64\(2\)\)/u);
  assert.match(source, /\.isa\[Float64\]\(\)/u);
  assert.match(source, /Optional\[Int32\]\(Int32\(/u);
  assert.match(source, /Variant\[tsonic_runtime\.Null, Float64\]\(tsonic_runtime\.Null\(\)\)/u);
  assert.equal(source.match(/tsonic_node\.process\.set_exit_code/gu)?.length, 2);
});

test("bare Node aliases retain canonical provider identities", () => {
  const result = compileNode(`
import { basename } from "path";
export function main(): void { basename("/one/two.txt"); }
`);
  assert.deepEqual(result.diagnostics, []);
  assert.match(artifactTexts(result).map(({ text }) => text).join("\n"), /tsonic_node\.path\.basename/u);
});

test("filesystem promises retain source Promise and native Future contracts", () => {
  const result = compileNode(`
import { Buffer } from "node:buffer";
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";

export async function main(): Promise<void> {
  await mkdir("work", { recursive: true });
  await writeFile("work/value.txt", Buffer.from("value"));
  const bytes = await readFile("work/value.txt");
  bytes.toString();
  const text = await readFile("work/value.txt", "utf8");
  const entries = await readdir("work");
  const metadata = await stat("work/value.txt");
  metadata.isFile();
  await rename("work/value.txt", "work/next.txt");
  if (text.length + entries.length === 0) return;
  await rm("work", { recursive: true, force: true });
}
`);
  assert.deepEqual(result.diagnostics, []);
  const source = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of [
    "filesystem_promises.make_directory",
    "filesystem_promises.write_file",
    "filesystem_promises.read_file",
    "filesystem_promises.read_text_file",
    "filesystem_promises.read_directory",
    "filesystem_promises.stat",
    "filesystem_promises.rename_path",
    "filesystem_promises.remove_path",
  ]) assert.match(source, new RegExp(operation.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&"), "u"));
  assert.match(source, /await create_raising_task\(/u);
  assert.match(source, /async def __tsonic_async_entry\(\) raises:\n    await create_raising_task\(__tsonic_entry\(\)\)/u);
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
