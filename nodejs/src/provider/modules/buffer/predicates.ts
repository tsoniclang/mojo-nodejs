import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import type { ProviderMemberDeclaration } from "../../model/types.js";
import { booleanType, boolCarrier, targetTypeParameter, typeParameter } from "../../model.js";

const bufferId = "node:buffer::Buffer";
const memberId = `${bufferId}.isBuffer#static`;
const functionId = "node:buffer::isBuffer";

function signature(id: string) {
  return Object.freeze({
    id: `${id}(value)`,
    name: "isBuffer",
    typeParameters: Object.freeze([Object.freeze({ name: "T" })]),
    parameters: Object.freeze([Object.freeze({ name: "value", type: typeParameter("T") })]),
    returnType: booleanType,
  });
}

export function bufferPredicateMember(): ProviderMemberDeclaration {
  return Object.freeze({
    id: memberId,
    name: "isBuffer",
    kind: "method",
    static: true,
    signatures: Object.freeze([signature(memberId)]),
  });
}

export function bufferPredicateExport(): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({
    id: functionId,
    name: "isBuffer",
    kind: "function",
    signatures: Object.freeze([signature(functionId)]),
  });
}

export function bufferPredicateOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([false, true].map((staticMember): MojoProviderOperationDefinition =>
    Object.freeze({
      exportId: staticMember ? bufferId : functionId,
      ...(staticMember ? { memberId } : {}),
      signatureId: signature(staticMember ? memberId : functionId).id,
      operationKind: "call",
      target: Object.freeze({
        kind: "function-call",
        modulePath: Object.freeze(["tsonic_node", "buffer"]),
        name: "buffer_is_buffer",
        genericParameters: Object.freeze([Object.freeze({
          kind: "type",
          name: "T",
          position: "inferred",
          variadic: false,
          constraints: Object.freeze([]),
        })]),
        arguments: Object.freeze([Object.freeze({
          convention: "imm",
          position: "positional-or-keyword",
        })]),
      }),
      parameterTypes: Object.freeze([targetTypeParameter("T")]),
      resultType: boolCarrier,
    })));
}
