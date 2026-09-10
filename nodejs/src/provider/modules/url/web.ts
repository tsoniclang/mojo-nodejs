import type {
  MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoNamedTargetType, mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, constructorMember, float64Carrier, fnExport, functionCall, instanceCall,
  methodMember, nativeString, nodeProviderType, numberType, optionalStringCarrier,
  overloadedFunctionExport, overloadedMethodMember, propertyMember, propertyRead,
  propertyWrite, providerRef, staticCall, stringArrayType, stringListCarrier,
  stringType, unitCarrier, voidType,
} from "../../model.js";

const moduleSpecifier = "node:url";
const urlId = `${moduleSpecifier}::URL`;
const paramsId = `${moduleSpecifier}::URLSearchParams`;
const urlType = providerRef(moduleSpecifier, "URL");
const paramsType = providerRef(moduleSpecifier, "URLSearchParams");
const urlCarrier = mojoNamedTargetType("tsonic.mojo.node.URL", ["tsonic_node", "url"], "URL");
const paramsCarrier = mojoNamedTargetType("tsonic.mojo.node.URLSearchParams", ["tsonic_node", "url"], "URLSearchParams");
const nullableString = Object.freeze({ kind: "union" as const, types: Object.freeze([
  stringType, Object.freeze({ kind: "literal" as const, value: null }),
]) });
const nullableUrl = Object.freeze({ kind: "union" as const, types: Object.freeze([
  urlType, Object.freeze({ kind: "literal" as const, value: null }),
]) });
const fields = Object.freeze([
  "href", "protocol", "username", "password", "host", "hostname", "port", "pathname", "search", "hash",
]);
const constructors = Object.freeze([
  { suffix: "input", parameters: [{ name: "input", type: stringType }], carriers: [nativeString] },
  { suffix: "input,baseString", parameters: [{ name: "input", type: stringType }, { name: "base", type: stringType }], carriers: [nativeString, nativeString] },
  { suffix: "input,baseURL", parameters: [{ name: "input", type: stringType }, { name: "base", type: urlType }], carriers: [nativeString, urlCarrier] },
]);
const paramInitializers = Object.freeze([
  { suffix: "", parameters: [], carriers: [] },
  { suffix: "input", parameters: [{ name: "input", type: stringType }], carriers: [nativeString] },
]);
const namedValue = Object.freeze([{ name: "name", type: stringType }, { name: "value", type: stringType }]);

export function webUrlExports(): MojoProviderModuleDefinition["exports"] {
  return Object.freeze([
    Object.freeze({
      id: urlId, name: "URL", kind: "class" as const,
      members: Object.freeze([
        constructor(urlId, constructors),
        ...fields.map((name) => propertyMember(urlId, name, stringType, { readonly: false })),
        propertyMember(urlId, "origin", stringType),
        propertyMember(urlId, "searchParams", paramsType),
        methodMember(urlId, "toString", [], stringType),
        methodMember(urlId, "toJSON", [], stringType),
        ...["canParse", "parse"].map((name) => overloadedMethodMember(urlId, name,
          constructors.map((row) => ({
            signatureSuffix: row.suffix, parameters: row.parameters,
            returnType: name === "canParse" ? booleanType : nullableUrl,
          })), { static: true })),
      ]),
    }),
    Object.freeze({
      id: paramsId, name: "URLSearchParams", kind: "class" as const,
      members: Object.freeze([
        constructor(paramsId, paramInitializers),
        propertyMember(paramsId, "size", numberType),
        methodMember(paramsId, "get", [{ name: "name", type: stringType }], nullableString),
        methodMember(paramsId, "getAll", [{ name: "name", type: stringType }], stringArrayType),
        ...["set", "append"].map((name) => methodMember(paramsId, name, namedValue, voidType)),
        ...["has", "delete"].map((name) => overloadedMethodMember(paramsId, name, [
          { parameters: [namedValue[0]!], returnType: name === "has" ? booleanType : voidType },
          { parameters: namedValue, returnType: name === "has" ? booleanType : voidType },
        ])),
        methodMember(paramsId, "sort", [], voidType),
        methodMember(paramsId, "toString", [], stringType),
      ]),
    }),
    fnExport(moduleSpecifier, "pathToFileURL", [{ name: "path", type: stringType }], urlType),
    ...["domainToASCII", "domainToUnicode"].map((name) => fnExport(moduleSpecifier, name, [{ name: "domain", type: stringType }], stringType)),
    overloadedFunctionExport(moduleSpecifier, "fileURLToPathBuffer", [
      { signatureSuffix: "url", parameters: [{ name: "url", type: urlType }], returnType: providerRef("node:buffer", "Buffer") },
      { signatureSuffix: "input", parameters: [{ name: "input", type: stringType }], returnType: providerRef("node:buffer", "Buffer") },
    ]),
    overloadedFunctionExport(moduleSpecifier, "fileURLToPath", [
      { signatureSuffix: "url", parameters: [{ name: "url", type: urlType }], returnType: stringType },
      { signatureSuffix: "input", parameters: [{ name: "input", type: stringType }], returnType: stringType },
    ]),
    overloadedFunctionExport(moduleSpecifier, "canParse", constructors.map((row) => ({
      signatureSuffix: row.suffix, parameters: row.parameters, returnType: booleanType,
    }))),
  ]);
}

export function webUrlTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(urlId, urlCarrier, "implicitly-copyable"),
    nodeProviderType(paramsId, paramsCarrier, "implicitly-copyable"),
  ]);
}

