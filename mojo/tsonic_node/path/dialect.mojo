from std.collections import List
from .model import PathParts, PathInput
from . import posix, win32
from .glob import matches_glob


@fieldwise_init
struct PathDialect(ImplicitlyCopyable):
    var windows: Bool

    def separator(self) -> String:
        return "\\" if self.windows else "/"

    def delimiter(self) -> String:
        return ";" if self.windows else ":"

    def normalize(self, path: String) -> String:
        return win32.normalize(path) if self.windows else posix.normalize(path)

    def is_absolute(self, path: String) -> Bool:
        return win32.is_absolute(path) if self.windows else posix.is_absolute(
            path
        )

    def matches_glob(self, path: String, pattern: String) raises -> Bool:
        return matches_glob(path, pattern, self.windows)

    def join(self, parts: List[String]) -> String:
        return win32.join(parts) if self.windows else posix.join(parts)

    def resolve(self, parts: List[String]) raises -> String:
        return win32.resolve(parts) if self.windows else posix.resolve(parts)

    def dirname(self, path: String) -> String:
        return win32.dirname(path) if self.windows else posix.dirname(path)

    def basename(self, path: String, suffix: String = "") -> String:
        return win32.basename(path, suffix) if self.windows else posix.basename(
            path, suffix
        )

    def extname(self, path: String) -> String:
        return win32.extname(path) if self.windows else posix.extname(path)

    def parse(self, path: String) -> PathParts:
        return win32.parse(path) if self.windows else posix.parse(path)

    def format_path(self, parts: PathParts) -> String:
        return win32.format_path(parts) if self.windows else posix.format_path(
            parts
        )

    def format_path(self, parts: PathInput) -> String:
        return win32.format_path(parts) if self.windows else posix.format_path(
            parts
        )

    def relative(self, source: String, target: String) raises -> String:
        return win32.relative(
            source, target
        ) if self.windows else posix.relative(source, target)

    def to_namespaced_path(self, path: String) raises -> String:
        return win32.to_namespaced_path(path) if self.windows else path

    def posix(self) -> Self:
        return Self(False)

    def win32(self) -> Self:
        return Self(True)


def posix_value() -> PathDialect:
    return PathDialect(False)


def win32_value() -> PathDialect:
    return PathDialect(True)
