import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  dnsAddressArrayCallbackCarrier,
  dnsLookupAddressCarrier,
  dnsLookupCallbackCarrier,
  float64Carrier,
  functionCall,
  nativeString,
  propertyMember,
  propertyRead,
  providerCallbackType,
  providerRef,
  sourcePromise,
  stringArrayType,
  stringListCarrier,
  stringType,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:dns";
const promisesSpecifier = "node:dns/promises";
const lookupAddressId = `${moduleSpecifier}::LookupAddress`;
const anyType = Object.freeze({ kind: "any" as const });

export function dnsModule(): MojoProviderModuleDefinition {
  const lookupCallback = providerCallbackType(
    `${moduleSpecifier}::lookup(hostname,callback)`,
    "callback",
    [
      { name: "error", type: anyType },
      { name: "address", type: stringType },
      { name: "family", type: Object.freeze({ kind: "number" }) },
    ],
  );
  const addressesCallback = (signatureId: string) => providerCallbackType(
    signatureId,
    "callback",
    [
      { name: "error", type: anyType },
      { name: "addresses", type: stringArrayType },
    ],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.dns",
    exports: Object.freeze([
      Object.freeze({
        id: lookupAddressId,
        name: "LookupAddress",
        kind: "interface",
        members: Object.freeze([
          propertyMember(lookupAddressId, "address", stringType),
          propertyMember(lookupAddressId, "family", Object.freeze({ kind: "number" })),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::lookup`,
        name: "lookup",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::lookup(hostname,callback)`,
          name: "lookup",
          parameters: Object.freeze([
            { name: "hostname", type: stringType },
            { name: "callback", type: lookupCallback },
          ]),
          returnType: voidType,
        })]),
      }),
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
      namedImports: Object.freeze([{ exportedName: "LookupAddress" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: `${promisesSpecifier}::lookup`,
        name: "lookup",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${promisesSpecifier}::lookup(hostname)`,
          name: "lookup",
          parameters: Object.freeze([{ name: "hostname", type: stringType }]),
          returnType: sourcePromise(providerRef(moduleSpecifier, "LookupAddress")),
        })]),
      }),
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
  return Object.freeze([Object.freeze({
    exportId: lookupAddressId,
    sourceGenericParameters: Object.freeze([]),
    targetType: dnsLookupAddressCarrier,
  })]);
}

export function dnsOperations(): readonly MojoProviderOperationDefinition[] {
  const stringListFuture = Object.freeze({
    kind: "future" as const,
    domain: "native" as const,
    output: stringListCarrier,
    raises: true,
  });
  return Object.freeze([
    functionCall(`${moduleSpecifier}::lookup`, `${moduleSpecifier}::lookup(hostname,callback)`, "dns", "lookup_callback", [nativeString, dnsLookupCallbackCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::resolve4`, `${moduleSpecifier}::resolve4(hostname,callback)`, "dns", "resolve4_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::resolve6`, `${moduleSpecifier}::resolve6(hostname,callback)`, "dns", "resolve6_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::reverse`, `${moduleSpecifier}::reverse(address,callback)`, "dns", "reverse_callback", [nativeString, dnsAddressArrayCallbackCarrier], unitCarrier, true),
    propertyRead(lookupAddressId, `${lookupAddressId}.address`, "address_value", dnsLookupAddressCarrier, nativeString, "method"),
    propertyRead(lookupAddressId, `${lookupAddressId}.family`, "family_value", dnsLookupAddressCarrier, float64Carrier, "method"),
    functionCall(`${promisesSpecifier}::lookup`, `${promisesSpecifier}::lookup(hostname)`, "dns", "lookup_async", [nativeString], Object.freeze({ kind: "future", domain: "native", output: dnsLookupAddressCarrier, raises: true }), true),
    functionCall(`${promisesSpecifier}::resolve4`, `${promisesSpecifier}::resolve4(hostname)`, "dns", "resolve4_async", [nativeString], stringListFuture, true),
    functionCall(`${promisesSpecifier}::resolve6`, `${promisesSpecifier}::resolve6(hostname)`, "dns", "resolve6_async", [nativeString], stringListFuture, true),
    functionCall(`${promisesSpecifier}::reverse`, `${promisesSpecifier}::reverse(address)`, "dns", "reverse_async", [nativeString], stringListFuture, true),
  ]);
}
