import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition } from "@tsonic/target-mojo/provider";
import { float64Carrier, numberType, propertyMember, staticPropertyRead } from "../../model.js";

const owner = "node:zlib::constants";
const constants = [
  ["Z_NO_FLUSH", "z_no_flush"],
  ["Z_PARTIAL_FLUSH", "z_partial_flush"],
  ["Z_SYNC_FLUSH", "z_sync_flush"],
  ["Z_FULL_FLUSH", "z_full_flush"],
  ["Z_FINISH", "z_finish"],
  ["Z_BLOCK", "z_block"],
  ["Z_DEFAULT_COMPRESSION", "z_default_compression"],
  ["Z_BEST_SPEED", "z_best_speed"],
  ["Z_BEST_COMPRESSION", "z_best_compression"],
  ["Z_NO_COMPRESSION", "z_no_compression"],
  ["Z_DEFAULT_STRATEGY", "z_default_strategy"],
  ["Z_FILTERED", "z_filtered"],
  ["Z_HUFFMAN_ONLY", "z_huffman_only"],
  ["Z_RLE", "z_rle"],
  ["Z_FIXED", "z_fixed"],
  ["BROTLI_OPERATION_PROCESS", "brotli_operation_process"],
  ["BROTLI_OPERATION_FLUSH", "brotli_operation_flush"],
  ["BROTLI_OPERATION_FINISH", "brotli_operation_finish"],
  ["BROTLI_PARAM_MODE", "brotli_param_mode"],
  ["BROTLI_PARAM_QUALITY", "brotli_param_quality"],
  ["BROTLI_PARAM_LGWIN", "brotli_param_lgwin"],
  ["BROTLI_PARAM_LGBLOCK", "brotli_param_lgblock"],
  ["BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING", "brotli_param_disable_literal_context_modeling"],
  ["BROTLI_PARAM_SIZE_HINT", "brotli_param_size_hint"],
  ["BROTLI_PARAM_LARGE_WINDOW", "brotli_param_large_window"],
  ["BROTLI_MODE_GENERIC", "brotli_mode_generic"],
  ["BROTLI_MODE_TEXT", "brotli_mode_text"],
  ["BROTLI_MODE_FONT", "brotli_mode_font"],
  ["BROTLI_MIN_QUALITY", "brotli_min_quality"],
  ["BROTLI_MAX_QUALITY", "brotli_max_quality"],
  ["BROTLI_DEFAULT_QUALITY", "brotli_default_quality"],
  ["BROTLI_MIN_WINDOW_BITS", "brotli_min_window_bits"],
  ["BROTLI_MAX_WINDOW_BITS", "brotli_max_window_bits"],
  ["BROTLI_DEFAULT_WINDOW", "brotli_default_window"],
  ["BROTLI_DECODER_PARAM_DISABLE_RING_BUFFER_REALLOCATION", "brotli_decoder_param_disable_ring_buffer_reallocation"],
  ["BROTLI_DECODER_PARAM_LARGE_WINDOW", "brotli_decoder_param_large_window"],
] as const;

export function compressionConstantsExport(): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({
    id: owner,
    name: "constants",
    kind: "class",
    members: Object.freeze(constants.map(([name]) => propertyMember(owner, name, numberType, { readonly: true, static: true }))),
  });
}

export function compressionConstantsOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(constants.map(([name, helper]) => staticPropertyRead(owner, `${owner}.${name}`, "zlib", helper, float64Carrier)));
}
