import { mojoFutureTargetType } from "@tsonic/target-mojo/provider";
import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  fnExport,
  functionCall,
  nativeString,
  overloadedFunctionExport,
  providerRef,
  sourcePromise,
  stringType,
  unitCarrier,
  voidType,
} from "../../model.js";

type SourceType = Parameters<typeof fnExport>[3];
type Parameter = readonly [name: string, source: SourceType, target: MojoTargetTypeRef];
interface ContentsCall {
  readonly name: string;
  readonly signature: string;
  readonly native: string;
  readonly asynchronousNative?: string;
  readonly parameters: readonly Parameter[];
  readonly result: readonly [source: SourceType, target: MojoTargetTypeRef];
}

const path: Parameter = ["path", stringType, nativeString];
const encoding: Parameter = ["encoding", stringType, nativeString];
const text: Parameter = ["data", stringType, nativeString];
const bytes: Parameter = ["data", providerRef("node:buffer", "Buffer"), bufferCarrier];

const calls: readonly ContentsCall[] = Object.freeze([
  {
    name: "readFile", signature: "path", native: "read_file",
    parameters: [path], result: [bytes[1], bufferCarrier],
  },
  {
    name: "readFile", signature: "path,encoding", native: "read_text_file_encoded",
    asynchronousNative: "read_text_file",
    parameters: [path, encoding], result: [stringType, nativeString],
  },
  ...(["write", "append"] as const).flatMap((action): ContentsCall[] => [
    {
      name: `${action}File`, signature: "path,buffer", native: `${action}_file`,
      parameters: [path, bytes], result: [voidType, unitCarrier],
    },
    {
      name: `${action}File`, signature: "path,string", native: `${action}_text_file`,
      parameters: [path, text], result: [voidType, unitCarrier],
    },
    {
      name: `${action}File`, signature: "path,string,encoding", native: `${action}_text_file`,
      parameters: [path, text, encoding], result: [voidType, unitCarrier],
    },
  ]),
]);

export function filesystemContentsExports(asynchronous = false): MojoProviderModuleDefinition["exports"] {
  const specifier = asynchronous ? "node:fs/promises" : "node:fs";
  const groups = new Map<string, Parameters<typeof overloadedFunctionExport>[2][number][]>();
  for (const call of calls) {
    const name = asynchronous ? call.name : `${call.name}Sync`;
    const overloads = groups.get(name) ?? [];
    overloads.push(Object.freeze({
      signatureSuffix: call.signature,
      parameters: Object.freeze(call.parameters.map(([name, type]) => Object.freeze({ name, type }))),
      returnType: asynchronous ? sourcePromise(call.result[0]) : call.result[0],
    }));
    groups.set(name, overloads);
  }
  return Object.freeze([...groups].map(([name, overloads]) =>
    overloadedFunctionExport(specifier, name, overloads)));
}

export function filesystemContentsOperations(asynchronous = false): readonly MojoProviderOperationDefinition[] {
  const specifier = asynchronous ? "node:fs/promises" : "node:fs";
  return Object.freeze(calls.map((call) => {
    const name = asynchronous ? call.name : `${call.name}Sync`;
    return functionCall(
      `${specifier}::${name}`,
      `${specifier}::${name}(${call.signature})`,
      asynchronous ? ["filesystem", "promises"] : "filesystem",
      asynchronous ? call.asynchronousNative ?? call.native : call.native,
      call.parameters.map(([, , target]) => target),
      asynchronous ? mojoFutureTargetType(call.result[1], "native", true) : call.result[1],
      true,
    );
  }));
}
