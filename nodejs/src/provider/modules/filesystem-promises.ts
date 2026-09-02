import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  fnExport,
  functionCall,
  mkdirOptionsCarrier,
  nativeString,
  nativeStringFutureCarrier,
  overloadedFunctionExport,
  providerRef,
  rmOptionsCarrier,
  sourcePromise,
  statsCarrier,
  stringArrayType,
  stringListFutureCarrier,
  stringType,
  unitFutureCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:fs/promises";

export function filesystemPromisesModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.filesystem-promises",
    imports: Object.freeze([
      Object.freeze({
        moduleSpecifier: "node:buffer",
        namedImports: Object.freeze([{ exportedName: "Buffer" }]),
      }),
      Object.freeze({
        moduleSpecifier: "node:fs",
        namedImports: Object.freeze([
          { exportedName: "MakeDirectoryOptions" },
          { exportedName: "RmOptions" },
          { exportedName: "Stats" },
        ]),
      }),
    ]),
    exports: Object.freeze([
      overloadedFunctionExport(moduleSpecifier, "readFile", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: sourcePromise(providerRef("node:buffer", "Buffer")),
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "encoding", type: Object.freeze({ kind: "literal" as const, value: "utf8" }) },
          ],
          returnType: sourcePromise(stringType),
          signatureSuffix: "path,encoding",
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "writeFile", [
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "data", type: providerRef("node:buffer", "Buffer") },
          ],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path,buffer",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "data", type: stringType },
          ],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path,string",
        },
      ]),
      fnExport(moduleSpecifier, "readdir", [{ name: "path", type: stringType }], sourcePromise(stringArrayType)),
      fnExport(moduleSpecifier, "stat", [{ name: "path", type: stringType }], sourcePromise(providerRef("node:fs", "Stats"))),
      overloadedFunctionExport(moduleSpecifier, "mkdir", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "options", type: providerRef("node:fs", "MakeDirectoryOptions") },
          ],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path,options",
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "rm", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "options", type: providerRef("node:fs", "RmOptions") },
          ],
          returnType: sourcePromise(voidType),
          signatureSuffix: "path,options",
        },
      ]),
      fnExport(moduleSpecifier, "unlink", [{ name: "path", type: stringType }], sourcePromise(voidType)),
      fnExport(moduleSpecifier, "copyFile", [
        { name: "source", type: stringType },
        { name: "destination", type: stringType },
      ], sourcePromise(voidType)),
      fnExport(moduleSpecifier, "rename", [
        { name: "oldPath", type: stringType },
        { name: "newPath", type: stringType },
      ], sourcePromise(voidType)),
    ]),
  });
}

export function filesystemPromisesOperations(): readonly MojoProviderOperationDefinition[] {
  const operation = (
    sourceName: string,
    signature: string,
    targetName: string,
    parameters: readonly MojoTargetTypeRef[],
    result: MojoTargetTypeRef,
  ): MojoProviderOperationDefinition => functionCall(
    `${moduleSpecifier}::${sourceName}`,
    `${moduleSpecifier}::${sourceName}(${signature})`,
    "filesystem_promises",
    targetName,
    parameters,
    result,
    true,
  );
  return Object.freeze([
    operation("readFile", "path", "read_file", [nativeString], Object.freeze({
      kind: "future",
      domain: "native",
      output: bufferCarrier,
      raises: true,
    })),
    operation("readFile", "path,encoding", "read_text_file", [nativeString, nativeString], nativeStringFutureCarrier),
    operation("writeFile", "path,buffer", "write_file", [nativeString, bufferCarrier], unitFutureCarrier),
    operation("writeFile", "path,string", "write_text_file", [nativeString, nativeString], unitFutureCarrier),
    operation("readdir", "path", "read_directory", [nativeString], stringListFutureCarrier),
    operation("stat", "path", "stat", [nativeString], Object.freeze({
      kind: "future",
      domain: "native",
      output: statsCarrier,
      raises: true,
    })),
    operation("mkdir", "path", "make_directory_default", [nativeString], unitFutureCarrier),
    operation("mkdir", "path,options", "make_directory", [nativeString, mkdirOptionsCarrier], unitFutureCarrier),
    operation("rm", "path", "remove_path_default", [nativeString], unitFutureCarrier),
    operation("rm", "path,options", "remove_path", [nativeString, rmOptionsCarrier], unitFutureCarrier),
    operation("unlink", "path", "unlink", [nativeString], unitFutureCarrier),
    operation("copyFile", "source,destination", "copy_file", [nativeString, nativeString], unitFutureCarrier),
    operation("rename", "oldPath,newPath", "rename_path", [nativeString, nativeString], unitFutureCarrier),
  ]);
}
