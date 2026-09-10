import { mojoCallableTargetType, mojoNamedTargetType, mojoOptionalTargetType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import {
  bufferCarrier, jsValueCarrier, nodeProviderType, propertyMember, propertyRead, providerCallbackType,
  providerRef, undefinedType, unitCarrier, zlibTransformCarrier,
} from "../../model.js";
import type { ResultMode } from "./options.js";

const bufferType = providerRef("node:buffer", "Buffer");
const infoType = providerRef("node:zlib", "ZlibInfo");
const infoCarrier = mojoNamedTargetType("tsonic.mojo.node.ZlibInfo", ["tsonic_node", "zlib"], "ZlibInfo");
const unionType = Object.freeze({ kind: "union" as const, types: Object.freeze([bufferType, infoType]) });
const unionCarrier = mojoUnionTargetType([bufferCarrier, infoCarrier]);

export function sourceResult(mode: ResultMode) {
  return mode === "buffer" ? bufferType : mode === "info" ? infoType : unionType;
}

export function targetResult(mode: ResultMode) {
  return mode === "buffer" ? bufferCarrier : mode === "info" ? infoCarrier : unionCarrier;
}

export function compressionCallbackType(signature: string, mode: ResultMode) {
  return providerCallbackType(signature, "callback", [
    { name: "error", type: Object.freeze({ kind: "any" }) },
    { name: "result", type: Object.freeze({ kind: "union", types: Object.freeze([sourceResult(mode), undefinedType]) }) },
  ]);
}

export function compressionCallbackCarrier(mode: ResultMode) {
  return mojoCallableTargetType([jsValueCarrier, mojoOptionalTargetType(targetResult(mode))].map((type) =>
    Object.freeze({ type, convention: "imm" as const, passing: "plain" as const })), unitCarrier, true);
}

export const compressionInfoExport = Object.freeze({
  id: "node:zlib::ZlibInfo", name: "ZlibInfo", kind: "interface" as const,
  members: Object.freeze([
    propertyMember("node:zlib::ZlibInfo", "buffer", bufferType),
    propertyMember("node:zlib::ZlibInfo", "engine", providerRef("node:zlib", "Zlib")),
  ]),
});
export const compressionInfoType = nodeProviderType(compressionInfoExport.id, infoCarrier, "implicitly-copyable");
export const compressionInfoOperations = Object.freeze([
  propertyRead(compressionInfoExport.id, `${compressionInfoExport.id}.buffer`, "buffer", infoCarrier, bufferCarrier),
  propertyRead(compressionInfoExport.id, `${compressionInfoExport.id}.engine`, "engine", infoCarrier, zlibTransformCarrier),
]);
