from std.collections import List
from std.sys import argv
from tsonic_node.path import PathInput, PathDialect, posix_value, win32_value


def main() raises:
    var arguments = argv()
    if len(arguments) == 1:
        return
    if len(arguments) < 4:
        raise Error("Path oracle requires dialect, operation and input")
    var dialect = (
        win32_value() if String(arguments[1]) == "win32" else posix_value()
    )
    var operation = String(arguments[2])
    var path = String(arguments[3])
    if operation == "normalize":
        print(dialect.normalize(path))
    elif operation == "isAbsolute":
        print("true" if dialect.is_absolute(path) else "false")
    elif operation == "matchesGlob":
        if len(arguments) != 5:
            raise Error("Path glob oracle requires path and pattern")
        print(
            "true" if dialect.matches_glob(
                path, String(arguments[4])
            ) else "false"
        )
    elif operation == "dirname":
        print(dialect.dirname(path))
    elif operation == "basename":
        print(
            dialect.basename(
                path, String(arguments[4]) if len(arguments) > 4 else String()
            )
        )
    elif operation == "extname":
        print(dialect.extname(path))
    elif operation == "toNamespacedPath":
        print(dialect.to_namespaced_path(path))
    elif operation == "parse":
        var parts = dialect.parse(path)
        print(parts.root)
        print(parts.directory)
        print(parts.base)
        print(parts.name)
        print(parts.extension)
    elif operation == "format":
        if len(arguments) != 8:
            raise Error("Path format oracle requires five fields")
        var parts = PathInput()
        parts.root = String(arguments[3])
        parts.directory = String(arguments[4])
        parts.base = String(arguments[5])
        parts.name = String(arguments[6])
        parts.extension = String(arguments[7])
        print(dialect.format_path(parts))
    elif operation == "relative":
        print(dialect.relative(path, String(arguments[4])))
    elif operation == "join" or operation == "resolve":
        var parts = List[String]()
        for index in range(3, len(arguments)):
            parts.append(String(arguments[index]))
        print(
            dialect.join(parts) if operation
            == "join" else dialect.resolve(parts)
        )
    else:
        raise Error("Unknown path oracle operation")
