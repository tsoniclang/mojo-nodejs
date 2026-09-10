import { mojoNamedTargetType, mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, float64Carrier, nativeString, nodeProviderType, numberType,
  propertyMember, propertyRead, propertyWrite, providerRef, stringType,
} from "../../model.js";

const records = [
  { name: "AddressInfo", immutable: true, fields: [
    { name: "address", target: "address", source: stringType, carrier: nativeString, optional: false },
    { name: "family", target: "family", source: stringType, carrier: nativeString, optional: false },
    { name: "port", target: "port", source: numberType, carrier: float64Carrier, optional: false },
  ] },
  { name: "ServerOpts", immutable: false, fields: [
    { name: "allowHalfOpen", target: "allow_half_open", source: booleanType, carrier: boolCarrier, optional: true },
    { name: "pauseOnConnect", target: "pause_on_connect", source: booleanType, carrier: boolCarrier, optional: true },
  ] },
  { name: "NetConnectOpts", immutable: false, fields: [
    { name: "port", target: "port", source: numberType, carrier: float64Carrier, optional: false },
    { name: "host", target: "host", source: stringType, carrier: nativeString, optional: true },
    { name: "allowHalfOpen", target: "allow_half_open", source: booleanType, carrier: boolCarrier, optional: true },
    { name: "noDelay", target: "no_delay", source: booleanType, carrier: boolCarrier, optional: true },
    { name: "timeout", target: "timeout", source: numberType, carrier: float64Carrier, optional: true },
  ] },
] as const;

const targetNames = { AddressInfo: "AddressInfo", ServerOpts: "ServerOptions", NetConnectOpts: "ConnectionOptions" } as const;
const carriers = Object.freeze(Object.fromEntries(records.map(({ name }) => [name,
  mojoNamedTargetType(`tsonic.mojo.node.net.${targetNames[name]}`, ["tsonic_node", "net"], targetNames[name]),
])));

export const addressCarrier = carriers.AddressInfo!;
export const connectionOptionsCarrier = carriers.NetConnectOpts!;
export const serverOptionsCarrier = carriers.ServerOpts!;
export const addressType = providerRef("node:net", "AddressInfo");
export const connectionOptionsType = providerRef("node:net", "NetConnectOpts");
export const serverOptionsType = providerRef("node:net", "ServerOpts");

export const networkRecordExports = Object.freeze(records.map((record) => Object.freeze({
  id: `node:net::${record.name}`, name: record.name, kind: "interface" as const,
  members: Object.freeze(record.fields.map((field) =>
    propertyMember(`node:net::${record.name}`, field.name, field.source, { readonly: record.immutable, optional: field.optional }))),
})));

export const networkRecordTypes = Object.freeze(records.map((record) =>
  nodeProviderType(`node:net::${record.name}`, carriers[record.name]!, record.immutable ? "implicitly-copyable" : "copyable",
    { objectLiteralConstruction: !record.immutable })));

export const networkRecordOperations = Object.freeze(records.flatMap((record) =>
  record.fields.flatMap((field) => {
    const owner = `node:net::${record.name}`;
    const carrier = field.optional ? mojoOptionalTargetType(field.carrier) : field.carrier;
    return [
      propertyRead(owner, `${owner}.${field.name}`, field.target, carriers[record.name]!, carrier),
      ...record.immutable ? [] : [propertyWrite(owner, `${owner}.${field.name}`, field.target, carriers[record.name]!, carrier)],
    ];
  })));
