import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

function compile(files, options = {}) {
  return compileMojo({ files, capabilities: [createMojoNodejsCapability()], target: { id: "mojo", options } });
}

test("worker payload guards recover exact primitive values at their use boundaries", () => {
  const result = compileMojo({ surfaces: ["js"], capabilities: [createMojoNodejsCapability()], files: {
    "index.ts": `import { Worker } from "node:worker_threads";
export function main(): void { new Worker("./child.js", { workerData: 3 }); }`,
    "child.ts": `import { parentPort, workerData } from "node:worker_threads";
if (parentPort === undefined) throw new Error("No parent");
if (typeof workerData !== "number") throw new Error("Not numeric");
const offset = workerData;
const port = parentPort;
port.on("message", (value) => {
  if (typeof value !== "number") throw new Error("Not numeric");
  port.postMessage(value + offset);
});`,
  } });
  assert.deepEqual(result.diagnostics, []);
  const child = artifactTexts(result).find(({ text }) => text.includes("worker_data("));
  assert.ok(child);
  assert.match(child.text, /js_value_number\(worker_data\(\)\)/u);
  assert.match(child.text, /js_value_number\(value\)/u);
});

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
  assert.match(entry.text, /source_module_complete\(\s*False/u);
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

test("a worker in a transitive source package becomes a direct binary artifact dependency only", () => {
  const sourcePackages = {
    fingerprint: "worker-package-closure", rootPackageId: "root",
    packages: [
      { id: "root", name: "root", packageRoot: "/src", sourceRoot: "/src", sourceFiles: ["/src/index.ts"], dependencies: ["factory"], exports: [{ specifier: ".", sourceFile: "/src/index.ts" }], componentId: "root" },
      { id: "factory", name: "factory", packageRoot: "/src/factory", sourceRoot: "/src/factory", sourceFiles: ["/src/factory/index.ts"], dependencies: ["worker"], exports: [{ specifier: ".", sourceFile: "/src/factory/index.ts" }], componentId: "factory" },
      { id: "worker", name: "worker", packageRoot: "/src/factory/worker", sourceRoot: "/src/factory/worker", sourceFiles: ["/src/factory/worker/index.ts"], dependencies: [], exports: [{ specifier: ".", sourceFile: "/src/factory/worker/index.ts" }], componentId: "worker" },
    ],
    components: [
      { id: "root", packages: ["root"], dependencies: ["factory"] },
      { id: "factory", packages: ["factory"], dependencies: ["worker"] },
      { id: "worker", packages: ["worker"], dependencies: [] },
    ],
  };
  const result = compileMojo({
    capabilities: [createMojoNodejsCapability()], sourcePackages,
    files: {
      "index.ts": `import { launch } from "./factory/index.js"; export function main(): void { launch(); }`,
      "factory/index.ts": `import { Worker } from "node:worker_threads"; export function launch(): void { new Worker("./worker/index.js"); }`,
      "factory/worker/index.ts": `import { parentPort } from "node:worker_threads"; if (parentPort !== undefined) parentPort.postMessage(42);`,
    },
  });
  assert.deepEqual(result.diagnostics, []);
  const artifacts = artifactTexts(result);
  const task = result.artifacts.find(({ path }) => path === "pixi.toml");
  assert.ok(task);
  const build = task.text.match(/^build = .*depends-on = \[([^\]]+)\]/mu);
  assert.ok(build);
  assert.equal(build[1].match(/"build_tsonic_dep_[a-f0-9]+"/gu)?.length, 2);
  const entry = artifacts.find(({ path }) => path === "src/main.mojo");
  assert.ok(entry);
  assert.match(entry.text, /source_module_entry/u);
  assert.equal(sourcePackages.components[0].dependencies.length, 1);
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
