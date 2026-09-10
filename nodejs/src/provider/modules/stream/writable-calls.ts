import { mojoCallableTargetType, mojoOptionalTargetType, mojoSourceErrorType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, instanceCall,
  nativeString, optionalStringCarrier, overloadedMethodMember,
  providerCallbackType, providerRef, stringType, undefinedType, unitCarrier,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";

interface Argument {
  readonly name: string;
  readonly source: ProviderTypeExpression;
  readonly target: MojoTargetTypeRef;
}

interface Row {
  readonly method: "write" | "end";
  readonly suffix: string;
  readonly target: string;
  readonly arguments: readonly Argument[];
}

const bufferType = providerRef("node:buffer", "Buffer");
const chunkType: ProviderTypeExpression = { kind: "union", types: [bufferType, stringType] };
const chunkCarrier = mojoUnionTargetType([bufferCarrier, nativeString]);
const completionError: ProviderTypeExpression = {
  kind: "union", types: [{ kind: "source-global", name: "Error" }, undefinedType],
};
const completionCarrier = mojoCallableTargetType([
  { convention: "imm", passing: "plain", type: mojoOptionalTargetType(mojoSourceErrorType()) },
], unitCarrier, true);
const encoding: Argument = {
  name: "encoding", source: { kind: "union", types: [stringType, undefinedType] },
  target: optionalStringCarrier,
};

function completion(owner: string, method: string, suffix: string): Argument {
  return {
    name: "callback",
    source: { kind: "union", types: [providerCallbackType(`${owner}.${method}(${suffix})`, "callback", [
      { name: "error", type: completionError },
    ]), undefinedType] },
    target: mojoOptionalTargetType(completionCarrier),
  };
}

function callRows(owner: string): readonly Row[] {
  const rows: Row[] = [
    { method: "end", suffix: "", target: "end", arguments: [] },
    { method: "end", suffix: "callback", target: "end_callback", arguments: [completion(owner, "end", "callback")] },
  ];
  for (const method of ["write", "end"] as const) {
    const inputs = [
      { suffix: "buffer", source: bufferType, target: bufferCarrier },
      { suffix: "string", source: stringType, target: nativeString },
      ...(method === "end" ? [{ suffix: "empty", source: undefinedType, target: unitCarrier }] : []),
      { suffix: "value", source: method === "end"
        ? { kind: "union" as const, types: [chunkType, undefinedType] }
        : chunkType,
      target: method === "end" ? mojoOptionalTargetType(chunkCarrier) : chunkCarrier },
    ];
    for (const input of inputs) {
      const chunk: Argument = { name: "chunk", source: input.source, target: input.target };
      const callbackSuffix = `${input.suffix},callback`;
      const encodedSuffix = `${input.suffix},encoding`;
      const completeSuffix = `${encodedSuffix},callback`;
      rows.push(
        { method, suffix: input.suffix, target: `${method}_${input.suffix}`, arguments: [chunk] },
        { method, suffix: callbackSuffix, target: `${method}_${input.suffix}_callback`,
          arguments: [chunk, completion(owner, method, callbackSuffix)] },
        { method, suffix: encodedSuffix, target: `${method}_${input.suffix}_encoded`, arguments: [chunk, encoding] },
        { method, suffix: completeSuffix, target: `${method}_${input.suffix}_encoded`,
          arguments: [chunk, encoding, completion(owner, method, completeSuffix)] },
      );
    }
  }
  return rows;
}

export function writableCallMembers(owner: string, result: ProviderTypeExpression) {
  const rows = callRows(owner);
  return ["write", "end"].map((method) => overloadedMethodMember(owner, method,
    rows.filter((row) => row.method === method).map((row) => ({
      signatureSuffix: row.suffix,
      parameters: row.arguments.map((argument) => ({ name: argument.name, type: argument.source })),
      returnType: method === "write" ? booleanType : result,
    }))));
}

export function writableCallOperations(owner: string, receiver: MojoTargetTypeRef) {
  return callRows(owner).map((row) => instanceCall(owner, `${owner}.${row.method}`,
    `${owner}.${row.method}(${row.suffix})`, row.target, receiver,
    row.arguments.map((argument) => argument.target), row.method === "write" ? boolCarrier : receiver,
    true, "mut"));
}
