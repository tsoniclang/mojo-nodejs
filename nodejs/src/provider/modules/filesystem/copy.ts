import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition } from "@tsonic/target-mojo/provider";
import { mojoCallableTargetType, mojoFutureTargetType, mojoNamedTargetType, mojoOptionalTargetType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import { booleanType, boolCarrier, float64Carrier, functionCall, nativeString, nodeProviderType, numberType, overloadedFunctionExport, propertyMember, propertyRead, propertyWrite, providerRef, sourcePromise, stringType, unitCarrier, voidType } from "../../model.js";

const parameters = [{ name: "source", type: stringType }, { name: "destination", type: stringType }];
const controls = [
  { name: "dereference", target: "dereference", type: booleanType, carrier: boolCarrier },
  { name: "errorOnExist", target: "error_on_exist", type: booleanType, carrier: boolCarrier },
  { name: "force", target: "force", type: booleanType, carrier: boolCarrier },
  { name: "mode", target: "mode", type: numberType, carrier: float64Carrier },
  { name: "preserveTimestamps", target: "preserve_timestamps", type: booleanType, carrier: boolCarrier },
  { name: "recursive", target: "recursive", type: booleanType, carrier: boolCarrier },
  { name: "verbatimSymlinks", target: "verbatim_symlinks", type: booleanType, carrier: boolCarrier },
];

const records = [false, true].map((asynchronous) => {
  const name = asynchronous ? "CopyOptions" : "CopySyncOptions";
  const id = `node:fs::${name}`;
  const nativeName = asynchronous ? "AsyncCopyOptions" : "CopyOptions";
  const result = asynchronous ? mojoUnionTargetType([boolCarrier, Object.freeze({ ...mojoFutureTargetType(boolCarrier, "native", true), captureOrigins: "empty" as const })]) : boolCarrier;
  const filter = Object.freeze({
    kind: "function" as const, id: `${id}.filter`, parameters,
    returnType: asynchronous ? { kind: "union" as const, types: [booleanType, sourcePromise(booleanType)] } : booleanType,
  });
  const carrier = mojoNamedTargetType(`tsonic.mojo.node.fs.${nativeName}`, ["tsonic_node", "filesystem"], nativeName);
  const fields = [...controls, { name: "filter", target: "filter", type: filter, carrier: mojoCallableTargetType(parameters.map(() => ({ type: nativeString, convention: "imm", passing: "plain" })), result, true) }];
  return { name, id, carrier, fields };
});

export function filesystemCopyExports(asynchronous = false): MojoProviderModuleDefinition["exports"] {
  const moduleSpecifier = asynchronous ? "node:fs/promises" : "node:fs";
  const record = records[asynchronous ? 1 : 0]!;
  return Object.freeze([
    ...(asynchronous ? [] : records.map((value) => Object.freeze({
      id: value.id, name: value.name, kind: "interface" as const,
      members: Object.freeze(value.fields.map((field) => propertyMember(value.id, field.name, field.type, { optional: true, readonly: false }))),
    }))),
    overloadedFunctionExport(moduleSpecifier, asynchronous ? "cp" : "cpSync", [
      { parameters, returnType: asynchronous ? sourcePromise(voidType) : voidType, signatureSuffix: "source,destination" },
      { parameters: [...parameters, { name: "options", type: providerRef("node:fs", record.name) }], returnType: asynchronous ? sourcePromise(voidType) : voidType, signatureSuffix: "source,destination,options" },
    ]),
  ]);
}

export function filesystemCopyTypes(): readonly MojoProviderTypeDefinition[] {
  return records.map((record) => nodeProviderType(record.id, record.carrier, "copyable", { objectLiteralConstruction: true }));
}

export function filesystemCopyOperations(asynchronous = false): readonly MojoProviderOperationDefinition[] {
  const moduleSpecifier = asynchronous ? "node:fs/promises" : "node:fs";
  const name = asynchronous ? "cp" : "cpSync";
  const owner = `${moduleSpecifier}::${name}`;
  const record = records[asynchronous ? 1 : 0]!;
  const result = asynchronous ? mojoFutureTargetType(unitCarrier, "native", true) : unitCarrier;
  return Object.freeze([
    ...[false, true].map((options) => functionCall(owner, `${owner}(source,destination${options ? ",options" : ""})`, asynchronous ? ["filesystem", "promises"] : "filesystem", "copy_tree", [nativeString, nativeString, ...options ? [record.carrier] : []], result, true)),
    ...(asynchronous ? [] : records.flatMap((value) => value.fields.flatMap((field) => [
      propertyRead(value.id, `${value.id}.${field.name}`, field.target, value.carrier, mojoOptionalTargetType(field.carrier)),
      propertyWrite(value.id, `${value.id}.${field.name}`, field.target, value.carrier, mojoOptionalTargetType(field.carrier)),
    ]))),
  ]);
}
