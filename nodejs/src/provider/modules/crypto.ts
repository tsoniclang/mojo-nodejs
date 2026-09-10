import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  booleanType,
  boolCarrier,
  float64Carrier,
  fnExport,
  functionCall,
  hashCarrier,
  hmacCarrier,
  instanceCall,
  methodMember,
  nativeString,
  nodeProviderType,
  numberType,
  overloadedFunctionExport,
  overloadedMethodMember,
  providerRef,
  stringArrayType,
  stringListCarrier,
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
      ...["getCiphers", "getHashes", "getCurves"].map((name) => fnExport(moduleSpecifier, name, [], stringArrayType)),
      fnExport(moduleSpecifier, "randomBytes", [{ name: "size", type: numberType }], bufferType),
      fnExport(moduleSpecifier, "randomFillSync", [{ name: "buffer", type: bufferType }], bufferType),
      fnExport(moduleSpecifier, "timingSafeEqual", [{ name: "left", type: bufferType }, { name: "right", type: bufferType }], booleanType),
      overloadedFunctionExport(moduleSpecifier, "randomInt", [
        { parameters: [{ name: "maximum", type: numberType }], returnType: numberType },
        { parameters: [{ name: "minimum", type: numberType }, { name: "maximum", type: numberType }], returnType: numberType },
      ]),
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
      ...(name === "Hash" ? [methodMember(owner, "copy", [], providerRef(moduleSpecifier, "Hash"))] : []),
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
    ...([["getCiphers", "get_ciphers"], ["getHashes", "get_hashes"], ["getCurves", "get_curves"]] as const).map(([source, target]) =>
      functionCall(`node:crypto::${source}`, `node:crypto::${source}()`, "crypto_catalog", target, [], stringListCarrier, true)),
    functionCall("node:crypto::randomBytes", "node:crypto::randomBytes(size)", "crypto", "random_bytes", [float64Carrier], bufferCarrier, true),
    Object.freeze({
      ...functionCall("node:crypto::randomFillSync", "node:crypto::randomFillSync(buffer)", "crypto", "random_fill", [bufferCarrier], bufferCarrier, true),
      target: Object.freeze({ kind: "function-call" as const, modulePath: Object.freeze(["tsonic_node", "crypto"]), name: "random_fill",
        arguments: Object.freeze([{ convention: "mut" as const, position: "positional-or-keyword" as const }]),
      }),
    }),
    functionCall("node:crypto::timingSafeEqual", "node:crypto::timingSafeEqual(left,right)", "crypto", "timing_safe_equal", [bufferCarrier, bufferCarrier], boolCarrier, true),
    functionCall("node:crypto::randomInt", "node:crypto::randomInt(maximum)", "crypto", "random_int", [float64Carrier], float64Carrier, true),
    functionCall("node:crypto::randomInt", "node:crypto::randomInt(minimum,maximum)", "crypto", "random_int", [float64Carrier, float64Carrier], float64Carrier, true),
    instanceCall("node:crypto::Hash", "node:crypto::Hash.copy", "node:crypto::Hash.copy()", "copy_hash", hashCarrier, [], hashCarrier, true),
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
