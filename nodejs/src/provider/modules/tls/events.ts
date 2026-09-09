import { mojoSourceErrorType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { booleanType, boolCarrier, bufferCarrier, providerRef, tlsSocketCarrier } from "../../model.js";
import { nodeEventMembers, nodeEventOperations } from "../../model/events.js";
import type { NodeEventDefinition } from "../../model/events.js";

const error = { name: "error", source: { kind: "source-global" as const, name: "Error" }, target: mojoSourceErrorType() };
const socket = { name: "socket", source: providerRef("node:tls", "TLSSocket"), target: tlsSocketCarrier };
const errorEvent: NodeEventDefinition = { suffix: "error", names: ["error"], parameters: [error] };
const socketEvents: readonly NodeEventDefinition[] = [
  { suffix: "data", names: ["data"], parameters: [{ name: "chunk", source: providerRef("node:buffer", "Buffer"), target: bufferCarrier }] },
  errorEvent,
  { suffix: "close", names: ["close"], parameters: [{ name: "hadError", source: booleanType, target: boolCarrier }] },
  { suffix: "empty", names: ["secureConnect", "drain", "end", "finish", "readable", "timeout"], parameters: [] },
];
const serverEvents: readonly NodeEventDefinition[] = [
  { suffix: "tls_client_error", names: ["tlsClientError"], parameters: [error, socket] },
  { suffix: "connection", names: ["secureConnection"], parameters: [socket] },
  errorEvent,
  { suffix: "empty", names: ["listening", "close"], parameters: [] },
];

export function tlsEventMembers(name: "TLSSocket" | "Server") {
  return nodeEventMembers("node:tls", name, name === "TLSSocket" ? socketEvents : serverEvents);
}

export function tlsEventOperations(name: "TLSSocket" | "Server", receiver: MojoTargetTypeRef) {
  return nodeEventOperations("node:tls", name, receiver, name === "TLSSocket" ? socketEvents : serverEvents);
}
