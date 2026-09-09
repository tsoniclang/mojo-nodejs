import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  float64Carrier,
  fnExport,
  functionCall,
  hashCarrier,
  hmacCarrier,
  instanceCall,
  nativeString,
  nodeProviderType,
  numberType,
  overloadedFunctionExport,
  overloadedMethodMember,
  providerRef,
  stringType,
} from "../model.js";

const moduleSpecifier = "node:crypto";
const bufferType = providerRef("node:buffer", "Buffer");
const digestTypes = Object.freeze([
  Object.freeze({ name: "Hash", carrier: hashCarrier }),
  Object.freeze({ name: "Hmac", carrier: hmacCarrier }),
]);

export function cryptoModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.crypto",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      ...digestTypes.map(({ name }) => digestExport(name)),
      fnExport(moduleSpecifier, "createHash", [{ name: "algorithm", type: stringType }], providerRef(moduleSpecifier, "Hash")),
      overloadedFunctionExport(moduleSpecifier, "createHmac", [
        {
          parameters: [{ name: "algorithm", type: stringType }, { name: "key", type: stringType }],
          returnType: providerRef(moduleSpecifier, "Hmac"), signatureSuffix: "algorithm,string",
        },
        {
          parameters: [{ name: "algorithm", type: stringType }, { name: "key", type: bufferType }],
          returnType: providerRef(moduleSpecifier, "Hmac"), signatureSuffix: "algorithm,buffer",
        },
      ]),
      fnExport(moduleSpecifier, "randomUUID", [], stringType),
      fnExport(moduleSpecifier, "randomBytes", [{ name: "size", type: numberType }], bufferType),
    ]),
  });
}

function digestExport(name: string): MojoProviderModuleDefinition["exports"][number] {
  const owner = `${moduleSpecifier}::${name}`;
  return Object.freeze({
    id: owner,
    name,
    kind: "interface",
    members: Object.freeze([
      overloadedMethodMember(owner, "update", [
        { parameters: [{ name: "data", type: bufferType }], returnType: providerRef(moduleSpecifier, name), signatureSuffix: "buffer" },
        { parameters: [{ name: "data", type: stringType }], returnType: providerRef(moduleSpecifier, name), signatureSuffix: "string" },
      ]),
      overloadedMethodMember(owner, "digest", [
        { parameters: [], returnType: bufferType },
        { parameters: [{ name: "encoding", type: stringType }], returnType: stringType },
      ]),
    ]),
  });
}

export function cryptoTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze(digestTypes.map(({ name, carrier }) =>
    nodeProviderType(`${moduleSpecifier}::${name}`, carrier, "implicitly-copyable")));
}

export function cryptoOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall("node:crypto::createHash", "node:crypto::createHash(algorithm)", "crypto", "create_hash", [nativeString], hashCarrier, true),
    functionCall("node:crypto::createHmac", "node:crypto::createHmac(algorithm,string)", "crypto", "create_hmac", [nativeString, nativeString], hmacCarrier, true),
    functionCall("node:crypto::createHmac", "node:crypto::createHmac(algorithm,buffer)", "crypto", "create_hmac", [nativeString, bufferCarrier], hmacCarrier, true),
    functionCall("node:crypto::randomUUID", "node:crypto::randomUUID()", "crypto", "random_uuid", [], nativeString, true),
    functionCall("node:crypto::randomBytes", "node:crypto::randomBytes(size)", "crypto", "random_bytes", [float64Carrier], bufferCarrier, true),
    ...digestTypes.flatMap(({ name, carrier }) => {
      const owner = `${moduleSpecifier}::${name}`;
      return [
        instanceCall(owner, `${owner}.update`, `${owner}.update(buffer)`, "update_buffer", carrier, [bufferCarrier], carrier, true),
        instanceCall(owner, `${owner}.update`, `${owner}.update(string)`, "update_string", carrier, [nativeString], carrier, true),
        instanceCall(owner, `${owner}.digest`, `${owner}.digest()`, "digest", carrier, [], bufferCarrier, true),
        instanceCall(owner, `${owner}.digest`, `${owner}.digest(encoding)`, "digest", carrier, [nativeString], nativeString, true),
      ];
    }),
  ]);
}
