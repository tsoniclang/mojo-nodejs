import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  float64Carrier,
  functionCall,
  instanceCall,
  numberType,
  overloadedFunctionExport,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerCallbackType,
  providerRef,
  undefinedType,
  unitCarrier,
  voidType,
  zlibCallbackCarrier,
  zlibOptionsCarrier,
  zlibTransformCarrier,
} from "../model.js";

const moduleSpecifier = "node:zlib";
const optionsId = `${moduleSpecifier}::ZlibOptions`;
const transformId = `${moduleSpecifier}::Zlib`;
const bufferType = providerRef("node:buffer", "Buffer");
const optionsType = providerRef(moduleSpecifier, "ZlibOptions");
const optionalBufferType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([bufferType, undefinedType]),
});

const syncOperations = [
  ["gzipSync", "gzip_sync"],
  ["gunzipSync", "gunzip_sync"],
  ["deflateSync", "deflate_sync"],
  ["inflateSync", "inflate_sync"],
  ["deflateRawSync", "deflate_raw_sync"],
  ["inflateRawSync", "inflate_raw_sync"],
  ["unzipSync", "unzip_sync"],
  ["brotliCompressSync", "brotli_compress_sync"],
  ["brotliDecompressSync", "brotli_decompress_sync"],
] as const;

const callbackOperations = [
  ["gzip", "gzip_callback"],
  ["gunzip", "gunzip_callback"],
  ["deflate", "deflate_callback"],
  ["inflate", "inflate_callback"],
  ["deflateRaw", "deflate_raw_callback"],
  ["inflateRaw", "inflate_raw_callback"],
  ["unzip", "unzip_callback"],
  ["brotliCompress", "brotli_compress_callback"],
  ["brotliDecompress", "brotli_decompress_callback"],
] as const;

const factories = [
  ["createGzip", "create_gzip"],
  ["createGunzip", "create_gunzip"],
  ["createDeflate", "create_deflate"],
  ["createInflate", "create_inflate"],
  ["createDeflateRaw", "create_deflate_raw"],
  ["createInflateRaw", "create_inflate_raw"],
] as const;

