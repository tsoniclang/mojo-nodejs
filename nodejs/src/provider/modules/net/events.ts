import { mojoSourceErrorType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { booleanType, boolCarrier, bufferCarrier, netSocketCarrier, providerRef } from "../../model.js";
import { nodeEventMembers, nodeEventOperations } from "../../model/events.js";
import type { NodeEventDefinition } from "../../model/events.js";

const errors: NodeEventDefinition = {
  suffix: "error", names: ["error"],
  parameters: [{ name: "error", source: { kind: "source-global", name: "Error" }, target: mojoSourceErrorType() }],
};

function events(owner: "Socket" | "Server"): readonly NodeEventDefinition[] {
  return owner === "Socket" ? [
    { suffix: "data", names: ["data"], parameters: [{ name: "chunk", source: providerRef("node:buffer", "Buffer"), target: bufferCarrier }] },
    errors,
    { suffix: "close", names: ["close"], parameters: [{ name: "hadError", source: booleanType, target: boolCarrier }] },
    { suffix: "empty", names: ["connect", "drain", "end", "finish", "readable", "timeout"], parameters: [] },
  ] : [
    { suffix: "connection", names: ["connection"], parameters: [{ name: "socket", source: providerRef("node:net", "Socket"), target: netSocketCarrier }] },
    errors,
    { suffix: "empty", names: ["listening", "close"], parameters: [] },
  ];
}

export function networkEventMembers(name: "Socket" | "Server") {
  return nodeEventMembers("node:net", name, events(name));
}

export function networkEventOperations(name: "Socket" | "Server", receiver: MojoTargetTypeRef) {
  return nodeEventOperations("node:net", name, receiver, events(name));
}
