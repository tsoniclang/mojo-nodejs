import { mojoListTargetType } from "@tsonic/target-mojo/provider";
import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  float64Carrier,
  fnExport,
  functionCall,
  instanceCall,
  methodMember,
  nativeString,
  nodeProviderType,
  numberArrayType,
  numberListCarrier,
  numberType,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  providerRef,
  staticCall,
  staticPropertyRead,
  staticPropertyWrite,
  stringType,
} from "../../model.js";
import { extraBufferMembers, extraBufferOperations } from "./members.js";
import { bufferPredicateExport, bufferPredicateMember, bufferPredicateOperations } from "./predicates.js";

const moduleSpecifier = "node:buffer";
const bufferId = `${moduleSpecifier}::Buffer`;
const bufferType = providerRef(moduleSpecifier, "Buffer");
const bufferListCarrier = mojoListTargetType(bufferCarrier);

interface NumericMember {
  readonly sourceName: string;
  readonly targetName: string;
  readonly write: boolean;
}

const numericMemberRows = [
  ["readUInt8", "read_uint8", false],
  ["readInt8", "read_int8", false],
  ["readUInt16LE", "read_uint16_le", false],
  ["readUInt16BE", "read_uint16_be", false],
  ["readInt16LE", "read_int16_le", false],
  ["readInt16BE", "read_int16_be", false],
  ["readUInt32LE", "read_uint32_le", false],
  ["readUInt32BE", "read_uint32_be", false],
  ["readInt32LE", "read_int32_le", false],
  ["readInt32BE", "read_int32_be", false],
  ["readFloatLE", "read_float_le", false],
  ["readFloatBE", "read_float_be", false],
  ["readDoubleLE", "read_double_le", false],
  ["readDoubleBE", "read_double_be", false],
  ["writeUInt8", "write_uint8", true],
  ["writeInt8", "write_int8", true],
  ["writeUInt16LE", "write_uint16_le", true],
  ["writeUInt16BE", "write_uint16_be", true],
  ["writeInt16LE", "write_int16_le", true],
  ["writeInt16BE", "write_int16_be", true],
  ["writeUInt32LE", "write_uint32_le", true],
  ["writeUInt32BE", "write_uint32_be", true],
  ["writeInt32LE", "write_int32_le", true],
  ["writeInt32BE", "write_int32_be", true],
  ["writeFloatLE", "write_float_le", true],
  ["writeFloatBE", "write_float_be", true],
  ["writeDoubleLE", "write_double_le", true],
  ["writeDoubleBE", "write_double_be", true],
] as const;

const numericMembers: readonly NumericMember[] = Object.freeze(
  numericMemberRows.map(([sourceName, targetName, write]) =>
    Object.freeze({ sourceName, targetName, write })),
);

function numericMember(member: NumericMember) {
  const valueParameters = member.write ? [{ name: "value", type: numberType }] : [];
  return overloadedMethodMember(bufferId, member.sourceName, [
    { parameters: valueParameters, returnType: numberType },
    {
      parameters: [...valueParameters, { name: "offset", type: numberType }],
      returnType: numberType,
    },
  ]);
}

