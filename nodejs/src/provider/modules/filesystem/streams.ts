import type {
  MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import { mojoNamedTargetType } from "@tsonic/target-mojo/provider";
import { writableCallMembers, writableCallOperations } from "../stream/writable-calls.js";
import { writableEventMembers, writableEventOperations } from "../stream/writable-events.js";
import { readableReadMember, readableReadOperations } from "../stream/readable-calls.js";
import { readableEventMembers, readableEventOperations } from "../stream/readable-events.js";
import {
  booleanType, boolCarrier, float64Carrier, functionCall,
  httpServerResponseCarrier, instanceCall, methodMember, nativeString,
  nodeProviderType, numberType, optionalBoolCarrier, optionalFloat64Carrier,
  optionalStringCarrier, overloadedFunctionExport, overloadedMethodMember,
  propertyMember, propertyRead, propertyWrite, providerRef, readableCarrier,
  stringType, unitCarrier, voidType, writableCarrier,
} from "../../model.js";

const moduleSpecifier = "node:fs";
const readId = `${moduleSpecifier}::ReadStream`;
const writeId = `${moduleSpecifier}::WriteStream`;
const readOptionsId = `${moduleSpecifier}::ReadStreamOptions`;
const writeOptionsId = `${moduleSpecifier}::WriteStreamOptions`;
const readType = providerRef(moduleSpecifier, "ReadStream");
const writeType = providerRef(moduleSpecifier, "WriteStream");
const responseType = providerRef("node:http", "ServerResponse");
const readOptions = mojoNamedTargetType("tsonic.mojo.node.ReadStreamOptions", ["tsonic_node", "filesystem"], "ReadStreamOptions");
const writeOptions = mojoNamedTargetType("tsonic.mojo.node.WriteStreamOptions", ["tsonic_node", "filesystem"], "WriteStreamOptions");
const optionFields = Object.freeze([
  ["flags", "flags", stringType, optionalStringCarrier],
  ["mode", "mode", numberType, optionalFloat64Carrier],
  ["start", "start", numberType, optionalFloat64Carrier],
  ["highWaterMark", "high_water_mark", numberType, optionalFloat64Carrier],
] as const);

export function filesystemStreamExports(): MojoProviderModuleDefinition["exports"] {
  return Object.freeze([
    ...([[readOptionsId, "ReadStreamOptions"], [writeOptionsId, "WriteStreamOptions"]] as const).map(([id, name]) => Object.freeze({
      id, name, kind: "interface" as const,
      members: Object.freeze([
        ...optionFields.map(([field, , type]) => propertyMember(id, field, type, { readonly: false, optional: true })),
        propertyMember(id, "encoding", stringType, { readonly: false, optional: true }),
        propertyMember(id, id === readOptionsId ? "end" : "flush", id === readOptionsId ? numberType : booleanType, { readonly: false, optional: true }),
      ]),
    })),
    Object.freeze({ id: readId, name: "ReadStream", kind: "class" as const,
      heritage: Object.freeze([{ kind: "extends" as const, type: providerRef("node:stream", "Readable") }]), members: Object.freeze([
      readableReadMember(readId),
      ...readableEventMembers(moduleSpecifier, "ReadStream"),
      methodMember(readId, "setEncoding", [{ name: "encoding", type: stringType }], readType),
      overloadedMethodMember(readId, "pipe", [
        { signatureSuffix: "writeStream", parameters: [{ name: "destination", type: writeType }], returnType: writeType },
        { signatureSuffix: "writable", parameters: [{ name: "destination", type: providerRef("node:stream", "Writable") }], returnType: providerRef("node:stream", "Writable") },
        { signatureSuffix: "serverResponse", parameters: [{ name: "destination", type: responseType }], returnType: responseType },
      ]),
      methodMember(readId, "close", [], voidType),
      methodMember(readId, "pause", [], readType),
      methodMember(readId, "resume", [], readType),
      methodMember(readId, "isPaused", [], booleanType),
      propertyMember(readId, "path", stringType),
      propertyMember(readId, "bytesRead", numberType),
    ]) }),
    Object.freeze({ id: writeId, name: "WriteStream", kind: "class" as const,
      heritage: Object.freeze([{ kind: "extends" as const, type: providerRef("node:stream", "Writable") }]), members: Object.freeze([
      ...writableCallMembers(writeId, writeType),
      ...writableEventMembers(moduleSpecifier, "WriteStream"),
      methodMember(writeId, "close", [], voidType),
      methodMember(writeId, "cork", [], voidType),
      methodMember(writeId, "uncork", [], voidType),
      propertyMember(writeId, "path", stringType),
      propertyMember(writeId, "bytesWritten", numberType),
    ]) }),
    ...([
      ["createReadStream", "ReadStreamOptions", readType],
      ["createWriteStream", "WriteStreamOptions", writeType],
    ] as const).map(([name, options, result]) => overloadedFunctionExport(moduleSpecifier, name, [
      { parameters: [{ name: "path", type: stringType }], returnType: result },
      { parameters: [{ name: "path", type: stringType }, { name: "options", type: providerRef(moduleSpecifier, options) }], returnType: result },
    ])),
  ]);
}

export function filesystemStreamTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(readId, readableCarrier, "implicitly-copyable"),
    nodeProviderType(writeId, writableCarrier, "implicitly-copyable"),
    nodeProviderType(readOptionsId, readOptions, "copyable", { objectLiteralConstruction: true }),
    nodeProviderType(writeOptionsId, writeOptions, "copyable", { objectLiteralConstruction: true }),
  ]);
}

