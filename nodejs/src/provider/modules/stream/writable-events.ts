import { mojoSourceErrorType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { nodeEventMembers, nodeEventOperations } from "../../model/events.js";
import type { NodeEventDefinition } from "../../model/events.js";

const events: readonly NodeEventDefinition[] = [
  {
    suffix: "error", names: ["error"], parameters: [
      { name: "error", source: { kind: "source-global", name: "Error" }, target: mojoSourceErrorType() },
    ],
  },
  { suffix: "empty", names: ["drain", "finish", "close"], parameters: [] },
];

export function writableEventMembers(module: string, name: string) {
  return nodeEventMembers(module, name, events);
}

export function writableEventOperations(module: string, name: string, receiver: MojoTargetTypeRef) {
  return nodeEventOperations(module, name, receiver, events);
}
