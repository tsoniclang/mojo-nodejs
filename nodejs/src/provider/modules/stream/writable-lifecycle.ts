import { mojoOptionalTargetType, mojoSourceErrorType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, float64Carrier, instanceCall, methodMember,
  nativeString, nullType, numberType, overloadedMethodMember, propertyMember,
  propertyRead, stringType, undefinedType, unitCarrier, voidType,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";

const errorType: ProviderTypeExpression = { kind: "source-global", name: "Error" };
const nullableError: ProviderTypeExpression = { kind: "union", types: [errorType, nullType] };
const optionalError: ProviderTypeExpression = { kind: "union", types: [errorType, nullType, undefinedType] };
const states = [
  ["writable", "writable", booleanType, boolCarrier],
  ["writableEnded", "writable_ended", booleanType, boolCarrier],
  ["writableFinished", "writable_finished", booleanType, boolCarrier],
  ["writableAborted", "writable_aborted", booleanType, boolCarrier],
  ["writableNeedDrain", "writable_need_drain", booleanType, boolCarrier],
  ["writableObjectMode", "writable_object_mode", booleanType, boolCarrier],
  ["destroyed", "destroyed", booleanType, boolCarrier],
  ["closed", "closed", booleanType, boolCarrier],
  ["writableCorked", "writable_corked", numberType, float64Carrier],
  ["writableHighWaterMark", "writable_high_water_mark", numberType, float64Carrier],
  ["writableLength", "writable_length", numberType, float64Carrier],
  ["errored", "errored", nullableError, mojoOptionalTargetType(mojoSourceErrorType())],
] as const;

export function writableLifecycleMembers(owner: string, result: ProviderTypeExpression) {
  return [
    ...["cork", "uncork"].map((name) => methodMember(owner, name, [], voidType)),
    methodMember(owner, "setDefaultEncoding", [{ name: "encoding", type: stringType }], result),
    overloadedMethodMember(owner, "destroy", [
      { signatureSuffix: "", parameters: [], returnType: result },
      { signatureSuffix: "error", parameters: [{ name: "error", type: optionalError }], returnType: result },
    ]),
    ...states.map(([name, , type]) => propertyMember(owner, name, type)),
  ];
}

export function writableLifecycleOperations(owner: string, receiver: MojoTargetTypeRef) {
  return [
    ...["cork", "uncork"].map((name) => instanceCall(owner, `${owner}.${name}`, `${owner}.${name}()`, name, receiver, [], unitCarrier, name === "uncork", "mut")),
    instanceCall(owner, `${owner}.setDefaultEncoding`, `${owner}.setDefaultEncoding(encoding)`, "set_default_encoding", receiver, [nativeString], receiver, true, "mut"),
    instanceCall(owner, `${owner}.destroy`, `${owner}.destroy()`, "destroy", receiver, [], receiver, true, "mut"),
    instanceCall(owner, `${owner}.destroy`, `${owner}.destroy(error)`, "destroy", receiver, [mojoOptionalTargetType(mojoSourceErrorType())], receiver, true, "mut"),
    ...states.map(([name, target, , type]) => propertyRead(owner, `${owner}.${name}`, target, receiver, type, "method")),
  ];
}