export function webUrlOperations(): readonly MojoProviderOperationDefinition[] {
  const operations: MojoProviderOperationDefinition[] = [
    ...constructors.map((row) => constructOperation(urlId, row.suffix, "url_new", row.carriers, urlCarrier)),
    ...paramInitializers.map((row) => constructOperation(paramsId, row.suffix, "search_params_new", row.carriers, paramsCarrier)),
    ...fields.flatMap((name) => [
      Object.freeze({ ...propertyRead(urlId, `${urlId}.${name}`, name, urlCarrier, nativeString, "method"), raises: true }),
      Object.freeze({ ...propertyWrite(urlId, `${urlId}.${name}`, `set_${name}`, urlCarrier, nativeString, "method"), raises: true }),
    ]),
    Object.freeze({ ...propertyRead(urlId, `${urlId}.origin`, "origin", urlCarrier, nativeString, "method"), raises: true }),
    propertyRead(urlId, `${urlId}.searchParams`, "search_params", urlCarrier, paramsCarrier, "method"),
    propertyRead(paramsId, `${paramsId}.size`, "size", paramsCarrier, float64Carrier, "method"),
    ...["toString", "toJSON"].map((name) => instanceCall(urlId, `${urlId}.${name}`, `${urlId}.${name}()`, "to_string", urlCarrier, [], nativeString, true)),
    ...constructors.flatMap((row) => [
      staticCall(urlId, `${urlId}.canParse`, `${urlId}.canParse(${row.suffix})`, "url", "can_parse", row.carriers, boolCarrier, true),
      staticCall(urlId, `${urlId}.parse`, `${urlId}.parse(${row.suffix})`, "url", "url_parse", row.carriers, mojoOptionalTargetType(urlCarrier), true),
      functionCall(`${moduleSpecifier}::canParse`, `${moduleSpecifier}::canParse(${row.suffix})`, "url", "can_parse", row.carriers, boolCarrier, true),
    ]),
    functionCall(`${moduleSpecifier}::pathToFileURL`, `${moduleSpecifier}::pathToFileURL(path)`, "url", "path_to_file_url", [nativeString], urlCarrier, true),
    functionCall(`${moduleSpecifier}::format`, `${moduleSpecifier}::format(URL)`, "url", "format_url", [urlCarrier], nativeString, true),
    functionCall(`${moduleSpecifier}::domainToASCII`, `${moduleSpecifier}::domainToASCII(domain)`, "url", "domain_to_ascii", [nativeString], nativeString, true),
    functionCall(`${moduleSpecifier}::domainToUnicode`, `${moduleSpecifier}::domainToUnicode(domain)`, "url", "domain_to_unicode", [nativeString], nativeString, true),
    functionCall(`${moduleSpecifier}::fileURLToPathBuffer`, `${moduleSpecifier}::fileURLToPathBuffer(url)`, "url", "file_url_to_path_buffer", [urlCarrier], bufferCarrier, true),
    functionCall(`${moduleSpecifier}::fileURLToPathBuffer`, `${moduleSpecifier}::fileURLToPathBuffer(input)`, "url", "file_url_to_path_buffer", [nativeString], bufferCarrier, true),
    functionCall(`${moduleSpecifier}::fileURLToPath`, `${moduleSpecifier}::fileURLToPath(url)`, "url", "file_url_to_path", [urlCarrier], nativeString, true),
    functionCall(`${moduleSpecifier}::fileURLToPath`, `${moduleSpecifier}::fileURLToPath(input)`, "url", "file_url_to_path", [nativeString], nativeString, true),
    instanceCall(paramsId, `${paramsId}.get`, `${paramsId}.get(name)`, "get", paramsCarrier, [nativeString], optionalStringCarrier),
    instanceCall(paramsId, `${paramsId}.getAll`, `${paramsId}.getAll(name)`, "get_all", paramsCarrier, [nativeString], stringListCarrier),
    instanceCall(paramsId, `${paramsId}.sort`, `${paramsId}.sort()`, "sort", paramsCarrier, [], unitCarrier, true),
    instanceCall(paramsId, `${paramsId}.toString`, `${paramsId}.toString()`, "to_string", paramsCarrier, [], nativeString, true),
  ];
  for (const name of ["append", "set", "has", "delete"]) {
    const arities = name === "has" || name === "delete" ? [1, 2] : [2];
    for (const arity of arities) {
      const suffix = arity === 1 ? "name" : "name,value";
      operations.push(instanceCall(paramsId, `${paramsId}.${name}`, `${paramsId}.${name}(${suffix})`,
        name, paramsCarrier, arity === 1 ? [nativeString] : [nativeString, nativeString],
        name === "has" ? boolCarrier : unitCarrier, name !== "has"));
    }
  }
  return Object.freeze(operations);
}

function constructor(
  id: string,
  rows: readonly { readonly suffix: string; readonly parameters: readonly { readonly name: string; readonly type: typeof stringType | typeof urlType }[] }[],
): ReturnType<typeof constructorMember> {
  return Object.freeze({
    id: `${id}.constructor`, name: "constructor", kind: "constructor",
    signatures: Object.freeze(rows.map((row) => Object.freeze({
      id: `${id}.constructor(${row.suffix})`, name: "constructor",
      parameters: Object.freeze(row.parameters), returnType: voidType,
    }))),
  });
}

function constructOperation(id: string, suffix: string, name: string,
  parameters: readonly MojoTargetTypeRef[], result: MojoTargetTypeRef): MojoProviderOperationDefinition {
  return Object.freeze({
    ...functionCall(id, `${id}.constructor(${suffix})`, "url", name, parameters, result, true),
    memberId: `${id}.constructor`, operationKind: "constructor",
  });
}