export function filesystemStreamOperations(): readonly MojoProviderOperationDefinition[] {
  const operations: MojoProviderOperationDefinition[] = [];
  for (const [name, target, result, options] of [
    ["createReadStream", "create_read_stream", readableCarrier, readOptions],
    ["createWriteStream", "create_write_stream", writableCarrier, writeOptions],
  ] as const) {
    operations.push(
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(path)`, "filesystem", target, [nativeString], result, true),
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(path,options)`, "filesystem", target, [nativeString, options], result, true),
    );
  }
  for (const [id, carrier] of [[readOptionsId, readOptions], [writeOptionsId, writeOptions]] as const) {
    const fields = [...optionFields,
      ["encoding", "encoding", stringType, optionalStringCarrier] as const, id === readOptionsId
      ? ["end", "end", numberType, optionalFloat64Carrier] as const
      : ["flush", "flush", booleanType, optionalBoolCarrier] as const];
    for (const [name, target, , fieldType] of fields) {
      operations.push(propertyRead(id, `${id}.${name}`, target, carrier, fieldType),
        propertyWrite(id, `${id}.${name}`, target, carrier, fieldType));
    }
  }
  for (const [id, carrier, counter, targetCounter, receiver] of [
    [readId, readableCarrier, "bytesRead", "bytes_read", "imm"],
    [writeId, writableCarrier, "bytesWritten", "bytes_written", "mut"],
  ] as const) {
    operations.push(instanceCall(id, `${id}.close`, `${id}.close()`, "close", carrier, [], unitCarrier, true, receiver),
      propertyRead(id, `${id}.path`, "path", carrier, nativeString, "method"),
      propertyRead(id, `${id}.${counter}`, targetCounter, carrier, float64Carrier, "method"));
  }
  operations.push(...readableReadOperations(readId, readableCarrier));
  operations.push(...readableEventOperations(moduleSpecifier, "ReadStream", readableCarrier));
  operations.push(instanceCall(readId, `${readId}.setEncoding`, `${readId}.setEncoding(encoding)`, "set_encoding", readableCarrier, [nativeString], readableCarrier, true, "mut"));
  for (const [suffix, destination, target] of [
    ["writeStream", writableCarrier, "pipe_to"], ["writable", writableCarrier, "pipe_to"],
    ["serverResponse", httpServerResponseCarrier, "pipe_to_response"],
  ] as const) operations.push(instanceCall(readId, `${readId}.pipe`, `${readId}.pipe(${suffix})`, target, readableCarrier, [destination], destination, true, "mut"));
  for (const name of ["pause", "resume"] as const) operations.push(instanceCall(readId, `${readId}.${name}`, `${readId}.${name}()`, name, readableCarrier, [], readableCarrier, true, "mut"));
  operations.push(instanceCall(readId, `${readId}.isPaused`, `${readId}.isPaused()`, "is_paused", readableCarrier, [], boolCarrier));
  operations.push(...writableCallOperations(writeId, writableCarrier));
  operations.push(...writableEventOperations(moduleSpecifier, "WriteStream", writableCarrier));
  for (const name of ["cork", "uncork"] as const) operations.push(instanceCall(writeId, `${writeId}.${name}`, `${writeId}.${name}()`, name, writableCarrier, [], unitCarrier, name === "uncork", "mut"));
  return Object.freeze(operations);
}
