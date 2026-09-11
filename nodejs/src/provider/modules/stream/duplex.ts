import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition } from "@tsonic/target-mojo/provider";
import { mojoNamedTargetType, mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import { booleanType, boolCarrier, bufferCarrier, instanceCall, nativeString, nodeProviderType, overloadedMethodMember, providerRef, stringType, nullType, undefinedType } from "../../model.js";

const owner = "node:stream::Duplex";
const source = providerRef("node:stream", "Duplex");
const buffer = providerRef("node:buffer", "Buffer");
export const duplexCarrier = mojoNamedTargetType("tsonic.mojo.node.stream.Duplex", ["tsonic_node", "stream"], "Duplex");
const inputs = [
  { suffix: "buffer", source: buffer, carrier: bufferCarrier },
  { suffix: "string", source: stringType, carrier: nativeString },
];

export const duplexExport: MojoProviderModuleDefinition["exports"][number] = Object.freeze({
  id: owner, name: "Duplex", kind: "interface",
  members: [
    overloadedMethodMember(owner, "write", inputs.map((input) => ({ signatureSuffix: input.suffix, parameters: [{ name: "chunk", type: input.source }], returnType: booleanType }))),
    overloadedMethodMember(owner, "end", [
      { signatureSuffix: "", parameters: [], returnType: source },
      ...inputs.map((input) => ({ signatureSuffix: input.suffix, parameters: [{ name: "chunk", type: input.source }], returnType: source })),
    ]),
    overloadedMethodMember(owner, "read", [{ signatureSuffix: "", parameters: [], returnType: { kind: "union", types: [buffer, nullType, undefinedType] } }]),
  ],
});
export const duplexType = nodeProviderType(owner, duplexCarrier, "implicitly-copyable");
export const duplexOperations: readonly MojoProviderOperationDefinition[] = [
  ...inputs.map((input) => instanceCall(owner, `${owner}.write`, `${owner}.write(${input.suffix})`, `write_${input.suffix}`, duplexCarrier, [input.carrier], boolCarrier, true)),
  instanceCall(owner, `${owner}.read`, `${owner}.read()`, "read", duplexCarrier, [], mojoOptionalTargetType(bufferCarrier), true),
  instanceCall(owner, `${owner}.end`, `${owner}.end()`, "end", duplexCarrier, [], duplexCarrier, true),
  ...inputs.map((input) => instanceCall(owner, `${owner}.end`, `${owner}.end(${input.suffix})`, `end_${input.suffix}`, duplexCarrier, [input.carrier], duplexCarrier, true)),
];

export function withDuplexView(type: MojoProviderTypeDefinition, module: string): MojoProviderTypeDefinition {
  return Object.freeze({ ...type, nativeViews: Object.freeze([{ targetType: duplexCarrier, factory: Object.freeze({ modulePath: Object.freeze(["tsonic_node", module, "duplex"]), name: "as_duplex" }) }]) });
}
