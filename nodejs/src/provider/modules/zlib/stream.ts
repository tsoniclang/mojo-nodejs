import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, emptyCallbackCarrier, float64Carrier, instanceCall,
  nativeString, numberType, overloadedMethodMember, propertyMember, propertyRead,
  providerCallbackType, providerRef, stringType, undefinedType, unitCarrier, voidType, zlibTransformCarrier,
} from "../../model.js";
import type { MojoProviderModuleDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";

type Export = MojoProviderModuleDefinition["exports"][number];
type SourceType = NonNullable<Export["signatures"]>[number]["parameters"][number]["type"];
interface Argument { readonly name: string; readonly source: SourceType; readonly target: MojoTargetTypeRef }
interface Row {
  readonly name: string;
  readonly target: string;
  readonly suffix: string;
  readonly arguments: readonly Argument[];
  readonly result: SourceType;
  readonly carrier: MojoTargetTypeRef;
  readonly raises: boolean;
}
const owner = "node:zlib::Zlib";
const input = { name: "input", source: providerRef("node:buffer", "Buffer"), target: bufferCarrier };
const text = { name: "input", source: stringType, target: nativeString };
const kind = { name: "kind", source: numberType, target: float64Carrier };
function callback(signature: string): Argument {
  return { name: "callback", source: providerCallbackType(signature, "callback", []), target: emptyCallbackCarrier };
}

const rows: readonly Row[] = [
  { name: "write", target: "write", suffix: "input", arguments: [input], result: booleanType, carrier: boolCarrier, raises: true },
  { name: "write", target: "write_string", suffix: "text", arguments: [text], result: booleanType, carrier: boolCarrier, raises: true },
  { name: "read", target: "read", suffix: "", arguments: [], result: { kind: "union", types: [input.source, undefinedType] }, carrier: mojoOptionalTargetType(bufferCarrier), raises: true },
  ...[
    { target: "end", suffix: "", arguments: [] },
    { target: "end_buffer", suffix: "input", arguments: [input] },
    { target: "end_string", suffix: "text", arguments: [text] },
  ].map((row) => ({ ...row, name: "end", result: providerRef("node:zlib", "Zlib"), carrier: zlibTransformCarrier, raises: true })),
  ...[
    { target: "flush", suffix: "", arguments: [] },
    { target: "flush_kind", suffix: "kind", arguments: [kind] },
    { target: "flush_callback", suffix: "callback", arguments: [callback(`${owner}.flush(callback)`)] },
    { target: "flush_kind_callback", suffix: "kind,callback", arguments: [kind, callback(`${owner}.flush(kind,callback)`)] },
  ].map((row) => ({ ...row, name: "flush", result: voidType, carrier: unitCarrier, raises: true })),
  { name: "params", target: "params_callback", suffix: "level,strategy,callback", arguments: [
    { name: "level", source: numberType, target: float64Carrier },
    { name: "strategy", source: numberType, target: float64Carrier },
    callback(`${owner}.params(level,strategy,callback)`),
  ], result: voidType, carrier: unitCarrier, raises: true },
  { name: "reset", target: "reset", suffix: "", arguments: [], result: voidType, carrier: unitCarrier, raises: true },
  { name: "destroy", target: "destroy", suffix: "", arguments: [], result: voidType, carrier: unitCarrier, raises: false },
  { name: "close", target: "close", suffix: "", arguments: [], result: voidType, carrier: unitCarrier, raises: false },
  { name: "close", target: "close_callback", suffix: "callback", arguments: [callback(`${owner}.close(callback)`)], result: voidType, carrier: unitCarrier, raises: true },
];

export const compressionStreamExport: Export = Object.freeze({
  id: owner, name: "Zlib", kind: "class",
  members: Object.freeze([
    ...[...new Set(rows.map((row) => row.name))].map((name) => overloadedMethodMember(owner, name,
      rows.filter((row) => row.name === name).map((row) => ({
        signatureSuffix: row.suffix,
        parameters: row.arguments.map((argument) => ({ name: argument.name, type: argument.source })),
        returnType: row.result,
      })))),
    propertyMember(owner, "bytesWritten", numberType), propertyMember(owner, "closed", booleanType),
  ]),
});
export const compressionStreamOperations = Object.freeze([
  ...rows.map((row) => instanceCall(owner, `${owner}.${row.name}`, `${owner}.${row.name}(${row.suffix})`,
    row.target, zlibTransformCarrier, row.arguments.map((argument) => argument.target), row.carrier, row.raises)),
  propertyRead(owner, `${owner}.bytesWritten`, "bytes_written", zlibTransformCarrier, float64Carrier, "method"),
  propertyRead(owner, `${owner}.closed`, "closed", zlibTransformCarrier, boolCarrier, "method"),
]);
