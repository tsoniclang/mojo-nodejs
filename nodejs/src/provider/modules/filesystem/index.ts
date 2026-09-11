import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoProviderSurfaceMembers,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoNamedTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  direntCarrier,
  direntListCarrier,
  float64Carrier,
  fnExport,
  functionCall,
  instanceCall,
  mkdirOptionsCarrier,
  nativeIntCarrier,
  nativeString,
  nodeProviderType,
  numberType,
  optionalBoolCarrier,
  optionalFloat64Carrier,
  overloadedFunctionExport,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerRef,
  readdirOptionsCarrier,
  rmOptionsCarrier,
  statsCarrier,
  stringArrayType,
  stringListCarrier,
  stringType,
  unitCarrier,
  voidType,
} from "../../model.js";

import { filesystemWatchExports, filesystemWatchOperations, filesystemWatchTypes } from "./watch.js";
import { filesystemStreamExports, filesystemStreamOperations, filesystemStreamTypes } from "./streams.js";
import { filesystemCallExports, filesystemCallOperations } from "./call-records.js";
import { filesystemContentsExports, filesystemContentsOperations } from "./contents.js";
import { filesystemCopyExports, filesystemCopyOperations, filesystemCopyTypes } from "./copy.js";

const moduleSpecifier = "node:fs";
const statsId = `${moduleSpecifier}::Stats`;
const direntId = `${moduleSpecifier}::Dirent`;
const mkdirOptionsId = `${moduleSpecifier}::MakeDirectoryOptions`;
const rmOptionsId = `${moduleSpecifier}::RmOptions`;
const readdirOptionsId = `${moduleSpecifier}::ReaddirOptions`;

export function filesystemModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.filesystem",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    }), Object.freeze({ moduleSpecifier: "node:stream", namedImports: Object.freeze([{ exportedName: "Readable" }, { exportedName: "Writable" }]) }),
    Object.freeze({ moduleSpecifier: "node:http", namedImports: Object.freeze([{ exportedName: "ServerResponse" }]) })]),
    exports: Object.freeze([
      ...filesystemCallExports(),
      ...filesystemContentsExports(),
      ...filesystemCopyExports(),
      ...filesystemWatchExports(),
      ...filesystemStreamExports(),
      classExport(statsId, "Stats", [
        method(statsId, "isFile"),
        method(statsId, "isDirectory"),
        method(statsId, "isSymbolicLink"),
        propertyMember(statsId, "size", numberType),
        propertyMember(statsId, "mtimeMs", numberType),
        ...["atimeMs", "ctimeMs", "birthtimeMs"].map((name) => propertyMember(statsId, name, numberType)),
      ]),
      classExport(direntId, "Dirent", [
        propertyMember(direntId, "name", stringType),
        method(direntId, "isFile"),
        method(direntId, "isDirectory"),
        method(direntId, "isSymbolicLink"),
      ]),
      interfaceExport(mkdirOptionsId, "MakeDirectoryOptions", [
        propertyMember(mkdirOptionsId, "recursive", booleanType, { readonly: false, optional: true }),
        propertyMember(mkdirOptionsId, "mode", numberType, { readonly: false, optional: true }),
      ]),
      interfaceExport(rmOptionsId, "RmOptions", [
        propertyMember(rmOptionsId, "recursive", booleanType, { readonly: false, optional: true }),
        propertyMember(rmOptionsId, "force", booleanType, { readonly: false, optional: true }),
        propertyMember(rmOptionsId, "maxRetries", numberType, { readonly: false, optional: true }),
        propertyMember(rmOptionsId, "retryDelay", numberType, { readonly: false, optional: true }),
      ]),
      interfaceExport(readdirOptionsId, "ReaddirOptions", [
        propertyMember(
          readdirOptionsId,
          "withFileTypes",
          Object.freeze({ kind: "literal" as const, value: true }),
          { readonly: false },
        ),
      ]),
      fnExport(moduleSpecifier, "existsSync", [{ name: "path", type: stringType }], booleanType),
      fnExport(moduleSpecifier, "statSync", [{ name: "path", type: stringType }], providerRef(moduleSpecifier, "Stats")),
      fnExport(moduleSpecifier, "lstatSync", [{ name: "path", type: stringType }], providerRef(moduleSpecifier, "Stats")),
      overloadedFunctionExport(moduleSpecifier, "readdirSync", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: stringArrayType,
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "options", type: providerRef(moduleSpecifier, "ReaddirOptions") },
          ],
          returnType: Object.freeze({
            kind: "array" as const,
            elementType: providerRef(moduleSpecifier, "Dirent"),
          }),
          signatureSuffix: "path,options",
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "mkdirSync", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: voidType,
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "options", type: providerRef(moduleSpecifier, "MakeDirectoryOptions") },
          ],
          returnType: voidType,
          signatureSuffix: "path,options",
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "rmSync", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: voidType,
          signatureSuffix: "path",
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "options", type: providerRef(moduleSpecifier, "RmOptions") },
          ],
          returnType: voidType,
          signatureSuffix: "path,options",
        },
      ]),
      fnExport(moduleSpecifier, "mkdtempSync", [{ name: "prefix", type: stringType }], stringType),
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
  return Object.freeze([
    ...filesystemWatchTypes(),
    ...filesystemStreamTypes(),
    ...filesystemCopyTypes(),
    nodeProviderType(statsId, statsCarrier, "copyable"),
    nodeProviderType(direntId, direntCarrier, "copyable"),
    nodeProviderType(mkdirOptionsId, mkdirOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
    nodeProviderType(rmOptionsId, rmOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
    nodeProviderType(readdirOptionsId, readdirOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
  ]);
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
    ...filesystemCallOperations(),
    ...filesystemContentsOperations(),
    ...filesystemCopyOperations(),
    ...filesystemWatchOperations(),
    ...filesystemStreamOperations(),
    operation("existsSync", "path", "exists", [nativeString], boolCarrier, false),
    operation("statSync", "path", "stat", [nativeString], statsCarrier),
    operation("lstatSync", "path", "lstat", [nativeString], statsCarrier),
    operation("readdirSync", "path", "read_directory_names", [nativeString], stringListCarrier),
    operation("readdirSync", "path,options", "read_directory", [nativeString, readdirOptionsCarrier], direntListCarrier),
    operation("mkdirSync", "path", "make_directory_default", [nativeString], unitCarrier),
    operation("mkdirSync", "path,options", "make_directory", [nativeString, mkdirOptionsCarrier], unitCarrier),
    operation("rmSync", "path", "remove_path_default", [nativeString], unitCarrier),
    operation("rmSync", "path,options", "remove_path", [nativeString, rmOptionsCarrier], unitCarrier),
    operation("mkdtempSync", "prefix", "make_temp_directory", [nativeString], nativeString),
    operation("copyFileSync", "source,destination", "copy_file", [nativeString, nativeString], unitCarrier),
    operation("renameSync", "oldPath,newPath", "rename_path", [nativeString, nativeString], unitCarrier),
    operation("symlinkSync", "target,path", "symbolic_link", [nativeString, nativeString], unitCarrier),
    operation("realpathSync", "path", "real_path", [nativeString], nativeString),
    operation("unlinkSync", "path", "unlink", [nativeString], unitCarrier),
    ...methodOperations(statsId, statsCarrier),
    ...methodOperations(direntId, direntCarrier),
    propertyRead(statsId, `${statsId}.size`, "size", statsCarrier, nativeIntCarrier),
    propertyRead(statsId, `${statsId}.mtimeMs`, "mtime_ms", statsCarrier, float64Carrier),
    ...([["atimeMs", "atime_ms"], ["ctimeMs", "ctime_ms"], ["birthtimeMs", "birthtime_ms"]] as const).map(([source, target]) => propertyRead(statsId, `${statsId}.${source}`, target, statsCarrier, float64Carrier)),
    propertyRead(direntId, `${direntId}.name`, "name", direntCarrier, nativeString),
    ...optionFieldOperations(mkdirOptionsId, mkdirOptionsCarrier, [
      ["recursive", "recursive", optionalBoolCarrier],
      ["mode", "mode", optionalFloat64Carrier],
    ]),
    ...optionFieldOperations(rmOptionsId, rmOptionsCarrier, [
      ["recursive", "recursive", optionalBoolCarrier],
      ["force", "force", optionalBoolCarrier],
      ["maxRetries", "max_retries", optionalFloat64Carrier],
      ["retryDelay", "retry_delay", optionalFloat64Carrier],
    ]),
    ...optionFieldOperations(readdirOptionsId, readdirOptionsCarrier, [
      ["withFileTypes", "with_file_types", boolCarrier],
    ]),
  ]);
}

