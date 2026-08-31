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
  fnExport,
  functionCall,
  instanceCall,
  methodMember,
  nativeString,
  overloadedFunctionExport,
  providerRef,
  statsCarrier,
  stringType,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:fs";
const statsId = `${moduleSpecifier}::Stats`;

export function filesystemModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.filesystem",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: statsId,
        name: "Stats",
        kind: "class",
        members: Object.freeze([
          methodMember(statsId, "isFile", [], booleanType),
          methodMember(statsId, "isDirectory", [], booleanType),
          methodMember(statsId, "isSymbolicLink", [], booleanType),
        ]),
      }),
      fnExport(moduleSpecifier, "existsSync", [{ name: "path", type: stringType }], booleanType),
      fnExport(moduleSpecifier, "statSync", [{ name: "path", type: stringType }], providerRef(moduleSpecifier, "Stats")),
      fnExport(moduleSpecifier, "lstatSync", [{ name: "path", type: stringType }], providerRef(moduleSpecifier, "Stats")),
      overloadedFunctionExport(moduleSpecifier, "readFileSync", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: providerRef("node:buffer", "Buffer"),
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "encoding", type: { kind: "literal", value: "utf8" } },
          ],
          returnType: stringType,
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "writeFileSync", [
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "data", type: providerRef("node:buffer", "Buffer") },
          ],
          returnType: voidType,
          signatureSuffix: "path,buffer",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "data", type: stringType },
          ],
          returnType: voidType,
          signatureSuffix: "path,string",
        },
      ]),
      fnExport(moduleSpecifier, "copyFileSync", [
        { name: "source", type: stringType },
        { name: "destination", type: stringType },
      ], voidType),
      fnExport(moduleSpecifier, "renameSync", [
        { name: "oldPath", type: stringType },
        { name: "newPath", type: stringType },
      ], voidType),
      fnExport(moduleSpecifier, "symlinkSync", [
        { name: "target", type: stringType },
        { name: "path", type: stringType },
      ], voidType),
      fnExport(moduleSpecifier, "realpathSync", [{ name: "path", type: stringType }], stringType),
      fnExport(moduleSpecifier, "unlinkSync", [{ name: "path", type: stringType }], voidType),
    ]),
  });
}

export function filesystemTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([Object.freeze({ exportId: statsId, targetType: statsCarrier })]);
}

export function filesystemOperations(): readonly MojoProviderOperationDefinition[] {
  const operation = (
    sourceName: string,
    signature: string,
    targetName: string,
    parameters: readonly MojoTargetTypeRef[],
    result: MojoTargetTypeRef,
    raises = true,
  ): MojoProviderOperationDefinition => functionCall(
    `${moduleSpecifier}::${sourceName}`,
    `${moduleSpecifier}::${sourceName}(${signature})`,
    "filesystem",
    targetName,
    parameters,
    result,
    raises,
  );
  return Object.freeze([
    operation("existsSync", "path", "exists", [nativeString], boolCarrier, false),
    operation("statSync", "path", "stat", [nativeString], statsCarrier),
    operation("lstatSync", "path", "lstat", [nativeString], statsCarrier),
    operation("readFileSync", "path", "read_file", [nativeString], bufferCarrier),
    operation("readFileSync", "path,encoding", "read_text_file_encoded", [nativeString, nativeString], nativeString),
    operation("writeFileSync", "path,buffer", "write_file", [nativeString, bufferCarrier], unitCarrier),
    operation("writeFileSync", "path,string", "write_text_file", [nativeString, nativeString], unitCarrier),
    operation("copyFileSync", "source,destination", "copy_file", [nativeString, nativeString], unitCarrier),
    operation("renameSync", "oldPath,newPath", "rename_path", [nativeString, nativeString], unitCarrier),
    operation("symlinkSync", "target,path", "symbolic_link", [nativeString, nativeString], unitCarrier),
    operation("realpathSync", "path", "real_path", [nativeString], nativeString),
    operation("unlinkSync", "path", "unlink", [nativeString], unitCarrier),
    instanceCall(statsId, `${statsId}.isFile`, `${statsId}.isFile()`, "is_file", statsCarrier, [], boolCarrier),
    instanceCall(statsId, `${statsId}.isDirectory`, `${statsId}.isDirectory()`, "is_directory", statsCarrier, [], boolCarrier),
    instanceCall(statsId, `${statsId}.isSymbolicLink`, `${statsId}.isSymbolicLink()`, "is_symbolic_link", statsCarrier, [], boolCarrier),
  ]);
}
