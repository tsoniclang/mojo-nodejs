import type {
  MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import { mojoCallableTargetType, mojoNamedTargetType, mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, fnExport, functionCall, instanceCall, methodMember,
  nativeString, nodeProviderType, numberType, optionalBoolCarrier, optionalFloat64Carrier,
  optionalStringCarrier, overloadedFunctionExport, propertyMember, propertyRead,
  propertyWrite, providerCallbackType, providerRef, statsCarrier, stringType, unitCarrier, voidType,
} from "../../model.js";

const moduleSpecifier = "node:fs";
const watcherId = `${moduleSpecifier}::FSWatcher`;
const statWatcherId = `${moduleSpecifier}::StatWatcher`;
const optionsId = `${moduleSpecifier}::WatchOptions`;
const statOptionsId = `${moduleSpecifier}::WatchFileOptions`;
const watcherType = providerRef(moduleSpecifier, "FSWatcher");
const statWatcherType = providerRef(moduleSpecifier, "StatWatcher");
const watcherCarrier = mojoNamedTargetType("tsonic.mojo.node.FSWatcher", ["tsonic_node", "filesystem"], "FSWatcher");
const optionsCarrier = mojoNamedTargetType("tsonic.mojo.node.WatchOptions", ["tsonic_node", "filesystem"], "WatchOptions");
const filenameType = Object.freeze({ kind: "union" as const, types: Object.freeze([
  stringType, Object.freeze({ kind: "literal" as const, value: null }),
]) });
const changeType = providerCallbackType("node:fs::WatchListener", "listener", [
  { name: "eventType", type: stringType }, { name: "filename", type: filenameType },
]);
const statType = providerCallbackType("node:fs::StatWatcherListener", "listener", [
  { name: "current", type: providerRef(moduleSpecifier, "Stats") },
  { name: "previous", type: providerRef(moduleSpecifier, "Stats") },
]);
const callback = (types: readonly typeof nativeString[]) => mojoCallableTargetType(
  types.map((type) => Object.freeze({ type, convention: "imm" as const, passing: "plain" as const })),
  unitCarrier, true,
);
const changeCarrier = callback([nativeString, optionalStringCarrier]);
const statCarrier = callback([statsCarrier, statsCarrier]);
const pathParameter = Object.freeze({ name: "path", type: stringType });

export function filesystemWatchExports(): MojoProviderModuleDefinition["exports"] {
  return Object.freeze([
    ...([[watcherId, "FSWatcher", watcherType], [statWatcherId, "StatWatcher", statWatcherType]] as const).map(([id, name, type]) => Object.freeze({ id, name, kind: "class" as const, members: Object.freeze([
      methodMember(id, "close", [], voidType),
      methodMember(id, "ref", [], type),
      methodMember(id, "unref", [], type),
      methodMember(id, "hasRef", [], booleanType),
    ]) })),
    Object.freeze({ id: optionsId, name: "WatchOptions", kind: "interface" as const, members: Object.freeze([
      propertyMember(optionsId, "persistent", booleanType, { readonly: false, optional: true }),
      propertyMember(optionsId, "recursive", booleanType, { readonly: false, optional: true }),
    ]) }),
    Object.freeze({ id: statOptionsId, name: "WatchFileOptions", kind: "interface" as const, members: Object.freeze([
      propertyMember(statOptionsId, "persistent", booleanType, { readonly: false, optional: true }),
      propertyMember(statOptionsId, "interval", numberType, { readonly: false, optional: true }),
    ]) }),
    overloadedFunctionExport(moduleSpecifier, "watch", [
      { parameters: [pathParameter], returnType: watcherType },
      { parameters: [pathParameter, { name: "listener", type: changeType }], returnType: watcherType },
      { parameters: [pathParameter, { name: "options", type: providerRef(moduleSpecifier, "WatchOptions") }, { name: "listener", type: changeType }], returnType: watcherType },
    ]),
    overloadedFunctionExport(moduleSpecifier, "watchFile", [
      { parameters: [pathParameter, { name: "listener", type: statType }], returnType: statWatcherType },
      { parameters: [pathParameter, { name: "options", type: providerRef(moduleSpecifier, "WatchFileOptions") }, { name: "listener", type: statType }], returnType: statWatcherType },
    ]),
    overloadedFunctionExport(moduleSpecifier, "unwatchFile", [
      { parameters: [pathParameter], returnType: voidType },
      { parameters: [pathParameter, { name: "listener", type: statType }], returnType: voidType },
    ]),
  ]);
}

export function filesystemWatchTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(watcherId, watcherCarrier, "implicitly-copyable"),
    nodeProviderType(statWatcherId, watcherCarrier, "implicitly-copyable"),
    ...[optionsId, statOptionsId].map((id) => nodeProviderType(id, optionsCarrier, "copyable", { objectLiteralConstruction: true })),
  ]);
}

