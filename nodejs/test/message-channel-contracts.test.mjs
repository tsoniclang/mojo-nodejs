import assert from "node:assert/strict";
import test from "node:test";
import { compileMojo } from "../../../tsonic-mojo/test/helpers/mojo-session.mjs";
import { createMojoNodejsCapability } from "../../dist/index.js";

test("synchronous receive distinguishes a queued undefined from an empty channel", () => {
  const result = compileMojo({ capabilities: [createMojoNodejsCapability()], files: { "index.ts": `
import { MessageChannel, receiveMessageOnPort, markAsUntransferable, isMarkedAsUntransferable } from "node:worker_threads";
export function main(): void {
  const channel = new MessageChannel();
  channel.port1.postMessage(undefined);
  const received = receiveMessageOnPort(channel.port2);
  if (received !== undefined) {
    const undefinedPayload = received.message === undefined;
  }
  const emptyQueue = receiveMessageOnPort(channel.port2) === undefined;
  markAsUntransferable(1);
  const marked = isMarkedAsUntransferable(1);
  channel.port1.close();
  channel.port2.close();
}
` } });
  assert.deepEqual(result.diagnostics, []);
});
