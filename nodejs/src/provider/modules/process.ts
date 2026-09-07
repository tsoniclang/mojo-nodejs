import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  float64Carrier,
  fnExport,
  functionCall,
  functionValue,
  indexRead,
  instanceCall,
  methodMember as providerMethodMember,
  nativeIntCarrier,
  nativeString,
  nodeProviderType,
  numberArrayType,
  numberListCarrier,
  numberType,
  optionalInt32Carrier,
  optionalStringCarrier,
  overloadedFunctionExport,
  overloadedMethodMember,
  processEnvCarrier,
  processMemoryUsageCarrier,
  processWriteStreamCarrier,
  propertyMember,
  propertyRead,
  providerRef,
  staticCall,
  staticPropertyRead,
  staticPropertyWrite,
  stringArrayType,
  stringListCarrier,
  stringType,
  unitCarrier,
  valueExport,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:process";
const defaultId = "node:process.default";
const envId = `${moduleSpecifier}::ProcessEnv`;
const memoryUsageId = `${moduleSpecifier}::MemoryUsage`;
const writeStreamId = `${moduleSpecifier}::ProcessWriteStream`;
const nullableNumberType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([
    numberType,
    Object.freeze({ kind: "literal" as const, value: null }),
  ]),
});

export function processModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.process",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      fnExport(moduleSpecifier, "cwd", [], stringType),
      fnExport(moduleSpecifier, "chdir", [{ name: "directory", type: stringType }], voidType),
      overloadedFunctionExport(moduleSpecifier, "exit", [
        { parameters: [], returnType: voidType, signatureSuffix: "" },
        {
          parameters: [{ name: "code", type: numberType }],
          returnType: voidType,
          signatureSuffix: "code",
        },
      ]),
      overloadedFunctionExport(moduleSpecifier, "hrtime", [
        { parameters: [], returnType: numberArrayType, signatureSuffix: "" },
        {
          parameters: [{ name: "previous", type: numberArrayType }],
          returnType: numberArrayType,
          signatureSuffix: "previous",
        },
      ]),
      fnExport(moduleSpecifier, "memoryUsage", [], providerRef(moduleSpecifier, "MemoryUsage")),
      fnExport(moduleSpecifier, "uptime", [], numberType),
      classExport(envId, "ProcessEnv", [Object.freeze({
        id: `${envId}.indexer`,
        name: "indexer",
        kind: "indexer",
        signatures: Object.freeze([Object.freeze({
          id: `${envId}.indexer(name)`,
          name: "indexer",
          parameters: Object.freeze([{ name: "name", type: stringType }]),
          returnType: Object.freeze({
            kind: "union" as const,
            types: Object.freeze([stringType, Object.freeze({ kind: "undefined" as const })]),
          }),
        })]),
      })]),
      classExport(memoryUsageId, "MemoryUsage", [
        propertyMember(memoryUsageId, "rss", numberType),
        propertyMember(memoryUsageId, "heapTotal", numberType),
        propertyMember(memoryUsageId, "heapUsed", numberType),
        propertyMember(memoryUsageId, "external", numberType),
        propertyMember(memoryUsageId, "arrayBuffers", numberType),
      ]),
      classExport(writeStreamId, "ProcessWriteStream", [
        overloadedMethodMember(writeStreamId, "write", [
          {
            parameters: [{ name: "chunk", type: stringType }],
            returnType: booleanType,
            signatureSuffix: "string",
          },
          {
            parameters: [{ name: "chunk", type: providerRef("node:buffer", "Buffer") }],
            returnType: booleanType,
            signatureSuffix: "buffer",
          },
        ]),
        propertyMember(writeStreamId, "isTTY", booleanType),
        propertyMember(writeStreamId, "fd", numberType),
      ]),
      valueExport(moduleSpecifier, "env", providerRef(moduleSpecifier, "ProcessEnv")),
      valueExport(moduleSpecifier, "stdout", providerRef(moduleSpecifier, "ProcessWriteStream")),
      valueExport(moduleSpecifier, "stderr", providerRef(moduleSpecifier, "ProcessWriteStream")),
      valueExport(moduleSpecifier, "platform", stringType),
      valueExport(moduleSpecifier, "arch", stringType),
      valueExport(moduleSpecifier, "argv", stringArrayType),
      valueExport(moduleSpecifier, "argv0", stringType),
      valueExport(moduleSpecifier, "pid", numberType),
      valueExport(moduleSpecifier, "ppid", numberType),
      valueExport(moduleSpecifier, "execPath", stringType),
      valueExport(moduleSpecifier, "exitCode", nullableNumberType),
      defaultProcessExport(),
    ]),
  });
}

export function processTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(envId, processEnvCarrier, "copyable"),
    nodeProviderType(memoryUsageId, processMemoryUsageCarrier, "copyable"),
    nodeProviderType(writeStreamId, processWriteStreamCarrier, "copyable"),
  ]);
}

