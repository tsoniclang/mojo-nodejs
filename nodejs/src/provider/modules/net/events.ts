import { mojoCallableTargetType, mojoSourceErrorType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, instanceCall, nativeString, netSocketCarrier,
  overloadedMethodMember, providerCallbackType, providerRef, unitCarrier,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";

interface Event {
  readonly suffix: string;
  readonly names: readonly string[];
  readonly parameters: readonly { readonly name: string; readonly source: ProviderTypeExpression; readonly target: MojoTargetTypeRef }[];
}

const errors: Event = {
  suffix: "error", names: ["error"],
  parameters: [{ name: "error", source: { kind: "source-global", name: "Error" }, target: mojoSourceErrorType() }],
};

function events(owner: "Socket" | "Server"): readonly Event[] {
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
  const owner = `node:net::${name}`;
  return ["on", "once", "off"].map((method) => overloadedMethodMember(owner, method,
    events(name).map((event) => ({
      signatureSuffix: event.suffix,
      parameters: [
        { name: "event", type: event.names.length === 1
          ? { kind: "literal" as const, value: event.names[0]! }
          : { kind: "union" as const, types: event.names.map((value) => ({ kind: "literal" as const, value })) } },
        { name: "listener", type: providerCallbackType(`${owner}.${method}(${event.suffix})`, "listener",
          event.parameters.map((parameter) => ({ name: parameter.name, type: parameter.source }))) },
      ],
      returnType: providerRef("node:net", name),
    }))));
}

export function networkEventOperations(name: "Socket" | "Server", receiver: MojoTargetTypeRef) {
  const owner = `node:net::${name}`;
  return ["on", "once", "off"].flatMap((method) => events(name).map((event) =>
    instanceCall(owner, `${owner}.${method}`, `${owner}.${method}(${event.suffix})`,
      `${method}_${event.suffix}`, receiver, [nativeString, mojoCallableTargetType(
        event.parameters.map((parameter) => ({ convention: "imm", passing: "plain", type: parameter.target })),
        unitCarrier, true,
      )], receiver, true, "mut")));
}
