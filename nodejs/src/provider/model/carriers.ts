import { mojoCallableTargetType, mojoDynamicTargetType, mojoFutureTargetType, mojoListTargetType, mojoNamedTargetType, mojoOptionalTargetType, mojoPrimitiveTargetType, mojoStringTargetType, mojoUnitTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";

export const nativeString = mojoStringTargetType();

export const boolCarrier = mojoPrimitiveTargetType("bool");

export const nativeIntCarrier = mojoPrimitiveTargetType("native-int");

export const float64Carrier = mojoPrimitiveTargetType("float64");

export const int32Carrier = mojoPrimitiveTargetType("int32");

export const uint8Carrier = mojoPrimitiveTargetType("uint8");

export const unitCarrier = mojoUnitTargetType();

export const jsValueCarrier = mojoDynamicTargetType("js");

export const stringListCarrier = mojoListTargetType(nativeString);

export const numberListCarrier = mojoListTargetType(float64Carrier);

export const optionalInt32Carrier = mojoOptionalTargetType(int32Carrier);

export const optionalBoolCarrier = mojoOptionalTargetType(boolCarrier);

export const optionalFloat64Carrier = mojoOptionalTargetType(float64Carrier);

export const optionalStringCarrier = mojoOptionalTargetType(nativeString);

export const nativeStringFutureCarrier = mojoFutureTargetType(nativeString, "native", true);

export const unitFutureCarrier = mojoFutureTargetType(unitCarrier, "native", true);

export const stringListFutureCarrier = mojoFutureTargetType(stringListCarrier, "native", true);

export const bufferCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Buffer",
  ["tsonic_node", "buffer"],
  "Buffer",
);

export const statsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Stats",
  ["tsonic_node", "filesystem"],
  "Stats",
);

export const mkdirOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.MkdirOptions",
  ["tsonic_node", "filesystem"],
  "MkdirOptions",
);

export const rmOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.RmOptions",
  ["tsonic_node", "filesystem"],
  "RmOptions",
);

export const readdirOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.ReaddirOptions",
  ["tsonic_node", "filesystem"],
  "ReaddirOptions",
);

export const direntCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Dirent",
  ["tsonic_node", "filesystem"],
  "Dirent",
);

export const direntListCarrier = mojoListTargetType(direntCarrier);

export const pathPartsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.PathParts",
  ["tsonic_node", "path"],
  "PathParts",
);

export const processWriteStreamCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.stream.Writable",
  ["tsonic_node", "stream"],
  "Writable",
);

export const processEnvCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.ProcessEnv",
  ["tsonic_node", "process"],
  "ProcessEnv",
);

export const processMemoryUsageCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.MemoryUsage",
  ["tsonic_node", "process"],
  "MemoryUsage",
);

export const spawnSyncResultCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.SpawnSyncResult",
  ["tsonic_node", "child_process"],
  "SpawnSyncResult",
);

export const textDecoderCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.TextDecoder",
  ["tsonic_node", "util"],
  "TextDecoder",
);

export const legacyUrlCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.LegacyUrl",
  ["tsonic_node", "url"],
  "LegacyUrl",
);

export const hashCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Hash",
  ["tsonic_node", "crypto"],
  "Hash",
);

export const hmacCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Hmac",
  ["tsonic_node", "crypto"],
  "Hmac",
);

export const timeoutCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Timeout",
  ["tsonic_node", "timers"],
  "Timeout",
);

export const httpIncomingMessageCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpIncomingMessage",
  ["tsonic_node", "http"],
  "IncomingMessage",
);

export const httpServerResponseCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpServerResponse",
  ["tsonic_node", "http"],
  "ServerResponse",
);

export const httpServerCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpServer",
  ["tsonic_node", "http"],
  "Server",
);

export const eventEmitterCarrier = namedCarrier("EventEmitter", "events");

export const readableCarrier = namedCarrier("Readable", "stream");

export const writableCarrier = namedCarrier("Writable", "stream");

export const dnsLookupAddressCarrier = namedCarrier("LookupAddress", "dns");

export const zlibOptionsCarrier = namedCarrier("ZlibOptions", "zlib");

export const zlibTransformCarrier = namedCarrier("Zlib", "zlib");

export const netSocketCarrier = namedCarrier("Socket", "net");

export const netServerCarrier = namedCarrier("Server", "net");

export const tlsConnectOptionsCarrier = namedCarrier("ConnectionOptions", "tls");

export const tlsServerOptionsCarrier = namedCarrier("TlsOptions", "tls");

export const tlsSocketCarrier = namedCarrier("TLSSocket", "tls");

export const tlsServerCarrier = namedCarrier("Server", "tls");

export const httpsServerCarrier = namedCarrier("Server", "https");

export const readlineOptionsCarrier = namedCarrier("ReadLineOptions", "readline");

export const readlineInterfaceCarrier = namedCarrier("Interface", "readline");

export const workerCarrier = namedCarrier("Worker", "worker_threads");

export const workerOptionsCarrier = namedCarrier("WorkerOptions", "worker_threads");

export const messagePortCarrier = namedCarrier("MessagePort", "worker_threads");

export const messageChannelCarrier = namedCarrier("MessageChannel", "worker_threads");

export const emptyCallbackCarrier = mojoCallableTargetType([], unitCarrier, true);

export const oneValueCallbackCarrier = callbackCarrier([jsValueCarrier]);

export const twoValueCallbackCarrier = callbackCarrier([jsValueCarrier, jsValueCarrier]);

export const threeValueCallbackCarrier = callbackCarrier([
  jsValueCarrier,
  jsValueCarrier,
  jsValueCarrier,
]);

export const dnsLookupCallbackCarrier = callbackCarrier([
  jsValueCarrier,
  mojoOptionalTargetType(nativeString),
  mojoOptionalTargetType(float64Carrier),
]);

export const dnsAddressArrayCallbackCarrier = callbackCarrier([
  jsValueCarrier,
  mojoOptionalTargetType(stringListCarrier),
]);

export const zlibCallbackCarrier = callbackCarrier([jsValueCarrier, mojoOptionalTargetType(bufferCarrier)]);

export const netConnectionCallbackCarrier = callbackCarrier([netSocketCarrier]);

export const tlsSocketCallbackCarrier = callbackCarrier([tlsSocketCarrier]);

export const readlineQuestionCallbackCarrier = callbackCarrier([nativeString]);

export const httpResponseCallbackCarrier = callbackCarrier([httpIncomingMessageCarrier]);

export const httpRequestCallbackCarrier = mojoCallableTargetType(
  [httpIncomingMessageCarrier, httpServerResponseCarrier].map((type) => Object.freeze({
    convention: "imm" as const,
    passing: "plain" as const,
    type,
  })),
  unitCarrier,
  true,
);

function namedCarrier(name: string, moduleName: string): MojoTargetTypeRef {
  return mojoNamedTargetType(
    `tsonic.mojo.node.${moduleName}.${name}`,
    ["tsonic_node", moduleName],
    name,
  );
}

function callbackCarrier(types: readonly MojoTargetTypeRef[]): MojoTargetTypeRef {
  return mojoCallableTargetType(types.map((type) => Object.freeze({
    convention: "imm" as const,
    passing: "plain" as const,
    type,
  })), unitCarrier, true);
}

export function targetTypeParameter(name: string): MojoTargetTypeRef {
  return Object.freeze({ kind: "type-parameter", name });
}
