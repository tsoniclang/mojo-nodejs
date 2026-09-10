import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  bufferCarrier, instanceCall, numberType, optionalFloat64Carrier,
  overloadedMethodMember, providerRef, undefinedType,
} from "../../model.js";

const result = Object.freeze({ kind: "union" as const,
  types: Object.freeze([providerRef("node:buffer", "Buffer"), { kind: "null" as const }]) });
const size = Object.freeze({ kind: "union" as const, types: Object.freeze([numberType, undefinedType]) });

export function readableReadMember(owner: string) {
  return overloadedMethodMember(owner, "read", [
    { signatureSuffix: "", parameters: [], returnType: result },
    { signatureSuffix: "size", parameters: [{ name: "size", type: size }], returnType: result },
  ]);
}

export function readableReadOperations(owner: string, receiver: MojoTargetTypeRef) {
  return [
    instanceCall(owner, `${owner}.read`, `${owner}.read()`, "read", receiver, [], mojoOptionalTargetType(bufferCarrier), true, "mut"),
    instanceCall(owner, `${owner}.read`, `${owner}.read(size)`, "read_sized", receiver, [optionalFloat64Carrier], mojoOptionalTargetType(bufferCarrier), true, "mut"),
  ];
}
