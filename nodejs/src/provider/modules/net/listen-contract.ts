import type { MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { emptyCallbackCarrier, float64Carrier, instanceCall, nativeString, numberType, overloadedMethodMember, providerCallbackType, providerRef, stringType } from "../../model.js";
import { listenOptionsCarrier, listenOptionsType } from "./records.js";

const port = { name: "port", type: numberType, carrier: float64Carrier };
const host = { name: "host", type: stringType, carrier: nativeString };
const backlog = { name: "backlog", type: numberType, carrier: float64Carrier };
const rows = [
  { suffix: "port", target: "listen_default_host", parameters: [port] },
  { suffix: "port,host", target: "listen", parameters: [port, host] },
  { suffix: "options", target: "listen_options", parameters: [{ name: "options", type: listenOptionsType, carrier: listenOptionsCarrier }] },
  { suffix: "port,backlog", target: "listen_backlog", parameters: [port, backlog] },
  { suffix: "port,host,backlog", target: "listen_host_backlog", parameters: [port, host, backlog] },
] as const;

function signatures(moduleSpecifier: string) {
  const owner = `${moduleSpecifier}::Server`;
  return rows.flatMap((row) => [
    { ...row, parameters: [...row.parameters] },
    { ...row, suffix: `${row.suffix},callback`, parameters: [...row.parameters, {
      name: "callback", carrier: emptyCallbackCarrier,
      type: providerCallbackType(`${owner}.listen(${row.suffix},callback)`, "callback", []),
    }] },
  ]);
}

export const listenOptionsImport = Object.freeze({
  moduleSpecifier: "node:net",
  namedImports: Object.freeze([{ exportedName: "ListenOptions" }]),
});

export function serverListenMember(moduleSpecifier: string) {
  return overloadedMethodMember(`${moduleSpecifier}::Server`, "listen", signatures(moduleSpecifier).map((row) => ({
    signatureSuffix: row.suffix,
    parameters: row.parameters.map(({ name, type }) => ({ name, type })),
    returnType: providerRef(moduleSpecifier, "Server"),
  })));
}

export function serverListenOperations(moduleSpecifier: string, carrier: MojoTargetTypeRef): readonly MojoProviderOperationDefinition[] {
  const owner = `${moduleSpecifier}::Server`;
  return signatures(moduleSpecifier).map((row) => instanceCall(owner, `${owner}.listen`, `${owner}.listen(${row.suffix})`, row.target, carrier, row.parameters.map((parameter) => parameter.carrier), carrier, true, "mut"));
}
