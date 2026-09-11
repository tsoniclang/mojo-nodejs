import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  dnsAddressArrayCallbackCarrier,
  dnsLookupAddressCarrier,
  float64Carrier,
  functionCall,
  nativeString,
  nodeProviderType,
  propertyMember,
  propertyRead,
  providerCallbackType,
  sourcePromise,
  stringArrayType,
  stringListCarrier,
  stringType,
  unitCarrier,
  undefinedType,
  voidType,
} from "../model.js";
import {
  lookupCallOperations, lookupConstantExports, lookupConstantOperations, lookupExport,
  lookupOptionOperations, lookupOptionTypes, lookupRecordExports,
} from "./dns/lookup-contract.js";

const moduleSpecifier = "node:dns";
const promisesSpecifier = "node:dns/promises";
const lookupAddressId = `${moduleSpecifier}::LookupAddress`;
const anyType = Object.freeze({ kind: "any" as const });
const optionalAddresses = Object.freeze({ kind: "union" as const, types: Object.freeze([stringArrayType, undefinedType]) });

export function dnsModule(): MojoProviderModuleDefinition {
  const addressesCallback = (signatureId: string) => providerCallbackType(
    signatureId,
    "callback",
    [
      { name: "error", type: anyType },
      { name: "addresses", type: optionalAddresses },
    ],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.dns",
    exports: Object.freeze([
      ...lookupRecordExports,
      ...lookupConstantExports,
      Object.freeze({
        id: lookupAddressId,
        name: "LookupAddress",
        kind: "interface",
        members: Object.freeze([
          propertyMember(lookupAddressId, "address", stringType),
          propertyMember(lookupAddressId, "family", Object.freeze({ kind: "number" })),
        ]),
      }),
      lookupExport(false),
      ...(["resolve4", "resolve6", "reverse"] as const).map((name) => {
        const signatureId = `${moduleSpecifier}::${name}(${name === "reverse" ? "address" : "hostname"},callback)`;
        return Object.freeze({
          id: `${moduleSpecifier}::${name}`,
          name,
          kind: "function" as const,
          signatures: Object.freeze([Object.freeze({
            id: signatureId,
            name,
            parameters: Object.freeze([
              { name: name === "reverse" ? "address" : "hostname", type: stringType },
              { name: "callback", type: addressesCallback(signatureId) },
            ]),
            returnType: voidType,
          })]),
        });
      }),
    ]),
  });
}

export function dnsPromisesModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier: promisesSpecifier,
    providerModuleId: "tsonic.mojo.node.dns-promises",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier,
      namedImports: Object.freeze(["LookupAddress", "LookupOptions", "LookupAllOptions", "LookupOneOptions"].map((exportedName) => ({ exportedName }))),
    })]),
    exports: Object.freeze([
      lookupExport(true),
      ...(["resolve4", "resolve6", "reverse"] as const).map((name) => Object.freeze({
        id: `${promisesSpecifier}::${name}`,
        name,
        kind: "function" as const,
        signatures: Object.freeze([Object.freeze({
          id: `${promisesSpecifier}::${name}(${name === "reverse" ? "address" : "hostname"})`,
          name,
          parameters: Object.freeze([
            { name: name === "reverse" ? "address" : "hostname", type: stringType },
          ]),
          returnType: sourcePromise(stringArrayType),
        })]),
      })),
    ]),
  });
}

export function dnsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(lookupAddressId, dnsLookupAddressCarrier, "copyable"),
    ...lookupOptionTypes,
  ]);
}

export function dnsOperations(): readonly MojoProviderOperationDefinition[] {
  const stringListFuture = Object.freeze({
    kind: "future" as const,
    domain: "native" as const,
    output: stringListCarrier,
    raises: true,
  });
  return Object.freeze([
    ...lookupCallOperations,
    ...lookupOptionOperations,
    ...lookupConstantOperations,
    functionCall(`${moduleSpecifier}::resolve4`, `${moduleSpecifier}::resolve4(hostname,callback)`, "dns", "resolve4_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::resolve6`, `${moduleSpecifier}::resolve6(hostname,callback)`, "dns", "resolve6_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::reverse`, `${moduleSpecifier}::reverse(address,callback)`, "dns", "reverse_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    propertyRead(lookupAddressId, `${lookupAddressId}.address`, "address_value", dnsLookupAddressCarrier, nativeString, "method"),
    propertyRead(lookupAddressId, `${lookupAddressId}.family`, "family_value", dnsLookupAddressCarrier, float64Carrier, "method"),
    functionCall(`${promisesSpecifier}::resolve4`, `${promisesSpecifier}::resolve4(hostname)`, "dns", "resolve4_async", [nativeString], stringListFuture, true),
    functionCall(`${promisesSpecifier}::resolve6`, `${promisesSpecifier}::resolve6(hostname)`, "dns", "resolve6_async", [nativeString], stringListFuture, true),
    functionCall(`${promisesSpecifier}::reverse`, `${promisesSpecifier}::reverse(address)`, "dns", "reverse_async", [nativeString], stringListFuture, true),
  ]);
}
