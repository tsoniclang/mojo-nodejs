import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import test from "node:test";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../src/provider");

test("provider model entrypoint only composes domain-owned implementations", () => {
  const source = ts.createSourceFile("model.ts", readFileSync(resolve(root, "model.ts"), "utf8"), ts.ScriptTarget.Latest, true);
  assert.ok(source.statements.length > 0);
  for (const statement of source.statements) {
    assert.ok(ts.isExportDeclaration(statement));
    assert.match(statement.moduleSpecifier.text, /^\.\/model\//u);
  }
  for (const path of ["source-types.ts", "carriers.ts", "type-definitions.ts", "declarations.ts", "operations/calls.ts", "operations/properties.ts"]) {
    const text = readFileSync(resolve(root, "model", path), "utf8");
    assert.ok(text.split("\n").length <= 600, path);
    assert.doesNotMatch(text, /from\s+["'][^"']*\/model\.js["']/u, path);
  }
});

test("model implementation imports are acyclic and have no old root implementation", () => {
  const edges = new Map();
  function collect(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) collect(path);
      else if (entry.name.endsWith(".ts")) {
        const source = ts.createSourceFile(path, readFileSync(path, "utf8"), ts.ScriptTarget.Latest, true);
        edges.set(path, source.statements.filter(ts.isImportDeclaration)
          .map((declaration) => declaration.moduleSpecifier.text)
          .filter((module) => module.startsWith("."))
          .map((module) => resolve(dirname(path), module.replace(/\.js$/u, ".ts"))));
      }
    }
  }
  collect(resolve(root, "model"));
  const complete = new Set();
  const active = new Set();
  function visit(path) {
    assert.ok(!active.has(path), `cycle at ${path}`);
    if (complete.has(path)) return;
    assert.ok(edges.has(path), `missing owner ${path}`);
    active.add(path);
    for (const dependency of edges.get(path)) visit(dependency);
    active.delete(path);
    complete.add(path);
  }
  for (const path of edges.keys()) visit(path);
});
