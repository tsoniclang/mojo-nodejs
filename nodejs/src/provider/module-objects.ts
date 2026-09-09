import type { createMojoProviderPackage, MojoProviderModuleDefinition, MojoProviderOperationDefinition } from "@tsonic/target-mojo/provider";

type PackageDefinition = Parameters<typeof createMojoProviderPackage>[0];
type Member = NonNullable<MojoProviderModuleDefinition["exports"][number]["members"]>[number];

const moduleObjects = Object.freeze([
  ["node:buffer", "NodeBufferModule"],
  ["node:crypto", "NodeCryptoModule"],
  ["node:fs", "NodeFsModule"],
  ["node:fs/promises", "NodeFsPromisesModule"],
  ["node:http", "NodeHttpModule"],
  ["node:os", "NodeOsModule"],
  ["node:path", "NodePathModule"],
  ["node:timers", "NodeTimersModule"],
  ["node:url", "NodeUrlModule"],
  ["node:util", "NodeUtilModule"],
] as const);

export function withNodeModuleObjects(definition: PackageDefinition): PackageDefinition {
  const additions: MojoProviderOperationDefinition[] = [];
  const modules = definition.modules.map((module) => {
    const metadata = moduleObjects.find(([specifier]) => specifier === module.moduleSpecifier);
    if (metadata === undefined) return module;
    if (module.exports.some((entry) => entry.exportKind === "default")) {
      throw new Error(`Duplicate default-module producer for '${module.moduleSpecifier}'.`);
    }
    const exportId = `${module.moduleSpecifier}.default`;
    const members: Member[] = [];
    for (const declaration of module.exports) {
      if (declaration.kind !== "function" && declaration.kind !== "value") continue;
      const memberId = `${exportId}#${declaration.id}`;
      const signatureIds = new Map((declaration.signatures ?? []).map((signature) => [signature.id, `${memberId}#${signature.id}`]));
      const member = declaration.kind === "function"
        ? Object.freeze({ id: memberId, name: declaration.exportName ?? declaration.name, kind: "method" as const, static: true as const, signatures: Object.freeze((declaration.signatures ?? []).map((signature) => Object.freeze({ ...signature, id: signatureIds.get(signature.id)! }))) })
        : Object.freeze({ id: memberId, name: declaration.exportName ?? declaration.name, kind: "property" as const, static: true as const, readonly: true as const, type: declaration.type });
      members.push(member);
      for (const operation of definition.operations) {
        if (operation.exportId !== declaration.id || operation.memberId !== undefined) continue;
        additions.push(Object.freeze({
          ...operation,
          exportId,
          memberId,
          ...(operation.signatureId === undefined ? {} : { signatureId: signatureIds.get(operation.signatureId)! }),
          operationKind: declaration.kind === "value" ? "property" : operation.operationKind,
        }));
      }
    }
    return Object.freeze({
      ...module,
      exports: Object.freeze([...module.exports, Object.freeze({
        id: exportId, name: metadata[1], kind: "class" as const,
        exportKind: "default" as const, members: Object.freeze(members),
      })]),
    });
  });
  return Object.freeze({ ...definition, modules: Object.freeze(modules), operations: Object.freeze([...definition.operations, ...additions]) });
}
