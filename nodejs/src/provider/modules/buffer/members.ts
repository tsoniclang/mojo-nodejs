import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  float64Carrier,
  instanceCall,
  nativeString,
  numberArrayType,
  numberType,
  overloadedMethodMember,
  providerRef,
  staticCall,
  stringType,
  variadicFunctionCall,
} from "../../model.js";

const bufferId = "node:buffer::Buffer";
const bufferType = providerRef("node:buffer", "Buffer");
type Export = MojoProviderModuleDefinition["exports"][number];
type Member = NonNullable<Export["members"]>[number];
type Parameter = NonNullable<Member["signatures"]>[number]["parameters"][number];

interface ValueType {
  readonly source: Parameter["type"];
  readonly target: MojoTargetTypeRef;
}

interface Argument extends ValueType {
  readonly name: string;
}

interface Signature {
  readonly id: string;
  readonly targetName: string;
  readonly parameters: readonly Argument[];
  readonly raises?: boolean;
}

interface Method {
  readonly name: string;
  readonly static?: boolean;
  readonly result: ValueType;
  readonly signatures: readonly Signature[];
}

const number = { source: numberType, target: float64Carrier };
const string = { source: stringType, target: nativeString };
const buffer = { source: bufferType, target: bufferCarrier };
const boolean = { source: booleanType, target: boolCarrier };

function argument(name: string, type: ValueType): Argument {
  return { name, ...type };
}

function prefixes(
  targetName: string,
  parameters: readonly Argument[],
  minimum: number,
  raises = true,
  suffix = "",
): readonly Signature[] {
  return Array.from({ length: parameters.length - minimum + 1 }, (_, index) => {
    const selected = parameters.slice(0, minimum + index);
    return {
      id: `${suffix}${selected.map((parameter) => parameter.name).join(",")}`,
      targetName,
      parameters: selected,
      raises,
    };
  });
}

const searchMethods: readonly Method[] = ([
  ["indexOf", "find", number],
  ["lastIndexOf", "last", number],
  ["includes", "includes", boolean],
] as const).map(([name, target, result]) => ({
  name,
  result,
  signatures: [
    ...([
      ["buffer", buffer, false],
      ["string", string, true],
      ["number", number, false],
    ] as const).flatMap(([kind, type, raises]) => prefixes(
      `${target}_${kind}`,
      [argument("value", type), argument("byteOffset", number), argument("encoding", string)],
      1,
      raises,
      `${kind}:`,
    )),
    {
      id: "string:value,encoding",
      targetName: `${target}_encoded`,
      parameters: [argument("value", string), argument("encoding", string)],
      raises: true,
    },
  ],
}));

const methods: readonly Method[] = [
  ...searchMethods,
  {
    name: "write",
    result: number,
    signatures: [
      ...prefixes("write", [argument("value", string), argument("offset", number), argument("length", number), argument("encoding", string)], 1),
      { id: "value,encoding", targetName: "write_encoded", parameters: [argument("value", string), argument("encoding", string)], raises: true },
      { id: "value,offset,encoding", targetName: "write_offset_encoded", parameters: [argument("value", string), argument("offset", number), argument("encoding", string)], raises: true },
    ],
  },
  {
    name: "fill",
    result: buffer,
    signatures: [
      ...([ ["number", number], ["buffer", buffer], ["string", string] ] as const).flatMap(([kind, type]) => prefixes(
        `fill_${kind}`,
        [argument("value", type), argument("offset", number), argument("end", number), ...(kind === "string" ? [argument("encoding", string)] : [])],
        1,
        true,
        `${kind}:`,
      )),
      { id: "string:value,encoding", targetName: "fill_encoded", parameters: [argument("value", string), argument("encoding", string)], raises: true },
      { id: "string:value,offset,encoding", targetName: "fill_offset_encoded", parameters: [argument("value", string), argument("offset", number), argument("encoding", string)], raises: true },
    ],
  },
  {
    name: "alloc",
    static: true,
    result: buffer,
    signatures: [
      { id: "size", targetName: "buffer_alloc", parameters: [argument("size", number)], raises: true },
      ...([ ["number", number], ["buffer", buffer], ["string", string] ] as const).flatMap(([kind, type]) => prefixes(
        `buffer_alloc_${kind}`,
        [argument("size", number), argument("fill", type), ...(kind === "string" ? [argument("encoding", string)] : [])],
        2,
        true,
        `${kind}:`,
      )),
    ],
  },
  ...["allocUnsafe", "allocUnsafeSlow"].map((name) => ({
    name, static: true, result: buffer,
    signatures: [{ id: "size", targetName: "buffer_alloc", parameters: [argument("size", number)], raises: true }],
  })),
  {
    name: "compare", static: true, result: number,
    signatures: [{ id: "left,right", targetName: "buffer_compare", parameters: [argument("left", buffer), argument("right", buffer)] }],
  },
  {
    name: "isEncoding", static: true, result: boolean,
    signatures: [{ id: "encoding", targetName: "buffer_is_encoding", parameters: [argument("encoding", string)] }],
  },
];

export function extraBufferMembers(): readonly Member[] {
  return Object.freeze([
    ...methods.map((method): Member => {
      const memberId = methodIdentity(method);
      return Object.freeze({
        id: memberId,
        name: method.name,
        kind: "method",
        ...(method.static ? { static: true } : {}),
        signatures: Object.freeze(method.signatures.map((signature) => Object.freeze({
          id: `${memberId}(${signature.id})`,
          name: method.name,
          parameters: Object.freeze(signature.parameters.map((parameter) => Object.freeze({ name: parameter.name, type: parameter.source }))),
          returnType: method.result.source,
        }))),
      });
    }),
    overloadedMethodMember(bufferId, "of", [{ parameters: [{ name: "items", type: numberArrayType, rest: true }], returnType: bufferType }], { static: true }),
  ]);
}

export function extraBufferOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...methods.flatMap((method) => method.signatures.map((signature) => {
      const memberId = methodIdentity(method);
      const signatureId = `${memberId}(${signature.id})`;
      const parameterTypes = signature.parameters.map((parameter) => parameter.target);
      return method.static
        ? staticCall(bufferId, memberId, signatureId, "buffer", signature.targetName, parameterTypes, method.result.target, signature.raises)
        : instanceCall(bufferId, memberId, signatureId, signature.targetName, bufferCarrier, parameterTypes, method.result.target, signature.raises);
    })),
    Object.freeze({
      ...variadicFunctionCall(bufferId, `${bufferId}.of(items)`, "buffer", "buffer_from_numbers", float64Carrier, bufferCarrier),
      memberId: `${bufferId}.of`,
    }),
  ]);
}

function methodIdentity(method: Method): string {
  return `${bufferId}.${method.name}${method.static ? "#static" : ""}`;
}
