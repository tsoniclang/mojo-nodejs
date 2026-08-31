import type {
  MojoProviderModuleDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import { bufferCarrier } from "../model.js";

const moduleSpecifier = "node:buffer";
const bufferId = `${moduleSpecifier}::Buffer`;

export function bufferModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.buffer",
    exports: Object.freeze([Object.freeze({
      id: bufferId,
      name: "Buffer",
      kind: "class",
      members: Object.freeze([]),
    })]),
  });
}

export function bufferTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([Object.freeze({
    exportId: bufferId,
    sourceGenericParameters: Object.freeze([]),
    targetType: bufferCarrier,
  })]);
}
