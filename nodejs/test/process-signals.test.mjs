import assert from "node:assert/strict";
import test from "node:test";
import { artifactTexts, compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("process signal APIs retain each selected overload and default export identity", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import process, { kill as signal } from "node:process";
import { convertProcessSignalToExitCode } from "node:util";
export function main(): void {
  signal(process.pid, 0);
  signal(process.pid, "SIGCONT");
  process.kill(process.pid, 0);
  process.kill(process.pid, "SIGCONT");
  convertProcessSignalToExitCode("SIGTERM");
}
export function stop(pid: number): void { signal(pid); process.kill(pid); }
` } });
  assert.deepEqual(result.diagnostics, []);
  const emitted = artifactTexts(result).map(({ text }) => text).join("\n");
  for (const operation of ["kill_number", "kill_named", "kill_default", "convert_process_signal_to_exit_code"]) {
    assert.ok(emitted.includes(`${operation}(`), operation);
  }
});
