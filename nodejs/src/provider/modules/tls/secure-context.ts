import { mojoNamedTargetType } from "@tsonic/target-mojo/provider";
import { bufferCarrier, nativeString, providerRef, stringArrayType, stringListCarrier, stringType } from "../../model.js";

export const secureContextCarrier = mojoNamedTargetType("tsonic.mojo.node.tls.SecureContext", ["tsonic_node", "tls"], "SecureContext");
export const secureContextOptionsCarrier = mojoNamedTargetType("tsonic.mojo.node.tls.SecureContextOptions", ["tsonic_node", "tls"], "SecureContextOptions");
export const secureContextFields = [
  { source: "key", target: "key", sourceType: stringType, carrier: nativeString },
  { source: "cert", target: "cert", sourceType: stringType, carrier: nativeString },
  { source: "ca", target: "ca", sourceType: stringArrayType, carrier: stringListCarrier },
  { source: "pfx", target: "pfx", sourceType: providerRef("node:buffer", "Buffer"), carrier: bufferCarrier },
  { source: "passphrase", target: "passphrase", sourceType: stringType, carrier: nativeString },
  { source: "minVersion", target: "min_version", sourceType: stringType, carrier: nativeString },
  { source: "maxVersion", target: "max_version", sourceType: stringType, carrier: nativeString },
] as const;