export function bufferModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.buffer",
    exports: Object.freeze([
      Object.freeze({
        id: bufferId,
        name: "Buffer",
        kind: "class",
        members: Object.freeze([
          bufferPredicateMember(),
          overloadedMethodMember(bufferId, "from", [
            { parameters: [{ name: "value", type: stringType }], returnType: bufferType, signatureSuffix: "string" },
            {
              parameters: [{ name: "value", type: stringType }, { name: "encoding", type: stringType }],
              returnType: bufferType,
              signatureSuffix: "string,encoding",
            },
            { parameters: [{ name: "value", type: numberArrayType }], returnType: bufferType, signatureSuffix: "numberArray" },
            { parameters: [{ name: "value", type: bufferType }], returnType: bufferType, signatureSuffix: "buffer" },
          ], { static: true }),
          ...extraBufferMembers(),
          overloadedMethodMember(bufferId, "byteLength", [
            { parameters: [{ name: "value", type: stringType }], returnType: numberType, signatureSuffix: "string" },
            { parameters: [{ name: "value", type: stringType }, { name: "encoding", type: stringType }], returnType: numberType },
            { parameters: [{ name: "value", type: bufferType }], returnType: numberType, signatureSuffix: "buffer" },
          ], { static: true }),
          overloadedMethodMember(bufferId, "concat", [
            { parameters: [{ name: "list", type: { kind: "array", elementType: bufferType } }], returnType: bufferType },
            { parameters: [{ name: "list", type: { kind: "array", elementType: bufferType } }, { name: "totalLength", type: numberType }], returnType: bufferType },
          ], { static: true }),
          overloadedMethodMember(bufferId, "toString", [
            { parameters: [], returnType: stringType },
            { parameters: [{ name: "encoding", type: stringType }], returnType: stringType },
            { parameters: [{ name: "encoding", type: stringType }, { name: "start", type: numberType }], returnType: stringType },
            { parameters: [{ name: "encoding", type: stringType }, { name: "start", type: numberType }, { name: "end", type: numberType }], returnType: stringType },
          ]),
          overloadedMethodMember(bufferId, "copy", [
            { parameters: [{ name: "target", type: bufferType }], returnType: numberType },
            { parameters: [{ name: "target", type: bufferType }, { name: "targetStart", type: numberType }], returnType: numberType },
            { parameters: [{ name: "target", type: bufferType }, { name: "targetStart", type: numberType }, { name: "sourceStart", type: numberType }], returnType: numberType },
            { parameters: [{ name: "target", type: bufferType }, { name: "targetStart", type: numberType }, { name: "sourceStart", type: numberType }, { name: "sourceEnd", type: numberType }], returnType: numberType },
          ]),
          ...["slice", "subarray"].map((name) => overloadedMethodMember(bufferId, name, [
            { parameters: [], returnType: bufferType },
            { parameters: [{ name: "start", type: numberType }], returnType: bufferType },
            { parameters: [{ name: "start", type: numberType }, { name: "end", type: numberType }], returnType: bufferType },
          ])),
          ...["swap16", "swap32", "swap64"].map((name) => methodMember(bufferId, name, [], bufferType)),
          ...numericMembers.map(numericMember),
          methodMember(bufferId, "equals", [{ name: "other", type: bufferType }], booleanType),
          methodMember(bufferId, "compare", [{ name: "other", type: bufferType }], numberType),
          propertyMember(bufferId, "length", numberType),
          propertyMember(bufferId, "poolSize", numberType, { static: true, readonly: false }),
        ]),
      }),
      bufferPredicateExport(),
      fnExport(moduleSpecifier, "isEncoding", [{ name: "encoding", type: stringType }], booleanType),
      fnExport(moduleSpecifier, "isAscii", [{ name: "value", type: bufferType }], booleanType),
      fnExport(moduleSpecifier, "isUtf8", [{ name: "value", type: bufferType }], booleanType),
      fnExport(moduleSpecifier, "transcode", [{ name: "value", type: bufferType }, { name: "fromEncoding", type: stringType }, { name: "toEncoding", type: stringType }], bufferType),
      fnExport(moduleSpecifier, "btoa", [{ name: "value", type: stringType }], stringType),
      fnExport(moduleSpecifier, "atob", [{ name: "value", type: stringType }], stringType),
    ]),
  });
}

export function bufferTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(bufferId, bufferCarrier, "implicitly-copyable"),
  ]);
}

function staticOperation(
  member: string,
  signature: string,
  target: string,
  parameters: readonly MojoTargetTypeRef[],
  result: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return staticCall(bufferId, `${bufferId}.${member}`, `${bufferId}.${member}(${signature})`, "buffer", target, parameters, result, raises);
}

function instanceOperation(
  member: string,
  signature: string,
  target: string,
  parameters: readonly MojoTargetTypeRef[],
  result: MojoTargetTypeRef,
  raises = false,
  receiver: "imm" | "mut" = "imm",
): MojoProviderOperationDefinition {
  return instanceCall(bufferId, `${bufferId}.${member}`, `${bufferId}.${member}(${signature})`, target, bufferCarrier, parameters, result, raises, receiver);
}

function numericOperations(member: NumericMember): readonly MojoProviderOperationDefinition[] {
  const valueTypes = member.write ? [float64Carrier] : [];
  return Object.freeze([
    instanceOperation(member.sourceName, member.write ? "value" : "", member.targetName, valueTypes, float64Carrier, true, member.write ? "mut" : "imm"),
    instanceOperation(member.sourceName, member.write ? "value,offset" : "offset", member.targetName, [...valueTypes, float64Carrier], float64Carrier, true, member.write ? "mut" : "imm"),
  ]);
}

