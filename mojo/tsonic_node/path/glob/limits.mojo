comptime pattern_limit = 65536
comptime expansion_limit = 65536
comptime source_limit = 16777216
comptime depth_limit = 128


def require_source_size(size: Int) raises:
    if size > source_limit:
        raise Error("Path glob generated-source budget exceeded")


def require_expansion_size(count: Int) raises:
    if count > expansion_limit:
        raise Error("Path glob expansion budget exceeded")


def require_depth(depth: Int) raises:
    if depth > depth_limit:
        raise Error("Path glob nesting budget exceeded")
