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
  nativeIntCarrier,
  nativeString,
  numberArrayType,
  numberListCarrier,
  numberType,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  providerRef,
  staticCall,
  stringType,
} from "../model.js";

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
          overloadedMethodMember(bufferId, "from", [
            { parameters: [{ name: "value", type: stringType }], returnType: bufferType, signatureSuffix: "string" },
            {
              parameters: [{ name: "value", type: stringType }, { name: "encoding", type: stringType }],
              returnType: bufferType,
              signatureSuffix: "string,encoding",
            },
            { parameters: [{ name: "value", type: numberArrayType }], returnType: bufferType, signatureSuffix: "numberArray" },
          ], { static: true }),
          methodMember(bufferId, "alloc", [{ name: "size", type: numberType }], bufferType, { static: true }),
          overloadedMethodMember(bufferId, "byteLength", [
            { parameters: [{ name: "value", type: stringType }], returnType: numberType },
            { parameters: [{ name: "value", type: stringType }, { name: "encoding", type: stringType }], returnType: numberType },
          ], { static: true }),
          methodMember(bufferId, "concat", [{ name: "list", type: { kind: "array", elementType: bufferType } }], bufferType, { static: true }),
          overloadedMethodMember(bufferId, "toString", [
            { parameters: [], returnType: stringType },
            { parameters: [{ name: "encoding", type: stringType }], returnType: stringType },
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
        ]),
      }),
      fnExport(moduleSpecifier, "isBuffer", [{ name: "value", type: bufferType }], booleanType),
      fnExport(moduleSpecifier, "isEncoding", [{ name: "encoding", type: stringType }], booleanType),
      fnExport(moduleSpecifier, "btoa", [{ name: "value", type: stringType }], stringType),
      fnExport(moduleSpecifier, "atob", [{ name: "value", type: stringType }], stringType),
    ]),
  });
}

export function bufferTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([Object.freeze({
    exportId: bufferId,
    sourceGenericParameters: Object.freeze([]),
    targetType: bufferCarrier,
  })]);
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
    instanceOperation(member.sourceName, member.write ? "value,offset" : "offset", member.targetName, [...valueTypes, nativeIntCarrier], float64Carrier, true, member.write ? "mut" : "imm"),
  ]);
}

export function bufferOperations(): readonly MojoProviderOperationDefinition[] {
  const sliceOperations = ["slice", "subarray"].flatMap((member) => [
    instanceOperation(member, "", member, [], bufferCarrier),
    instanceOperation(member, "start", member, [nativeIntCarrier], bufferCarrier),
    instanceOperation(member, "start,end", member, [nativeIntCarrier, nativeIntCarrier], bufferCarrier),
  ]);
  return Object.freeze([
    staticOperation("from", "string", "buffer_from_string", [nativeString], bufferCarrier),
    staticOperation("from", "string,encoding", "buffer_from_string_encoded", [nativeString, nativeString], bufferCarrier, true),
    staticOperation("from", "numberArray", "buffer_from_numbers", [numberListCarrier], bufferCarrier),
    staticOperation("alloc", "size", "buffer_alloc", [nativeIntCarrier], bufferCarrier, true),
    staticOperation("byteLength", "value", "buffer_byte_length", [nativeString], float64Carrier, true),
    staticOperation("byteLength", "value,encoding", "buffer_byte_length", [nativeString, nativeString], float64Carrier, true),
    staticOperation("concat", "list", "buffer_concat", [bufferListCarrier], bufferCarrier),
    instanceOperation("toString", "", "to_string", [], nativeString, true),
    instanceOperation("toString", "encoding", "to_string", [nativeString], nativeString, true),
    instanceOperation("copy", "target", "copy", [bufferCarrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart", "copy", [bufferCarrier, nativeIntCarrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart,sourceStart", "copy", [bufferCarrier, nativeIntCarrier, nativeIntCarrier], float64Carrier, true),
    instanceOperation("copy", "target,targetStart,sourceStart,sourceEnd", "copy", [bufferCarrier, nativeIntCarrier, nativeIntCarrier, nativeIntCarrier], float64Carrier, true),
    ...sliceOperations,
    ...["swap16", "swap32", "swap64"].map((member) => instanceOperation(member, "", member, [], bufferCarrier, true, "mut")),
    ...numericMembers.flatMap(numericOperations),
    instanceOperation("equals", "other", "equals", [bufferCarrier], boolCarrier),
    instanceOperation("compare", "other", "compare", [bufferCarrier], float64Carrier),
    propertyRead(bufferId, `${bufferId}.length`, "js_length", bufferCarrier, float64Carrier, "method"),
    functionCall(`${moduleSpecifier}::isBuffer`, `${moduleSpecifier}::isBuffer(value)`, "buffer", "buffer_is_buffer", [bufferCarrier], boolCarrier),
    functionCall(`${moduleSpecifier}::isEncoding`, `${moduleSpecifier}::isEncoding(encoding)`, "buffer", "buffer_is_encoding", [nativeString], boolCarrier),
    functionCall(`${moduleSpecifier}::btoa`, `${moduleSpecifier}::btoa(value)`, "buffer", "buffer_btoa", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::atob`, `${moduleSpecifier}::atob(value)`, "buffer", "buffer_atob", [nativeString], nativeString, true),
  ]);
}
