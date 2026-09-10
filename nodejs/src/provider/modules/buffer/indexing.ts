import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import type { MojoProviderOperationDefinition } from "@tsonic/target-mojo/provider";
import { bufferCarrier, float64Carrier, numberType, undefinedType, unitCarrier } from "../../model.js";
import { indexRead } from "../../model/operations/properties.js";
import type { ProviderMemberDeclaration } from "../../model/types.js";

const exportId = "node:buffer::Buffer";
const memberId = `${exportId}.indexer`;
const signatureId = `${memberId}(index)`;
const byteType = Object.freeze({ kind: "union" as const, types: Object.freeze([numberType, undefinedType]) });
const byteCarrier = mojoOptionalTargetType(float64Carrier);

export function bufferIndexMember(): ProviderMemberDeclaration {
  return Object.freeze({
    id: memberId, name: "indexer", kind: "indexer",
    signatures: Object.freeze([Object.freeze({
      id: signatureId, name: "indexer",
      parameters: Object.freeze([{ name: "index", type: numberType }]),
      returnType: byteType,
    })]),
  });
}

export function bufferIndexOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    indexRead(exportId, memberId, signatureId, "get_index", bufferCarrier, float64Carrier, byteCarrier),
    Object.freeze({
      exportId, memberId, signatureId, operationKind: "index-set",
      target: Object.freeze({
        kind: "index-write", access: Object.freeze({ kind: "method", name: "set_index" }), receiver: "mut",
        index: Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
        value: Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
      }),
      receiverType: bufferCarrier,
      parameterTypes: Object.freeze([float64Carrier, byteCarrier]), resultType: unitCarrier,
    }),
  ]);
}