function classExport(
  id: string,
  name: string,
  members: NonNullable<MojoProviderModuleDefinition["exports"][number]["members"]>,
): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({ id, name, kind: "class", members: Object.freeze(members) });
}

function interfaceExport(
  id: string,
  name: string,
  members: NonNullable<MojoProviderModuleDefinition["exports"][number]["members"]>,
): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({ id, name, kind: "interface", members: Object.freeze(members) });
}

function method(
  ownerId: string,
  name: string,
): NonNullable<MojoProviderModuleDefinition["exports"][number]["members"]>[number] {
  return Object.freeze({
    id: `${ownerId}.${name}`,
    name,
    kind: "method",
    signatures: Object.freeze([Object.freeze({
      id: `${ownerId}.${name}()`,
      name,
      parameters: Object.freeze([]),
      returnType: booleanType,
    })]),
  });
}

function methodOperations(
  exportId: string,
  receiverType: MojoTargetTypeRef,
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    instanceCall(exportId, `${exportId}.isFile`, `${exportId}.isFile()`, "is_file", receiverType, [], boolCarrier),
    instanceCall(exportId, `${exportId}.isDirectory`, `${exportId}.isDirectory()`, "is_directory", receiverType, [], boolCarrier),
    instanceCall(exportId, `${exportId}.isSymbolicLink`, `${exportId}.isSymbolicLink()`, "is_symbolic_link", receiverType, [], boolCarrier),
  ]);
}

function optionFieldOperations(
  exportId: string,
  receiverType: MojoTargetTypeRef,
  fields: readonly (readonly [sourceName: string, targetName: string, storageType: MojoTargetTypeRef])[],
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(fields.flatMap(([sourceName, targetName, storageType]) => [
    propertyRead(exportId, `${exportId}.${sourceName}`, targetName, receiverType, storageType),
    propertyWrite(exportId, `${exportId}.${sourceName}`, targetName, receiverType, storageType),
  ]));
}

export function filesystemSurfaceMembers(): MojoProviderSurfaceMembers {
  const names = ["atime", "mtime", "ctime", "birthtime"];
  return Object.freeze({
    id: "filesystem-js-date-members",
    requiredSurfaces: Object.freeze(["js"]),
    declarations: Object.freeze([Object.freeze({
      exportId: statsId,
      members: Object.freeze(names.map((name) => propertyMember(statsId, name, Object.freeze({ kind: "source-global", name: "Date" })))),
    })]),
    operations: Object.freeze(names.map((name) => propertyRead(statsId, `${statsId}.${name}`, name, statsCarrier, mojoNamedTargetType("tsonic.mojo.js.JsDate", ["tsonic_js"], "JsDate"), "method"))),
  });
}
