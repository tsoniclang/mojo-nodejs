import type { MojoProviderModuleDefinition, MojoProviderTypeDefinition } from "@tsonic/target-mojo/provider";

export type ProviderExportDeclaration = MojoProviderModuleDefinition["exports"][number];

export type ProviderSignatureDeclaration = NonNullable<ProviderExportDeclaration["signatures"]>[number];

export type ProviderParameterDeclaration = ProviderSignatureDeclaration["parameters"][number];

export type ProviderTypeExpression = ProviderParameterDeclaration["type"];

export type ProviderMemberDeclaration = NonNullable<ProviderExportDeclaration["members"]>[number];

export type NodeProviderCopySemantics = "copyable" | "implicitly-copyable";

export type NodeProviderSourceGenericParameter = MojoProviderTypeDefinition["sourceGenericParameters"][number];
