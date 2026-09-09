import type { NodeProviderCopySemantics, NodeProviderSourceGenericParameter } from "./types.js";
import type { MojoProviderTypeDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { mojoLifecycleTraitTargetType } from "@tsonic/target-mojo/provider";

const providerLifecycleRoles: Readonly<Record<
  NodeProviderCopySemantics,
  readonly ("copyable" | "implicitly-copyable" | "movable" | "deinitializable")[]
>> = Object.freeze({
  copyable: Object.freeze(["copyable", "movable", "deinitializable"] as const),
  "implicitly-copyable": Object.freeze([
    "implicitly-copyable",
    "movable",
    "deinitializable",
  ] as const),
});

export function nodeProviderType(
  exportId: string,
  targetType: MojoTargetTypeRef,
  copySemantics: NodeProviderCopySemantics,
  options: {
    readonly sourceGenericParameters?: readonly NodeProviderSourceGenericParameter[];
    readonly objectLiteralConstruction?: boolean;
  } = {},
): MojoProviderTypeDefinition {
  return Object.freeze({
    exportId,
    sourceGenericParameters: Object.freeze([...(options.sourceGenericParameters ?? [])]),
    targetType,
    conformances: Object.freeze(providerLifecycleRoles[copySemantics].map((lifecycleRole) =>
      Object.freeze({
        trait: mojoLifecycleTraitTargetType(lifecycleRole),
        lifecycleRole,
      }))),
    ...(options.objectLiteralConstruction === true
      ? { objectLiteralConstruction: Object.freeze({ kind: "struct-default" as const }) }
      : {}),
  });
}
