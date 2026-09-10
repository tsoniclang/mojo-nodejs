import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition } from "@tsonic/target-mojo/provider";
import { bufferCarrier, functionCall, nodeProviderType, overloadedFunctionExport, providerRef, unitCarrier, voidType, zlibTransformCarrier } from "../../model.js";
import { compressionConstantsExport, compressionConstantsOperations } from "./constants.js";
import { compressionOptionExports, compressionOptionTypes, compressionOptionOperations, sourceOptions, targetOptions, type ResultMode } from "./options.js";
import { compressionCallbackType, compressionCallbackCarrier, compressionInfoExport, compressionInfoType, compressionInfoOperations, sourceResult, targetResult } from "./results.js";
import { compressionStreamExport, compressionStreamOperations } from "./stream.js";

const moduleSpecifier = "node:zlib";
const bufferType = providerRef("node:buffer", "Buffer");
const codecs = [
  ["gzip", "gzip", "createGzip", "zlib"],
  ["gunzip", "gunzip", "createGunzip", "zlib"],
  ["deflate", "deflate", "createDeflate", "zlib"],
  ["inflate", "inflate", "createInflate", "zlib"],
  ["deflateRaw", "deflate_raw", "createDeflateRaw", "zlib"],
  ["inflateRaw", "inflate_raw", "createInflateRaw", "zlib"],
  ["unzip", "unzip", "createUnzip", "zlib"],
  ["brotliCompress", "brotli_compress", "createBrotliCompress", "brotli"],
  ["brotliDecompress", "brotli_decompress", "createBrotliDecompress", "brotli"],
] as const;
const modes: readonly ResultMode[] = ["info", "buffer", "result"];
function optionSuffix(mode: ResultMode): string {
  return mode === "result" ? "options" : `${mode}Options`;
}
function targetSuffix(mode: ResultMode): string {
  return mode === "buffer" ? "options" : `${mode}_options`;
}

export function zlibModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier, providerModuleId: "tsonic.mojo.node.zlib",
    imports: Object.freeze([{ moduleSpecifier: "node:buffer", namedImports: Object.freeze([{ exportedName: "Buffer" }]) }]),
    exports: Object.freeze([
      compressionConstantsExport(), ...compressionOptionExports(), compressionInfoExport, compressionStreamExport,
      ...codecs.flatMap(([name, , factory, family]) => [
        overloadedFunctionExport(moduleSpecifier, `${name}Sync`, [
          { parameters: [{ name: "input", type: bufferType }], returnType: bufferType, signatureSuffix: "input" },
          ...modes.map((mode) => ({
            parameters: [{ name: "input", type: bufferType }, { name: "options", type: sourceOptions(family, mode) }],
            returnType: sourceResult(mode), signatureSuffix: `input,${optionSuffix(mode)}`,
          })),
        ]),
        overloadedFunctionExport(moduleSpecifier, name, [
          {
            parameters: [{ name: "input", type: bufferType }, { name: "callback", type: compressionCallbackType(`${moduleSpecifier}::${name}(input,callback)`, "buffer") }],
            returnType: voidType, signatureSuffix: "input,callback",
          },
          ...modes.map((mode) => ({
            parameters: [
              { name: "input", type: bufferType }, { name: "options", type: sourceOptions(family, mode) },
              { name: "callback", type: compressionCallbackType(`${moduleSpecifier}::${name}(input,${optionSuffix(mode)},callback)`, mode) },
            ],
            returnType: voidType, signatureSuffix: `input,${optionSuffix(mode)},callback`,
          })),
        ]),
        overloadedFunctionExport(moduleSpecifier, factory, [
          { parameters: [], returnType: providerRef(moduleSpecifier, "Zlib"), signatureSuffix: "" },
          { parameters: [{ name: "options", type: sourceOptions(family) }], returnType: providerRef(moduleSpecifier, "Zlib"), signatureSuffix: "options" },
        ]),
      ]),
    ]),
  });
}

export function zlibTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    ...compressionOptionTypes(), compressionInfoType,
    nodeProviderType(compressionStreamExport.id, zlibTransformCarrier, "implicitly-copyable"),
  ]);
}

export function zlibOperations(): readonly MojoProviderOperationDefinition[] {
  const operations: MojoProviderOperationDefinition[] = [
    ...compressionConstantsOperations(), ...compressionOptionOperations(),
    ...compressionInfoOperations, ...compressionStreamOperations,
  ];
  for (const [name, target, factory, family] of codecs) {
    operations.push(
      functionCall(`${moduleSpecifier}::${name}Sync`, `${moduleSpecifier}::${name}Sync(input)`, "zlib", `${target}_sync`, [bufferCarrier], bufferCarrier, true),
      functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input,callback)`, "zlib", `${target}_callback`, [bufferCarrier, compressionCallbackCarrier("buffer")], unitCarrier, true),
      functionCall(`${moduleSpecifier}::${factory}`, `${moduleSpecifier}::${factory}()`, "zlib", `create_${target}`, [], zlibTransformCarrier, true),
      functionCall(`${moduleSpecifier}::${factory}`, `${moduleSpecifier}::${factory}(options)`, "zlib", `create_${target}_options`, [targetOptions(family)], zlibTransformCarrier, true),
    );
    for (const mode of modes) {
      operations.push(
        functionCall(`${moduleSpecifier}::${name}Sync`, `${moduleSpecifier}::${name}Sync(input,${optionSuffix(mode)})`, "zlib", `${target}_sync_${targetSuffix(mode)}`, [bufferCarrier, targetOptions(family)], targetResult(mode), true),
        functionCall(`${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}(input,${optionSuffix(mode)},callback)`, "zlib", `${target}_callback_${targetSuffix(mode)}`, [bufferCarrier, targetOptions(family), compressionCallbackCarrier(mode)], unitCarrier, true),
      );
    }
  }
  return Object.freeze(operations);
}
