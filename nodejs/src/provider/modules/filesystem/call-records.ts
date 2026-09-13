import { mojoFutureTargetType } from "@tsonic/target-mojo/provider";
import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  bufferCarrier, float64Carrier, fnExport, functionCall, nativeString, numberType,
  optionalFloat64Carrier, overloadedFunctionExport, providerRef, sourcePromise,
  statsCarrier, stringType, unitCarrier, voidType,
} from "../../model.js";

type SourceType = Parameters<typeof fnExport>[3];
type Parameter = readonly [name: string, source: SourceType, target: MojoTargetTypeRef];
interface CallRecord {
  readonly name: string;
  readonly native: string;
  readonly minimum: number;
  readonly parameters: readonly Parameter[];
  readonly result: readonly [SourceType, MojoTargetTypeRef];
  readonly promise?: string;
}

const path: Parameter = ["path", stringType, nativeString];
const mode: Parameter = ["mode", numberType, float64Carrier];
const descriptor: Parameter = ["fd", numberType, float64Carrier];
const buffer: Parameter = ["buffer", providerRef("node:buffer", "Buffer"), bufferCarrier];
const offset: Parameter = ["offset", numberType, float64Carrier];
const length: Parameter = ["length", numberType, float64Carrier];
const position: Parameter = ["position", Object.freeze({ kind: "union", types: Object.freeze([
  numberType, Object.freeze({ kind: "literal", value: null }),
]) }), optionalFloat64Carrier];
const emptyResult = [voidType, unitCarrier] as const;
const numberResult = [numberType, float64Carrier] as const;
const stringResult = [stringType, nativeString] as const;

const records: readonly CallRecord[] = Object.freeze([
  { name: "accessSync", native: "access", minimum: 1, parameters: [path, mode], result: emptyResult, promise: "access" },
  { name: "chmodSync", native: "chmod", minimum: 2, parameters: [path, mode], result: emptyResult, promise: "chmod" },
  { name: "openSync", native: "open_file", minimum: 2, parameters: [path, ["flags", stringType, nativeString], mode], result: numberResult },
  { name: "closeSync", native: "close_file", minimum: 1, parameters: [descriptor], result: emptyResult },
  { name: "fstatSync", native: "fstat", minimum: 1, parameters: [descriptor], result: [providerRef("node:fs", "Stats"), statsCarrier] },
  { name: "readSync", native: "read_into", minimum: 4, parameters: [descriptor, buffer, offset, length, position], result: numberResult },
  { name: "writeSync", native: "write_from", minimum: 2, parameters: [descriptor, buffer, offset, ["length", numberType, optionalFloat64Carrier], position], result: numberResult },
  { name: "writeSync", native: "write_string", minimum: 2, parameters: [descriptor, ["value", stringType, nativeString], position, ["encoding", stringType, nativeString]], result: numberResult },
  { name: "readlinkSync", native: "read_link", minimum: 1, parameters: [path], result: stringResult, promise: "readlink" },
  { name: "rmdirSync", native: "remove_directory", minimum: 1, parameters: [path], result: emptyResult, promise: "rmdir" },
  { name: "truncateSync", native: "truncate_file", minimum: 1, parameters: [path, length], result: emptyResult, promise: "truncate" },
]);

function selectedRecords(asynchronous: boolean): readonly CallRecord[] {
  return asynchronous ? records.filter((record) => record.promise !== undefined) : records;
}

export function filesystemCallExports(asynchronous = false): MojoProviderModuleDefinition["exports"] {
  const moduleSpecifier = asynchronous ? "node:fs/promises" : "node:fs";
  const groups = new Map<string, Parameters<typeof overloadedFunctionExport>[2][number][]>();
  for (const record of selectedRecords(asynchronous)) {
    const name = asynchronous ? record.promise! : record.name;
    const overloads = groups.get(name) ?? [];
    for (let count = record.minimum; count <= record.parameters.length; count += 1) {
      overloads.push(Object.freeze({
        parameters: Object.freeze(record.parameters.slice(0, count).map(([name, type]) => Object.freeze({ name, type }))),
        returnType: asynchronous ? sourcePromise(record.result[0]) : record.result[0],
      }));
    }
    groups.set(name, overloads);
  }
  return Object.freeze([...groups].map(([name, overloads]) => overloadedFunctionExport(moduleSpecifier, name, overloads)));
}

export function filesystemCallOperations(asynchronous = false): readonly MojoProviderOperationDefinition[] {
  const moduleSpecifier = asynchronous ? "node:fs/promises" : "node:fs";
  return Object.freeze(selectedRecords(asynchronous).flatMap((record) => {
    const name = asynchronous ? record.promise! : record.name;
    return Array.from({ length: record.parameters.length - record.minimum + 1 }, (_, index) => {
      const parameters = record.parameters.slice(0, record.minimum + index);
      return functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(${parameters.map(([name]) => name).join(",")})`,
        asynchronous ? ["filesystem", "promises"] : "filesystem", record.native,
        parameters.map(([, , target]) => target),
        asynchronous ? mojoFutureTargetType(record.result[1], "native", true) : record.result[1], true);
    });
  }));
}
