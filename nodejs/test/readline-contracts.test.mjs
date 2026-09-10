import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("readline retains exact selected input, options and nested callbacks", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream, createWriteStream } from "node:fs";
import { createInterface as linesFrom } from "node:readline";
export function begin(path: string): () => string {
  let trace = "";
  const input = createReadStream(path, { highWaterMark: 1 });
  const output = createWriteStream(path + ".answers");
  const lines = linesFrom({ input, output, terminal: true, historySize: 2, removeHistoryDuplicates: true });
  const alias = lines;
  lines.question("first? ", (first): void => {
    trace += first;
    alias.question("second? ", (second): void => {
      trace += second;
      lines.close();
      input.close();
      output.end();
    });
  });
  return (): string => trace;
}` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map((entry) => entry.text).join("\n");
  for (const member of ["create_interface", "question", "historySize", "removeHistoryDuplicates"]) {
    assert.ok(emitted.includes(member), member);
  }
  assert.doesNotMatch(emitted, /unsafe_bitcast.*Interface/u);
});

test("readline source options and callbacks cannot drift from their selected types", () => {
  for (const statement of [
    "createInterface({ input, historySize: 'two' });",
    "createInterface({ input, removeHistoryDuplicates: 1 });",
    "lines.question('name?', (answer: number): void => {});",
    "lines.line = 'not an input operation';",
    "lines.write(42);",
  ]) {
    assert.throws(() => compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
export function main(): void {
  const input = createReadStream("input");
  const lines = createInterface({ input });
  ${statement}
}` } }), /TypeScript diagnostics:/u, statement);
  }
});
