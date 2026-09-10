import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import type { MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, float64Carrier, nativeString, numberType,
  propertyMember, propertyRead, propertyWrite, stringArrayType, stringListCarrier, stringType,
} from "../../model.js";
import type { ProviderTypeExpression } from "../../model/types.js";

interface Field {
  readonly source: string;
  readonly target: string;
  readonly sourceType: ProviderTypeExpression;
  readonly carrier: MojoTargetTypeRef;
}

const common = [
  { source: "ca", target: "ca", sourceType: stringArrayType, carrier: stringListCarrier },
  { source: "ALPNProtocols", target: "alpn_protocols", sourceType: stringArrayType, carrier: stringListCarrier },
  { source: "rejectUnauthorized", target: "reject_unauthorized", sourceType: booleanType, carrier: boolCarrier },
  { source: "allowHalfOpen", target: "allow_half_open", sourceType: booleanType, carrier: boolCarrier },
] as const;

export const tlsConnectionFields: readonly Field[] = [
  { source: "host", target: "host", sourceType: stringType, carrier: nativeString },
  { source: "servername", target: "servername", sourceType: stringType, carrier: nativeString },
  { source: "port", target: "port", sourceType: numberType, carrier: float64Carrier },
  ...common,
  { source: "timeout", target: "timeout", sourceType: numberType, carrier: float64Carrier },
];

export const tlsServerFields: readonly Field[] = [
  { source: "key", target: "key", sourceType: stringType, carrier: nativeString },
  { source: "cert", target: "cert", sourceType: stringType, carrier: nativeString },
  ...common,
  { source: "requestCert", target: "request_cert", sourceType: booleanType, carrier: boolCarrier },
  { source: "handshakeTimeout", target: "handshake_timeout", sourceType: numberType, carrier: float64Carrier },
];

export function tlsOptionMembers(id: string, fields: readonly Field[]) {
  return Object.freeze(fields.map((field) => propertyMember(id, field.source, field.sourceType, { readonly: false, optional: true })));
}

export function tlsOptionDeclaration(id: string, name: string, fields: readonly Field[]) {
  return Object.freeze({ id, name, kind: "interface" as const, members: tlsOptionMembers(id, fields) });
}

export function tlsOptionOperations(id: string, receiver: MojoTargetTypeRef, fields: readonly Field[]) {
  return fields.flatMap((field) => {
    const type = mojoOptionalTargetType(field.carrier);
    return [
      propertyRead(id, `${id}.${field.source}`, field.target, receiver, type),
      propertyWrite(id, `${id}.${field.source}`, field.target, receiver, type),
    ];
  });
}
