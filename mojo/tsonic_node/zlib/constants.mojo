from std.ffi import external_call


def z_no_flush() -> Float64:
    return external_call["tsonic_node_constant_Z_NO_FLUSH", Float64]()


def z_partial_flush() -> Float64:
    return external_call["tsonic_node_constant_Z_PARTIAL_FLUSH", Float64]()


def z_sync_flush() -> Float64:
    return external_call["tsonic_node_constant_Z_SYNC_FLUSH", Float64]()


def z_full_flush() -> Float64:
    return external_call["tsonic_node_constant_Z_FULL_FLUSH", Float64]()


def z_finish() -> Float64:
    return external_call["tsonic_node_constant_Z_FINISH", Float64]()


def z_block() -> Float64:
    return external_call["tsonic_node_constant_Z_BLOCK", Float64]()


def z_default_compression() -> Float64:
    return external_call["tsonic_node_constant_Z_DEFAULT_COMPRESSION", Float64]()


def z_best_speed() -> Float64:
    return external_call["tsonic_node_constant_Z_BEST_SPEED", Float64]()


def z_best_compression() -> Float64:
    return external_call["tsonic_node_constant_Z_BEST_COMPRESSION", Float64]()


def z_no_compression() -> Float64:
    return external_call["tsonic_node_constant_Z_NO_COMPRESSION", Float64]()


def z_default_strategy() -> Float64:
    return external_call["tsonic_node_constant_Z_DEFAULT_STRATEGY", Float64]()


def z_filtered() -> Float64:
    return external_call["tsonic_node_constant_Z_FILTERED", Float64]()


def z_huffman_only() -> Float64:
    return external_call["tsonic_node_constant_Z_HUFFMAN_ONLY", Float64]()


def z_rle() -> Float64:
    return external_call["tsonic_node_constant_Z_RLE", Float64]()


def z_fixed() -> Float64:
    return external_call["tsonic_node_constant_Z_FIXED", Float64]()


def brotli_operation_process() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_OPERATION_PROCESS", Float64]()


def brotli_operation_flush() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_OPERATION_FLUSH", Float64]()


def brotli_operation_finish() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_OPERATION_FINISH", Float64]()


def brotli_param_mode() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_MODE", Float64]()


def brotli_param_quality() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_QUALITY", Float64]()


def brotli_param_lgwin() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_LGWIN", Float64]()


def brotli_param_lgblock() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_LGBLOCK", Float64]()


def brotli_param_disable_literal_context_modeling() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING", Float64]()


def brotli_param_size_hint() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_SIZE_HINT", Float64]()


def brotli_param_large_window() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_PARAM_LARGE_WINDOW", Float64]()


def brotli_mode_generic() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MODE_GENERIC", Float64]()


def brotli_mode_text() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MODE_TEXT", Float64]()


def brotli_mode_font() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MODE_FONT", Float64]()


def brotli_min_quality() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MIN_QUALITY", Float64]()


def brotli_max_quality() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MAX_QUALITY", Float64]()


def brotli_default_quality() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_DEFAULT_QUALITY", Float64]()


def brotli_min_window_bits() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MIN_WINDOW_BITS", Float64]()


def brotli_max_window_bits() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_MAX_WINDOW_BITS", Float64]()


def brotli_default_window() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_DEFAULT_WINDOW", Float64]()


def brotli_decoder_param_disable_ring_buffer_reallocation() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_DECODER_PARAM_DISABLE_RING_BUFFER_REALLOCATION", Float64]()


def brotli_decoder_param_large_window() -> Float64:
    return external_call["tsonic_node_constant_BROTLI_DECODER_PARAM_LARGE_WINDOW", Float64]()
