import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
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
} from "../../model.js";
import { filesystemCallExports, filesystemCallOperations } from "./call-records.js";
import { filesystemContentsExports, filesystemContentsOperations } from "./contents.js";

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
      ...filesystemCallExports(true),
      ...filesystemContentsExports(true),
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
      fnExport(moduleSpecifier, "realpath", [{ name: "path", type: stringType }], sourcePromise(stringType)),
      fnExport(moduleSpecifier, "mkdtemp", [{ name: "prefix", type: stringType }], sourcePromise(stringType)),
      fnExport(moduleSpecifier, "symlink", [{ name: "target", type: stringType }, { name: "path", type: stringType }], sourcePromise(voidType)),
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
    ["filesystem", "promises"],
    targetName,
    parameters,
    result,
    true,
  );
  return Object.freeze([
    ...filesystemCallOperations(true),
    ...filesystemContentsOperations(true),
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
    operation("realpath", "path", "real_path", [nativeString], nativeStringFutureCarrier),
    operation("mkdtemp", "prefix", "make_temp_directory", [nativeString], nativeStringFutureCarrier),
    operation("symlink", "target,path", "symbolic_link", [nativeString, nativeString], unitFutureCarrier),
    operation("copyFile", "source,destination", "copy_file", [nativeString, nativeString], unitFutureCarrier),
    operation("rename", "oldPath,newPath", "rename_path", [nativeString, nativeString], unitFutureCarrier),
  ]);
}
