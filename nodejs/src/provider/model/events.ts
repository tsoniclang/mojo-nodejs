import { mojoCallableTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { instanceCall } from "./operations/calls.js";
import { nativeString, unitCarrier } from "./carriers.js";
import { overloadedMethodMember } from "./declarations.js";
import { providerCallbackType, providerRef } from "./source-types.js";
import type { ProviderTypeExpression } from "./types.js";

export interface NodeEventDefinition {
  readonly suffix: string;
  readonly names: readonly string[];
  readonly parameters: readonly {
    readonly name: string;
    readonly source: ProviderTypeExpression;
    readonly target: MojoTargetTypeRef;
  }[];
}

export function nodeEventMembers(module: string, name: string, events: readonly NodeEventDefinition[]) {
  const owner = `${module}::${name}`;
  return ["on", "once", "off"].map((method) => overloadedMethodMember(owner, method,
    events.map((event) => ({
      signatureSuffix: event.suffix,
      parameters: [
        { name: "event", type: event.names.length === 1
          ? { kind: "literal" as const, value: event.names[0]! }
          : { kind: "union" as const, types: event.names.map((value) => ({ kind: "literal" as const, value })) } },
        { name: "listener", type: providerCallbackType(`${owner}.${method}(${event.suffix})`, "listener",
          event.parameters.map((parameter) => ({ name: parameter.name, type: parameter.source }))) },
      ],
      returnType: providerRef(module, name),
    }))));
}

export function nodeEventOperations(module: string, name: string, receiver: MojoTargetTypeRef, events: readonly NodeEventDefinition[]) {
  const owner = `${module}::${name}`;
  return ["on", "once", "off"].flatMap((method) => events.map((event) =>
    instanceCall(owner, `${owner}.${method}`, `${owner}.${method}(${event.suffix})`,
      `${method}_${event.suffix}`, receiver, [nativeString, mojoCallableTargetType(
        event.parameters.map((parameter) => ({ convention: "imm", passing: "plain", type: parameter.target })),
        unitCarrier, true,
      )], receiver, true, "mut")));
}
