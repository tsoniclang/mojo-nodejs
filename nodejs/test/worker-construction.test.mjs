import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

function compile(files, options = {}) {
  return compileMojo({ files, capabilities: [createMojoNodejsCapability()], target: { id: "mojo", options } });
}

test("selected Worker module identities produce closed pre-source entry dispatch", () => {
  const result = compile({
    "index.ts": `import { Worker as Background } from "node:worker_threads";
export function main(): void { const worker = new Background("./child.js", { workerData: 42 }); worker.on("online", () => {}); worker.on("message", (value) => {}); }`,
    "child.ts": `import { parentPort, workerData } from "node:worker_threads";
if (parentPort !== undefined) parentPort.postMessage(workerData);`,
  });
  assert.deepEqual(result.diagnostics, []);
  const files = artifactTexts(result);
  const entry = files.find(({ path }) => path.endsWith("/main.mojo"));
  assert.ok(entry);
  assert.match(entry.text, /source_module_entry\(/u);
  assert.match(entry.text, /source_module_complete\(True/u);
  assert.match(entry.text, /source_module_complete\(False/u);
  assert.ok(entry.text.indexOf("source_module_entry(") < entry.text.indexOf("_entry()"));
  const call = files.find(({ text }) => text.includes("worker_new("));
  assert.ok(call);
  assert.doesNotMatch(call.text, /worker_new\("\.\/child\.js"/u);
});

test("unrelated same-named constructors do not create a source-module dispatcher", () => {
  const result = compile({ "index.ts": `class Worker { constructor(path: string) {} } export function main(): void { new Worker("anything"); }` });
  assert.deepEqual(result.diagnostics, []);
  for (const { text } of artifactTexts(result)) assert.doesNotMatch(text, /source_module_entry/u);
});

for (const [label, source, code, options] of [
  ["dynamic module", 'function launch(path: string): void { new Worker(path); } export function main(): void { launch("./child.js"); }', "MOJO_SOURCE_MODULE_ARGUMENT_NOT_STATIC", {}],
  ["unresolved module", 'export function main(): void { new Worker("./missing.js"); }', "MOJO_SOURCE_MODULE_ARGUMENT_NOT_PROJECT_SOURCE", {}],
  ["library output", 'export function main(): void { new Worker("./child.js"); }', "MOJO_SOURCE_MODULE_CONSTRUCTION_REQUIRES_BINARY", { outputType: "lib" }],
]) {
  test(`Worker ${label} fails at its exact module boundary`, () => {
    const result = compile({ "index.ts": `import { Worker } from "node:worker_threads"; ${source}`, "child.ts": "export const value = 1;" }, options);
    assert.deepEqual(result.artifacts, []);
    assert.ok(result.diagnostics.some((diagnostic) => diagnostic.code === code), JSON.stringify(result.diagnostics));
  });
}