export function processOperations(): readonly MojoProviderOperationDefinition[] {
  const operations: MojoProviderOperationDefinition[] = [
    functionCall(`${moduleSpecifier}::cwd`, `${moduleSpecifier}::cwd()`, "process", "current_directory", [], nativeString, true),
    functionCall(`${moduleSpecifier}::chdir`, `${moduleSpecifier}::chdir(directory)`, "process", "change_directory", [nativeString], unitCarrier, true),
    functionCall(`${moduleSpecifier}::exit`, `${moduleSpecifier}::exit()`, "process", "exit_default", [], unitCarrier),
    functionCall(`${moduleSpecifier}::exit`, `${moduleSpecifier}::exit(code)`, "process", "exit", [nativeIntCarrier], unitCarrier),
    functionCall(`${moduleSpecifier}::hrtime`, `${moduleSpecifier}::hrtime()`, "process", "hrtime", [], numberListCarrier),
    functionCall(`${moduleSpecifier}::hrtime`, `${moduleSpecifier}::hrtime(previous)`, "process", "hrtime_since", [numberListCarrier], numberListCarrier, true),
    functionCall(`${moduleSpecifier}::memoryUsage`, `${moduleSpecifier}::memoryUsage()`, "process", "memory_usage", [], processMemoryUsageCarrier),
    functionCall(`${moduleSpecifier}::uptime`, `${moduleSpecifier}::uptime()`, "process", "uptime", [], float64Carrier),
    functionValue(`${moduleSpecifier}::env`, "process", "environment_object", processEnvCarrier),
    functionValue(`${moduleSpecifier}::stdout`, "process", "stdout", processWriteStreamCarrier),
    functionValue(`${moduleSpecifier}::stderr`, "process", "stderr", processWriteStreamCarrier),
    functionValue(`${moduleSpecifier}::platform`, "process", "platform", nativeString),
    functionValue(`${moduleSpecifier}::arch`, "process", "arch", nativeString),
    functionValue(`${moduleSpecifier}::argv`, "process", "arguments", stringListCarrier, true),
    functionValue(`${moduleSpecifier}::argv0`, "process", "argument_zero", nativeString),
    functionValue(`${moduleSpecifier}::pid`, "process", "process_id", nativeIntCarrier),
    functionValue(`${moduleSpecifier}::ppid`, "process", "parent_process_id", nativeIntCarrier),
    functionValue(`${moduleSpecifier}::execPath`, "process", "executable_path", nativeString, true),
    functionValue(`${moduleSpecifier}::exitCode`, "process", "exit_code", optionalInt32Carrier),
    indexRead(
      envId,
      `${envId}.indexer`,
      `${envId}.indexer(name)`,
      "get",
      processEnvCarrier,
      nativeString,
      optionalStringCarrier,
    ),
    ...memoryUsageProperties(),
    instanceCall(writeStreamId, `${writeStreamId}.write`, `${writeStreamId}.write(string)`, "write_string", processWriteStreamCarrier, [nativeString], boolCarrier, true, "mut"),
    instanceCall(writeStreamId, `${writeStreamId}.write`, `${writeStreamId}.write(buffer)`, "write_buffer", processWriteStreamCarrier, [bufferCarrier], boolCarrier, true, "mut"),
    propertyRead(writeStreamId, `${writeStreamId}.isTTY`, "is_tty", processWriteStreamCarrier, boolCarrier, "method"),
    propertyRead(writeStreamId, `${writeStreamId}.fd`, "fd", processWriteStreamCarrier, nativeIntCarrier),
    ...defaultProcessOperations(),
  ];
  return Object.freeze(operations);
}

