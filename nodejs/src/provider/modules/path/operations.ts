import type { MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  boolCarrier, booleanType, functionCall, instanceCall, nativeString,
  overloadedFunctionExport, overloadedMethodMember, providerRef, stringArrayType, stringType,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";
import { dialectId, dialectCarrier, inputCarrier, parsedCarrier } from "./records.js";

interface Parameter {
  readonly name: string;
  readonly source: ProviderTypeExpression;
  readonly carrier: MojoTargetTypeRef;
  readonly rest?: boolean;
}
interface Operation {
  readonly name: string;
  readonly target: string;
  readonly suffix?: string;
  readonly parameters: readonly Parameter[];
  readonly sourceResult: ProviderTypeExpression;
  readonly result: MojoTargetTypeRef;
  readonly raises?: boolean;
}

const path: Parameter = { name: "path", source: stringType, carrier: nativeString };
const paths: Parameter = { name: "paths", source: stringArrayType, carrier: nativeString, rest: true };
const operations: readonly Operation[] = [
  { name: "parse", target: "parse", parameters: [path], sourceResult: providerRef("node:path", "ParsedPath"), result: parsedCarrier },
  { name: "format", target: "format_path", suffix: "parsed", parameters: [{ name: "pathObject", source: providerRef("node:path", "ParsedPath"), carrier: parsedCarrier }], sourceResult: stringType, result: nativeString },
  { name: "format", target: "format_path", suffix: "input", parameters: [{ name: "pathObject", source: providerRef("node:path", "FormatInputPathObject"), carrier: inputCarrier }], sourceResult: stringType, result: nativeString },
  { name: "join", target: "join", parameters: [paths], sourceResult: stringType, result: nativeString },
  { name: "resolve", target: "resolve", parameters: [paths], sourceResult: stringType, result: nativeString, raises: true },
  { name: "normalize", target: "normalize", parameters: [path], sourceResult: stringType, result: nativeString },
  { name: "isAbsolute", target: "is_absolute", parameters: [path], sourceResult: booleanType, result: boolCarrier },
  { name: "dirname", target: "dirname", parameters: [path], sourceResult: stringType, result: nativeString },
  { name: "extname", target: "extname", parameters: [path], sourceResult: stringType, result: nativeString },
  { name: "basename", target: "basename", parameters: [path], sourceResult: stringType, result: nativeString },
  { name: "basename", target: "basename", parameters: [path, { ...path, name: "suffix" }], sourceResult: stringType, result: nativeString },
  { name: "relative", target: "relative", parameters: [{ ...path, name: "from" }, { ...path, name: "to" }], sourceResult: stringType, result: nativeString, raises: true },
  { name: "toNamespacedPath", target: "to_namespaced_path", parameters: [path], sourceResult: stringType, result: nativeString, raises: true },
];

function overload(operation: Operation) {
  return {
    signatureSuffix: operation.suffix ?? operation.parameters.map((parameter) => parameter.name).join(","),
    parameters: operation.parameters.map((parameter) => ({ name: parameter.name, type: parameter.source, ...(parameter.rest ? { rest: true } : {}) })),
    returnType: operation.sourceResult,
  };
}

export function pathFunctionDeclarations() {
  return [...new Set(operations.map((operation) => operation.name))].map((name) =>
    overloadedFunctionExport("node:path", name, operations.filter((operation) => operation.name === name).map(overload)));
}

export function pathDialectMembers() {
  return [...new Set(operations.map((operation) => operation.name))].map((name) =>
    overloadedMethodMember(dialectId, name, operations.filter((operation) => operation.name === name).map(overload)));
}

export function pathCallOperations(dialect: boolean): readonly MojoProviderOperationDefinition[] {
  return operations.map((operation) => {
    const identity = overload(operation);
    const id = dialect ? `${dialectId}.${operation.name}` : `node:path::${operation.name}`;
    const parameters = operation.parameters.map((parameter) => parameter.carrier);
    const selected = dialect
      ? instanceCall(dialectId, id, `${id}(${identity.signatureSuffix})`, operation.target, dialectCarrier, parameters, operation.result, operation.raises)
      : functionCall(id, `${id}(${identity.signatureSuffix})`, "path", operation.target, parameters, operation.result, operation.raises);
    if (selected.target.kind !== "function-call" && selected.target.kind !== "instance-call") {
      throw new Error("Path operation producer requires a native call target.");
    }
    return Object.freeze({ ...selected, target: Object.freeze({ ...selected.target, arguments: Object.freeze(
      selected.target.arguments.map((argument, index) => Object.freeze({ ...argument,
        ...(operation.parameters[index]?.rest ? { variadic: true as const, restPacking: "list" as const } : {}),
      })),
    ) }) });
  });
}
