import type { MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  constructorMember, emptyCallbackCarrier, float64Carrier, functionCall,
  instanceCall, nativeString, netServerCarrier, netSocketCarrier, numberType,
  overloadedMethodMember, providerCallbackType, providerRef, stringType,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";
import { connectionOptionsCarrier, connectionOptionsType, listenOptionsCarrier, listenOptionsType } from "./records.js";

type Parameter = { readonly name: string; readonly type: ProviderTypeExpression; readonly carrier: MojoTargetTypeRef };
type Row = { readonly suffix: string; readonly target: string; readonly parameters: readonly Parameter[] };
const port: Parameter = { name: "port", type: numberType, carrier: float64Carrier };
const host: Parameter = { name: "host", type: stringType, carrier: nativeString };
const backlog: Parameter = { name: "backlog", type: numberType, carrier: float64Carrier };
const connectRows: readonly Row[] = [
  { suffix: "port", target: "connect_port", parameters: [port] },
  { suffix: "port,host", target: "connect_port_host", parameters: [port, host] },
  { suffix: "options", target: "connect_options", parameters: [{ name: "options", type: connectionOptionsType, carrier: connectionOptionsCarrier }] },
];
const listenRows: readonly Row[] = [
  { suffix: "options", target: "listen_options", parameters: [{ name: "options", type: listenOptionsType, carrier: listenOptionsCarrier }] },
  { suffix: "port,backlog", target: "listen_port_backlog", parameters: [port, backlog] },
  { suffix: "port,host,backlog", target: "listen_port_host_backlog", parameters: [port, host, backlog] },
];

function overloads(owner: string, method: string, rows: readonly Row[]) {
  return rows.flatMap((row) => [row, { ...row, suffix: `${row.suffix},callback`, target: `${row.target}_callback`, parameters: [...row.parameters, {
    name: "callback", type: providerCallbackType(`${owner}.${method}(${row.suffix},callback)`, "callback", []), carrier: emptyCallbackCarrier,
  }] }]);
}

export const socketConstructor = constructorMember("node:net::Socket", []);
export const socketConnectMember = overloadedMethodMember("node:net::Socket", "connect", overloads("node:net::Socket", "connect", connectRows).map((row) => ({
  signatureSuffix: row.suffix, parameters: row.parameters.map(({ name, type }) => ({ name, type })), returnType: providerRef("node:net", "Socket"),
})));
export const additionalListenSignatures = overloads("node:net::Server", "listen", listenRows).map((row) => ({
  signatureSuffix: row.suffix, parameters: row.parameters.map(({ name, type }) => ({ name, type })), returnType: providerRef("node:net", "Server"),
}));

export const networkLifecycleOperations: readonly MojoProviderOperationDefinition[] = [
  { ...functionCall("node:net::Socket", "node:net::Socket.constructor()", "net", "socket_new", [], netSocketCarrier), memberId: "node:net::Socket.constructor", operationKind: "constructor" },
  ...overloads("node:net::Socket", "connect", connectRows).map((row) => instanceCall("node:net::Socket", "node:net::Socket.connect", `node:net::Socket.connect(${row.suffix})`, row.target, netSocketCarrier, row.parameters.map((parameter) => parameter.carrier), netSocketCarrier, true, "mut")),
  ...overloads("node:net::Server", "listen", listenRows).map((row) => instanceCall("node:net::Server", "node:net::Server.listen", `node:net::Server.listen(${row.suffix})`, row.target, netServerCarrier, row.parameters.map((parameter) => parameter.carrier), netServerCarrier, true, "mut")),
];