function defaultProcessExport(): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({
    id: defaultId,
    name: "NodeProcessModule",
    exportKind: "default",
    kind: "class",
    members: Object.freeze([
      providerMethodMember(defaultId, "cwd", [], stringType, { static: true }),
      providerMethodMember(defaultId, "chdir", [{ name: "directory", type: stringType }], voidType, { static: true }),
      overloadedMethodMember(defaultId, "hrtime", [
        { parameters: [], returnType: numberArrayType, signatureSuffix: "" },
        {
          parameters: [{ name: "previous", type: numberArrayType }],
          returnType: numberArrayType,
          signatureSuffix: "previous",
        },
      ], { static: true }),
      providerMethodMember(defaultId, "memoryUsage", [], providerRef(moduleSpecifier, "MemoryUsage"), { static: true }),
      providerMethodMember(defaultId, "uptime", [], numberType, { static: true }),
      overloadedMethodMember(defaultId, "exit", [
        { parameters: [], returnType: voidType, signatureSuffix: "" },
        {
          parameters: [{ name: "code", type: numberType }],
          returnType: voidType,
          signatureSuffix: "code",
        },
      ], { static: true }),
      propertyMember(defaultId, "env", providerRef(moduleSpecifier, "ProcessEnv"), { static: true }),
      propertyMember(defaultId, "stdout", providerRef(moduleSpecifier, "ProcessWriteStream"), { static: true }),
      propertyMember(defaultId, "stderr", providerRef(moduleSpecifier, "ProcessWriteStream"), { static: true }),
      propertyMember(defaultId, "platform", stringType, { static: true }),
      propertyMember(defaultId, "arch", stringType, { static: true }),
      propertyMember(defaultId, "argv", stringArrayType, { static: true }),
      propertyMember(defaultId, "argv0", stringType, { static: true }),
      propertyMember(defaultId, "pid", numberType, { static: true }),
      propertyMember(defaultId, "ppid", numberType, { static: true }),
      propertyMember(defaultId, "execPath", stringType, { static: true }),
      propertyMember(defaultId, "exitCode", nullableNumberType, {
        static: true,
        readonly: false,
      }),
    ]),
  });
}

function defaultProcessOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    staticCall(defaultId, `${defaultId}.cwd`, `${defaultId}.cwd()`, "process", "current_directory", [], nativeString, true),
    staticCall(defaultId, `${defaultId}.chdir`, `${defaultId}.chdir(directory)`, "process", "change_directory", [nativeString], unitCarrier, true),
    staticCall(defaultId, `${defaultId}.hrtime`, `${defaultId}.hrtime()`, "process", "hrtime", [], numberListCarrier),
    staticCall(defaultId, `${defaultId}.hrtime`, `${defaultId}.hrtime(previous)`, "process", "hrtime_since", [numberListCarrier], numberListCarrier, true),
    staticCall(defaultId, `${defaultId}.memoryUsage`, `${defaultId}.memoryUsage()`, "process", "memory_usage", [], processMemoryUsageCarrier),
    staticCall(defaultId, `${defaultId}.uptime`, `${defaultId}.uptime()`, "process", "uptime", [], float64Carrier),
    staticCall(defaultId, `${defaultId}.exit`, `${defaultId}.exit()`, "process", "exit_default", [], unitCarrier),
    staticCall(defaultId, `${defaultId}.exit`, `${defaultId}.exit(code)`, "process", "exit", [nativeIntCarrier], unitCarrier),
    staticPropertyRead(defaultId, `${defaultId}.env`, "process", "environment_object", processEnvCarrier),
    staticPropertyRead(defaultId, `${defaultId}.stdout`, "process", "stdout", processWriteStreamCarrier),
    staticPropertyRead(defaultId, `${defaultId}.stderr`, "process", "stderr", processWriteStreamCarrier),
    staticPropertyRead(defaultId, `${defaultId}.platform`, "process", "platform", nativeString),
    staticPropertyRead(defaultId, `${defaultId}.arch`, "process", "arch", nativeString),
    staticPropertyRead(defaultId, `${defaultId}.argv`, "process", "arguments", stringListCarrier, true),
    staticPropertyRead(defaultId, `${defaultId}.argv0`, "process", "argument_zero", nativeString),
    staticPropertyRead(defaultId, `${defaultId}.pid`, "process", "process_id", nativeIntCarrier),
    staticPropertyRead(defaultId, `${defaultId}.ppid`, "process", "parent_process_id", nativeIntCarrier),
    staticPropertyRead(defaultId, `${defaultId}.execPath`, "process", "executable_path", nativeString, true),
    staticPropertyRead(defaultId, `${defaultId}.exitCode`, "process", "exit_code", optionalInt32Carrier),
    staticPropertyWrite(defaultId, `${defaultId}.exitCode`, "process", "set_exit_code", optionalInt32Carrier),
  ]);
}

function memoryUsageProperties(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    propertyRead(memoryUsageId, `${memoryUsageId}.rss`, "rss", processMemoryUsageCarrier, float64Carrier),
    propertyRead(memoryUsageId, `${memoryUsageId}.heapTotal`, "heap_total", processMemoryUsageCarrier, float64Carrier),
    propertyRead(memoryUsageId, `${memoryUsageId}.heapUsed`, "heap_used", processMemoryUsageCarrier, float64Carrier),
    propertyRead(memoryUsageId, `${memoryUsageId}.external`, "external", processMemoryUsageCarrier, float64Carrier),
    propertyRead(memoryUsageId, `${memoryUsageId}.arrayBuffers`, "array_buffers", processMemoryUsageCarrier, float64Carrier),
  ]);
}

function classExport(
  id: string,
  name: string,
  members: NonNullable<MojoProviderModuleDefinition["exports"][number]["members"]>,
): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({ id, name, kind: "class", members: Object.freeze(members) });
}
