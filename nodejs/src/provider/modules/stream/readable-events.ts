import { mojoSourceErrorType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { bufferCarrier, nativeString, providerRef, stringType } from "../../model.js";
import { nodeEventMembers, nodeEventOperations } from "../../model/events.js";
import type { NodeEventDefinition } from "../../model/events.js";

const events: readonly NodeEventDefinition[] = [
  { suffix: "data", names: ["data"], parameters: [{ name: "chunk",
    source: { kind: "union", types: [providerRef("node:buffer", "Buffer"), stringType] },
    target: mojoUnionTargetType([nativeString, bufferCarrier]),
  }] },
  { suffix: "error", names: ["error"], parameters: [{ name: "error",
    source: { kind: "source-global", name: "Error" }, target: mojoSourceErrorType(),
  }] },
  { suffix: "empty", names: ["end", "close", "readable", "pause", "resume"], parameters: [] },
];

export function readableEventMembers(module: string, name: string) {
  return nodeEventMembers(module, name, events);
}

export function readableEventOperations(module: string, name: string, receiver: MojoTargetTypeRef) {
  return nodeEventOperations(module, name, receiver, events);
}
