import {
  mojoCallableTargetType, mojoListTargetType, mojoNamedTargetType,
  mojoOptionalTargetType, mojoUnionTargetType,
} from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, dnsLookupAddressCarrier, dnsLookupCallbackCarrier,
  float64Carrier, functionCall, functionValue, jsValueCarrier, nativeString,
  nodeProviderType, numberType, optionalBoolCarrier, optionalFloat64Carrier,
  optionalStringCarrier, overloadedFunctionExport, propertyMember, propertyRead,
  propertyWrite, providerCallbackType, providerRef, sourcePromise, stringType,
  undefinedType, unitCarrier, valueExport, voidType,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";

const moduleSpecifier = "node:dns";
const optionsCarrier = mojoNamedTargetType("tsonic.mojo.node.dns.LookupOptions", ["tsonic_node", "dns"], "LookupOptions");
const addressType = providerRef(moduleSpecifier, "LookupAddress");
const addressesType: ProviderTypeExpression = { kind: "array", elementType: addressType };
const addressesCarrier = mojoListTargetType(dnsLookupAddressCarrier);
const familyType: ProviderTypeExpression = { kind: "union", types: [numberType, stringType] };
const familyCarrier = mojoOptionalTargetType(mojoUnionTargetType([float64Carrier, nativeString]));
const union = (...types: ProviderTypeExpression[]): ProviderTypeExpression => ({ kind: "union", types });
const callback = (parameters: readonly MojoTargetTypeRef[]) => mojoCallableTargetType(
  parameters.map((type) => ({ type, convention: "imm", passing: "plain" })), unitCarrier, true,
);
const allCallbackCarrier = callback([jsValueCarrier, mojoOptionalTargetType(addressesCarrier)]);
const anyCallbackCarrier = callback([jsValueCarrier, mojoOptionalTargetType(mojoUnionTargetType([nativeString, addressesCarrier])), optionalFloat64Carrier]);

const optionRecords = [
  { name: "LookupAllOptions", all: { kind: "literal", value: true } as ProviderTypeExpression, optional: false },
  { name: "LookupOneOptions", all: { kind: "literal", value: false } as ProviderTypeExpression, optional: true },
  { name: "LookupOptions", all: booleanType, optional: true },
] as const;
const optionFields = [
  ["family", familyType, familyCarrier],
  ["hints", numberType, optionalFloat64Carrier],
  ["verbatim", booleanType, optionalBoolCarrier],
  ["order", stringType, optionalStringCarrier],
] as const;

export const lookupRecordExports = optionRecords.map((record) => {
  const id = `${moduleSpecifier}::${record.name}`;
  return Object.freeze({ id, name: record.name, kind: "interface" as const, members: [
    ...optionFields.map(([name, type]) => propertyMember(id, name, type, { optional: true, readonly: false })),
    propertyMember(id, "all", record.all, { optional: record.optional, readonly: false }),
  ] });
});

export const lookupOptionTypes = optionRecords.map((record) =>
  nodeProviderType(`${moduleSpecifier}::${record.name}`, optionsCarrier, "copyable", { objectLiteralConstruction: true }));

export const lookupOptionOperations = optionRecords.flatMap((record) => {
  const id = `${moduleSpecifier}::${record.name}`;
  return [...optionFields, ["all", record.all, optionalBoolCarrier] as const].flatMap(([name, , target]) => [
    propertyRead(id, `${id}.${name}`, name, optionsCarrier, target),
    propertyWrite(id, `${id}.${name}`, name, optionsCarrier, target),
  ]);
});

const lookupShapes = [
  { suffix: "", parameters: [], result: addressType, resultCarrier: dnsLookupAddressCarrier, callbackCarrier: dnsLookupCallbackCarrier, callbackParameters: [{ name: "error", type: { kind: "any" } }, { name: "address", type: union(stringType, undefinedType) }, { name: "family", type: union(numberType, undefinedType) }], native: "lookup" },
  { suffix: ",family", parameters: [{ name: "family", type: numberType }], result: addressType, resultCarrier: dnsLookupAddressCarrier, callbackCarrier: dnsLookupCallbackCarrier, callbackParameters: [{ name: "error", type: { kind: "any" } }, { name: "address", type: union(stringType, undefinedType) }, { name: "family", type: union(numberType, undefinedType) }], native: "lookup_family" },
  { suffix: ",allOptions", parameters: [{ name: "options", type: providerRef(moduleSpecifier, "LookupAllOptions") }], result: addressesType, resultCarrier: addressesCarrier, callbackCarrier: allCallbackCarrier, callbackParameters: [{ name: "error", type: { kind: "any" } }, { name: "addresses", type: union(addressesType, undefinedType) }], native: "lookup_all" },
  { suffix: ",oneOptions", parameters: [{ name: "options", type: providerRef(moduleSpecifier, "LookupOneOptions") }], result: addressType, resultCarrier: dnsLookupAddressCarrier, callbackCarrier: dnsLookupCallbackCarrier, callbackParameters: [{ name: "error", type: { kind: "any" } }, { name: "address", type: union(stringType, undefinedType) }, { name: "family", type: union(numberType, undefinedType) }], native: "lookup_one" },
  { suffix: ",options", parameters: [{ name: "options", type: providerRef(moduleSpecifier, "LookupOptions") }], result: union(addressType, addressesType), resultCarrier: mojoUnionTargetType([dnsLookupAddressCarrier, addressesCarrier]), callbackCarrier: anyCallbackCarrier, callbackParameters: [{ name: "error", type: { kind: "any" } }, { name: "address", type: union(stringType, addressesType, undefinedType) }, { name: "family", type: union(numberType, undefinedType), optional: true }], native: "lookup_any" },
] as const;

export function lookupExport(promises: boolean) {
  const moduleName = promises ? "node:dns/promises" : moduleSpecifier;
  return overloadedFunctionExport(moduleName, "lookup", lookupShapes.map((shape) => {
    const suffix = `hostname${shape.suffix}${promises ? "" : ",callback"}`;
    return {
      signatureSuffix: suffix,
      parameters: [
        { name: "hostname", type: stringType },
        ...shape.parameters,
        ...promises ? [] : [{ name: "callback", type: providerCallbackType(`${moduleName}::lookup(${suffix})`, "callback", shape.callbackParameters) }],
      ],
      returnType: promises ? sourcePromise(shape.result) : voidType,
    };
  }));
}

export const lookupCallOperations = [false, true].flatMap((promises) => lookupShapes.map((shape) => {
  const moduleName = promises ? "node:dns/promises" : moduleSpecifier;
  return functionCall(`${moduleName}::lookup`, `${moduleName}::lookup(hostname${shape.suffix}${promises ? "" : ",callback"})`, "dns", `${shape.native}_${promises ? "async" : "callback"}`,
    [nativeString, ...shape.parameters.map((parameter) => parameter.type.kind === "number" ? float64Carrier : optionsCarrier), ...promises ? [] : [shape.callbackCarrier]],
    promises ? { kind: "future", domain: "native", output: shape.resultCarrier, raises: true } : unitCarrier, true);
}));

const constants = [["ADDRCONFIG", "addrconfig"], ["V4MAPPED", "v4mapped"], ["ALL", "all_addresses"]] as const;
export const lookupConstantExports = constants.map(([name]) => valueExport(moduleSpecifier, name, numberType));
export const lookupConstantOperations = constants.map(([name, native]) => functionValue(`${moduleSpecifier}::${name}`, "dns", native, float64Carrier));