export function zlibModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.zlib",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: optionsId,
        name: "ZlibOptions",
        kind: "interface",
        members: Object.freeze([
          ...(["flush", "finishFlush", "chunkSize", "windowBits", "level", "memLevel", "strategy", "maxOutputLength"] as const)
            .map((name) => propertyMember(optionsId, name, numberType, {
              readonly: false,
              optional: true,
            })),
          propertyMember(optionsId, "dictionary", bufferType, { readonly: false, optional: true }),
          propertyMember(optionsId, "info", booleanType, { readonly: false, optional: true }),
        ]),
      }),
      Object.freeze({
        id: transformId,
        name: "Zlib",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${transformId}.write`,
            name: "write",
            kind: "method",
            signatures: Object.freeze([Object.freeze({
              id: `${transformId}.write(input)`,
              name: "write",
              parameters: Object.freeze([{ name: "input", type: bufferType }]),
              returnType: booleanType,
            })]),
          }),
          Object.freeze({
            id: `${transformId}.read`,
            name: "read",
            kind: "method",
            signatures: Object.freeze([Object.freeze({
              id: `${transformId}.read()`,
              name: "read",
              parameters: Object.freeze([]),
              returnType: optionalBufferType,
            })]),
          }),
          Object.freeze({
            id: `${transformId}.end`,
            name: "end",
            kind: "method",
            signatures: Object.freeze([Object.freeze({
              id: `${transformId}.end()`,
              name: "end",
              parameters: Object.freeze([]),
              returnType: voidType,
            })]),
          }),
        ]),
      }),
      ...syncOperations.map(([name]) => overloadedFunctionExport(moduleSpecifier, name, [
        { parameters: [{ name: "input", type: bufferType }], returnType: bufferType, signatureSuffix: "input" },
        { parameters: [{ name: "input", type: bufferType }, { name: "options", type: optionsType }], returnType: bufferType, signatureSuffix: "input,options" },
      ])),
      ...callbackOperations.map(([name]) => overloadedFunctionExport(moduleSpecifier, name, [
        {
          parameters: [
            { name: "input", type: bufferType },
            { name: "callback", type: zlibCallbackType(`${moduleSpecifier}::${name}(input,callback)`) },
          ],
          returnType: voidType,
          signatureSuffix: "input,callback",
        },
        {
          parameters: [
            { name: "input", type: bufferType },
            { name: "options", type: optionsType },
            { name: "callback", type: zlibCallbackType(`${moduleSpecifier}::${name}(input,options,callback)`) },
          ],
          returnType: voidType,
          signatureSuffix: "input,options,callback",
        },
      ])),
      ...factories.map(([name]) => overloadedFunctionExport(moduleSpecifier, name, [
        { parameters: [], returnType: providerRef(moduleSpecifier, "Zlib"), signatureSuffix: "" },
        { parameters: [{ name: "options", type: optionsType }], returnType: providerRef(moduleSpecifier, "Zlib"), signatureSuffix: "options" },
      ])),
    ]),
  });
}

export function zlibTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: optionsId,
      sourceGenericParameters: Object.freeze([]),
      targetType: zlibOptionsCarrier,
      objectLiteralConstruction: Object.freeze({ kind: "struct-default" }),
    }),
    Object.freeze({
      exportId: transformId,
      sourceGenericParameters: Object.freeze([]),
      targetType: zlibTransformCarrier,
    }),
  ]);
}

export function zlibOperations(): readonly MojoProviderOperationDefinition[] {
  const rows: MojoProviderOperationDefinition[] = [];
  for (const [name, target] of syncOperations) {
    rows.push(
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input)`, "zlib", target, [bufferCarrier], bufferCarrier, true),
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input,options)`, "zlib", `${target}_options`, [bufferCarrier, zlibOptionsCarrier], bufferCarrier, true),
    );
  }
  for (const [name, target] of callbackOperations) {
    rows.push(
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input,callback)`, "zlib", target, [bufferCarrier, zlibCallbackCarrier], unitCarrier, true),
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input,options,callback)`, "zlib", `${target}_options`, [bufferCarrier, zlibOptionsCarrier, zlibCallbackCarrier], unitCarrier, true),
    );
  }
  for (const [name, target] of factories) {
    rows.push(
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}()`, "zlib", target, [], zlibTransformCarrier),
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(options)`, "zlib", `${target}_options`, [zlibOptionsCarrier], zlibTransformCarrier),
    );
  }
  rows.push(
    instanceCall(transformId, `${transformId}.write`, `${transformId}.write(input)`, "write", zlibTransformCarrier, [bufferCarrier], boolCarrier, true, "mut"),
    instanceCall(transformId, `${transformId}.read`, `${transformId}.read()`, "read", zlibTransformCarrier, [], mojoOptionalTargetType(bufferCarrier), false, "mut"),
    instanceCall(transformId, `${transformId}.end`, `${transformId}.end()`, "end", zlibTransformCarrier, [], unitCarrier, true, "mut"),
  );
  for (const [sourceName, targetName] of [
    ["flush", "flush"],
    ["finishFlush", "finish_flush"],
    ["chunkSize", "chunk_size"],
    ["windowBits", "window_bits"],
    ["level", "level"],
    ["memLevel", "mem_level"],
    ["strategy", "strategy"],
    ["maxOutputLength", "max_output_length"],
  ] as const) {
    rows.push(...optionProperty(sourceName, targetName, mojoOptionalTargetType(float64Carrier)));
  }
  rows.push(
    ...optionProperty("dictionary", "dictionary", mojoOptionalTargetType(bufferCarrier)),
    ...optionProperty("info", "info", mojoOptionalTargetType(boolCarrier)),
  );
  return Object.freeze(rows);
}

function zlibCallbackType(signatureId: string) {
  return providerCallbackType(signatureId, "callback", [
    { name: "error", type: Object.freeze({ kind: "any" }) },
    { name: "result", type: bufferType },
  ]);
}

function optionProperty(
  sourceName: string,
  targetName: string,
  type: MojoTargetTypeRef,
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    propertyRead(optionsId, `${optionsId}.${sourceName}`, targetName, zlibOptionsCarrier, type),
    propertyWrite(optionsId, `${optionsId}.${sourceName}`, targetName, zlibOptionsCarrier, type),
  ]);
}