export function bufferOperations(): readonly MojoProviderOperationDefinition[] {
  const sliceOperations = ["slice", "subarray"].flatMap((member) => [
    instanceOperation(member, "", member, [], bufferCarrier),
    instanceOperation(member, "start", member, [float64Carrier], bufferCarrier),
    instanceOperation(member, "start,end", member, [float64Carrier, float64Carrier], bufferCarrier),
  ]);
  return Object.freeze([
    staticOperation("from", "string", "buffer_from_string", [nativeString], bufferCarrier, true),
    staticOperation("from", "string,encoding", "buffer_from_string_encoded", [nativeString, nativeString], bufferCarrier, true),
    staticOperation("from", "numberArray", "buffer_from_numbers", [numberListCarrier], bufferCarrier, true),
    staticOperation("from", "buffer", "buffer_from_buffer", [bufferCarrier], bufferCarrier, true),
    ...extraBufferOperations(),
    staticOperation("byteLength", "string", "buffer_byte_length", [nativeString], float64Carrier, true),
    staticOperation("byteLength", "value,encoding", "buffer_byte_length", [nativeString, nativeString], float64Carrier, true),
    staticOperation("byteLength", "buffer", "buffer_byte_length_buffer", [bufferCarrier], float64Carrier),
    staticOperation("concat", "list", "buffer_concat", [bufferListCarrier], bufferCarrier, true),
    staticOperation("concat", "list,totalLength", "buffer_concat", [bufferListCarrier, float64Carrier], bufferCarrier, true),
    instanceOperation("toString", "", "to_string", [], nativeString, true),
    instanceOperation("toString", "encoding", "to_string", [nativeString], nativeString, true),
    instanceOperation("toString", "encoding,start", "to_string", [nativeString, float64Carrier], nativeString, true),
    instanceOperation("toString", "encoding,start,end", "to_string", [nativeString, float64Carrier, float64Carrier], nativeString, true),
    instanceOperation("copy", "target", "copy", [bufferCarrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart", "copy", [bufferCarrier, float64Carrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart,sourceStart", "copy", [bufferCarrier, float64Carrier, float64Carrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart,sourceStart,sourceEnd", "copy", [bufferCarrier, float64Carrier, float64Carrier, float64Carrier], float64Carrier, true),
    ...sliceOperations,
    ...["swap16", "swap32", "swap64"].map((member) => instanceOperation(member, "", member, [], bufferCarrier, true, "mut")),
    ...numericMembers.flatMap(numericOperations),
    instanceOperation("equals", "other", "equals", [bufferCarrier], boolCarrier),
    instanceOperation("compare", "other", "compare", [bufferCarrier], float64Carrier),
    propertyRead(bufferId, `${bufferId}.length`, "js_length", bufferCarrier, float64Carrier, "method"),
    staticPropertyRead(bufferId, `${bufferId}.poolSize`, "buffer", "buffer_pool_size", float64Carrier),
    staticPropertyWrite(bufferId, `${bufferId}.poolSize`, "buffer", "set_buffer_pool_size", float64Carrier),
    ...bufferPredicateOperations(),
    functionCall(`${moduleSpecifier}::isEncoding`, `${moduleSpecifier}::isEncoding(encoding)`, "buffer", "buffer_is_encoding", [nativeString], boolCarrier),
    functionCall(`${moduleSpecifier}::isAscii`, `${moduleSpecifier}::isAscii(value)`, "buffer", "buffer_is_ascii", [bufferCarrier], boolCarrier),
    functionCall(`${moduleSpecifier}::isUtf8`, `${moduleSpecifier}::isUtf8(value)`, "buffer", "buffer_is_utf8", [bufferCarrier], boolCarrier),
    functionCall(`${moduleSpecifier}::transcode`, `${moduleSpecifier}::transcode(value,fromEncoding,toEncoding)`, "buffer", "buffer_transcode", [bufferCarrier, nativeString, nativeString], bufferCarrier, true),
    functionCall(`${moduleSpecifier}::btoa`, `${moduleSpecifier}::btoa(value)`, "buffer", "buffer_btoa", [nativeString], nativeString, true),
    functionCall(`${moduleSpecifier}::atob`, `${moduleSpecifier}::atob(value)`, "buffer", "buffer_atob", [nativeString], nativeString, true),
  ]);
}
