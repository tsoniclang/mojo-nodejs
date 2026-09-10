import { mojoOptionalTargetType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  bufferCarrier, instanceCall, nativeString, numberType, optionalFloat64Carrier,
  overloadedMethodMember, providerRef, stringType, undefinedType, nullType,
} from "../../model.js";

const result = Object.freeze({ kind: "union" as const,
  types: Object.freeze([providerRef("node:buffer", "Buffer"), stringType, nullType]) });
const chunk = mojoUnionTargetType([bufferCarrier, nativeString]);
const size = Object.freeze({ kind: "union" as const, types: Object.freeze([numberType, undefinedType]) });

export function readableReadMember(owner: string) {
  return overloadedMethodMember(owner, "read", [
    { signatureSuffix: "", parameters: [], returnType: result },
    { signatureSuffix: "size", parameters: [{ name: "size", type: size }], returnType: result },
  ]);
}

export function readableReadOperations(owner: string, receiver: MojoTargetTypeRef) {
  return [
    instanceCall(owner, `${owner}.read`, `${owner}.read()`, "read", receiver, [], mojoOptionalTargetType(chunk), true, "mut"),
    instanceCall(owner, `${owner}.read`, `${owner}.read(size)`, "read_sized", receiver, [optionalFloat64Carrier], mojoOptionalTargetType(chunk), true, "mut"),
  ];
}