export function filesystemWatchOperations(): readonly MojoProviderOperationDefinition[] {
  const operations: MojoProviderOperationDefinition[] = [
    functionCall(`${moduleSpecifier}::watch`, `${moduleSpecifier}::watch(path)`, "filesystem", "watch", [nativeString], watcherCarrier, true),
    functionCall(`${moduleSpecifier}::watch`, `${moduleSpecifier}::watch(path,listener)`, "filesystem", "watch", [nativeString, changeCarrier], watcherCarrier, true),
    functionCall(`${moduleSpecifier}::watch`, `${moduleSpecifier}::watch(path,options,listener)`, "filesystem", "watch", [nativeString, optionsCarrier, changeCarrier], watcherCarrier, true),
    functionCall(`${moduleSpecifier}::watchFile`, `${moduleSpecifier}::watchFile(path,listener)`, "filesystem", "watch_file", [nativeString, statCarrier], watcherCarrier, true),
    functionCall(`${moduleSpecifier}::watchFile`, `${moduleSpecifier}::watchFile(path,options,listener)`, "filesystem", "watch_file", [nativeString, optionsCarrier, statCarrier], watcherCarrier, true),
    functionCall(`${moduleSpecifier}::unwatchFile`, `${moduleSpecifier}::unwatchFile(path)`, "filesystem", "unwatch_file", [nativeString], unitCarrier),
    functionCall(`${moduleSpecifier}::unwatchFile`, `${moduleSpecifier}::unwatchFile(path,listener)`, "filesystem", "unwatch_file", [nativeString, mojoOptionalTargetType(statCarrier)], unitCarrier),
    instanceCall(watcherId, `${watcherId}.close`, `${watcherId}.close()`, "close", watcherCarrier, [], unitCarrier),
    instanceCall(watcherId, `${watcherId}.ref`, `${watcherId}.ref()`, "ref", watcherCarrier, [], watcherCarrier),
    instanceCall(watcherId, `${watcherId}.unref`, `${watcherId}.unref()`, "unref", watcherCarrier, [], watcherCarrier),
    instanceCall(watcherId, `${watcherId}.hasRef`, `${watcherId}.hasRef()`, "has_ref", watcherCarrier, [], boolCarrier),
  ];
  for (const [name, target, result] of [["close", "close", unitCarrier], ["ref", "ref", watcherCarrier], ["unref", "unref", watcherCarrier], ["hasRef", "has_ref", boolCarrier]] as const) {
    operations.push(instanceCall(statWatcherId, `${statWatcherId}.${name}`, `${statWatcherId}.${name}()`, target, watcherCarrier, [], result));
  }
  for (const [id, names] of [[optionsId, ["persistent", "recursive"]], [statOptionsId, ["persistent", "interval"]]] as const) {
    for (const name of names) {
      const carrier = name === "interval" ? optionalFloat64Carrier : optionalBoolCarrier;
      operations.push(propertyRead(id, `${id}.${name}`, name, optionsCarrier, carrier),
        propertyWrite(id, `${id}.${name}`, name, optionsCarrier, carrier));
    }
  }
  return Object.freeze(operations);
}
