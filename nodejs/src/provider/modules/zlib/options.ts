import {
  mojoDictionaryTargetType, mojoNamedTargetType, mojoOptionalTargetType, mojoUnionTargetType,
} from "@tsonic/target-mojo/provider";
import type {
  MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, float64Carrier, nodeProviderType, numberType,
  propertyMember, propertyRead, propertyWrite, providerRef, zlibOptionsCarrier,
} from "../../model.js";

type Export = MojoProviderModuleDefinition["exports"][number];
type SourceType = NonNullable<NonNullable<Export["members"]>[number]["type"]>;
export type CodecFamily = "zlib" | "brotli";
export type ResultMode = "buffer" | "info" | "result";
const brotliCarrier = mojoNamedTargetType("tsonic.mojo.node.BrotliOptions", ["tsonic_node", "zlib"], "BrotliOptions");
const brotliValue = Object.freeze({ kind: "union" as const, types: Object.freeze([booleanType, numberType]) });
const parametersType = Object.freeze({ kind: "source-global" as const, name: "Record", typeArguments: Object.freeze([numberType, brotliValue]) });
const parametersCarrier = mojoDictionaryTargetType(float64Carrier, mojoUnionTargetType([float64Carrier, boolCarrier]));

const commonFields = [
  ["flush", "flush"], ["finishFlush", "finish_flush"], ["chunkSize", "chunk_size"],
  ["maxOutputLength", "max_output_length"],
] as const;
const zlibFields = [
  ["windowBits", "window_bits"], ["level", "level"], ["memLevel", "mem_level"], ["strategy", "strategy"],
] as const;

function optionName(family: CodecFamily, mode: ResultMode): string {
  return `${family === "zlib" ? "Zlib" : "Brotli"}${mode === "info" ? "Info" : mode === "buffer" ? "Buffer" : ""}Options`;
}

export function sourceOptions(family: CodecFamily, mode: ResultMode = "result") {
  return providerRef("node:zlib", optionName(family, mode));
}

export function targetOptions(family: CodecFamily): MojoTargetTypeRef {
  return family === "zlib" ? zlibOptionsCarrier : brotliCarrier;
}

interface Field {
  readonly source: string;
  readonly target: string;
  readonly sourceType: SourceType;
  readonly targetType: MojoTargetTypeRef;
  readonly optional: boolean;
}

function fields(family: CodecFamily, mode: ResultMode): readonly Field[] {
  const numeric = family === "zlib" ? [...commonFields, ...zlibFields] : commonFields;
  return Object.freeze([
    ...numeric.map(([source, target]) => ({ source, target, sourceType: numberType, targetType: float64Carrier, optional: true })),
    family === "zlib"
      ? { source: "dictionary", target: "dictionary", sourceType: providerRef("node:buffer", "Buffer"), targetType: bufferCarrier, optional: true }
      : { source: "params", target: "params", sourceType: parametersType, targetType: parametersCarrier, optional: true },
    {
      source: "info", target: "info",
      sourceType: mode === "result" ? booleanType : Object.freeze({ kind: "literal" as const, value: mode === "info" }),
      targetType: boolCarrier, optional: mode !== "info",
    },
  ]);
}

export function compressionOptionExports(): readonly Export[] {
  return Object.freeze((["zlib", "brotli"] as const).flatMap((family) =>
    (["result", "buffer", "info"] as const).map((mode) => {
      const name = optionName(family, mode);
      const id = `node:zlib::${name}`;
      return Object.freeze({
        id, name, kind: "interface" as const,
        members: Object.freeze(fields(family, mode).map((field) =>
          propertyMember(id, field.source, field.sourceType, { readonly: false, optional: field.optional }))),
      });
    })));
}

export function compressionOptionTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze((["zlib", "brotli"] as const).flatMap((family) =>
    (["result", "buffer", "info"] as const).map((mode) =>
      nodeProviderType(`node:zlib::${optionName(family, mode)}`, targetOptions(family),
        family === "zlib" ? "implicitly-copyable" : "copyable", { objectLiteralConstruction: true }))));
}

export function compressionOptionOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze((["zlib", "brotli"] as const).flatMap((family) =>
    (["result", "buffer", "info"] as const).flatMap((mode) => {
      const id = `node:zlib::${optionName(family, mode)}`;
      const carrier = targetOptions(family);
      return fields(family, mode).flatMap((field) => [
        propertyRead(id, `${id}.${field.source}`, field.optional ? field.target : "info_value", carrier,
          field.optional ? mojoOptionalTargetType(field.targetType) : field.targetType,
          field.optional ? "member" : "method"),
        propertyWrite(id, `${id}.${field.source}`, field.target, carrier, mojoOptionalTargetType(field.targetType)),
      ]);
    })));
}
