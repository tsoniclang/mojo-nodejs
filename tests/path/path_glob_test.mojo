from std.testing import assert_equal, assert_false, assert_true
from tsonic_node.path import matches_glob, posix_value, win32_value
from tsonic_node.path.glob.braces import expand_braces


def ordinary_paths() raises:
    assert_true(matches_glob("", ""))
    assert_false(matches_glob("file.txt", ""))
    assert_true(matches_glob("file.txt", "*.txt"))
    assert_false(matches_glob("dir/file.txt", "*.txt"))
    assert_true(matches_glob("dir/file.txt", "**/*.txt"))
    assert_true(matches_glob("file.txt", "**/*.txt"))
    assert_true(matches_glob("posts/2026/entry.md", "posts/**/*.md"))
    assert_true(matches_glob("a/b/c", "a/**/**/c"))
    assert_false(matches_glob(".hidden", "*"))
    assert_false(matches_glob("a/.hidden/b", "a/**/b"))
    assert_true(matches_glob("a/.hidden/b", "a/.hidden/*"))
    assert_true(matches_glob(".hidden", ".*"))
    assert_false(matches_glob("..", ".*"))
    assert_false(matches_glob(".", ".*"))
    assert_true(matches_glob(".", "."))
    assert_true(matches_glob("a/b/", "a/*"))
    assert_false(matches_glob("a", "a/**"))
    assert_true(matches_glob("a/", "a/**"))
    assert_true(matches_glob("a//b/../c", "a/c"))
    assert_true(matches_glob("!important", "!important"))
    assert_false(matches_glob("other", "!important"))
    assert_true(matches_glob("#heading", "#heading"))
    assert_true(matches_glob("a\nb", "a?b"))
    assert_true(matches_glob("😀", "??"))
    assert_false(matches_glob("😀", "?"))
    assert_true(matches_glob("café.md", "caf?.md"))


def alternatives_and_ranges() raises:
    assert_true(matches_glob("entry.md", "*.{md,html}"))
    assert_false(matches_glob("entry.txt", "*.{md,html}"))
    assert_true(matches_glob("asset.svg", "*.{txt,{png,svg}}"))
    assert_true(matches_glob("part-03", "part-{01..05..2}"))
    assert_false(matches_glob("part-02", "part-{01..05..2}"))
    assert_true(matches_glob("part-03", "part-{05..01..2}"))
    assert_true(matches_glob("part-c", "part-{a..f..2}"))
    assert_true(matches_glob("part--2", "part-{-3..0}"))
    assert_true(matches_glob("{word}", "{word}"))
    assert_true(matches_glob("[word", "[word"))
    assert_true(matches_glob("x", "[w-z]"))
    assert_false(matches_glob("x", "[!w-z]"))
    assert_true(matches_glob("a", "[!w-z]"))
    assert_true(matches_glob("a", "[a-z]"))
    assert_false(matches_glob("b", "[z-a]"))
    assert_true(matches_glob("-", "[a-]"))
    assert_true(matches_glob("]", "[]a]"))
    assert_true(matches_glob("*", "[*]"))
    assert_true(matches_glob(".name", "[.]name"))
    assert_false(matches_glob(".name", "[.a]name"))
    assert_true(matches_glob("é", "[[:alpha:]]"))
    assert_true(matches_glob("٣", "[[:digit:]]"))
    assert_false(matches_glob("x", "[[:digit:]]"))


def extended_patterns() raises:
    assert_true(matches_glob("entry.md", "@(entry|index).md"))
    assert_false(matches_glob("other.md", "@(entry|index).md"))
    assert_true(matches_glob("ababc", "+(ab)c"))
    assert_false(matches_glob("c", "+(ab)c"))
    assert_true(matches_glob("c", "*(ab)c"))
    assert_true(matches_glob("abc", "?(ab)c"))
    assert_true(matches_glob("c", "?(ab)c"))
    assert_false(matches_glob("ababc", "?(ab)c"))
    assert_true(matches_glob("icon.svg", "!(*.png|*.jpg)"))
    assert_false(matches_glob("icon.png", "!(*.png|*.jpg)"))
    assert_true(matches_glob("other.js", "!(test).js"))
    assert_false(matches_glob("test.js", "!(test).js"))
    assert_true(matches_glob("src/file.test.ts", "src/@(*.ts|*.js)"))
    assert_false(matches_glob(".file", "!(other)"))
    assert_true(matches_glob(".file", "@(.file|*)"))
    assert_false(matches_glob(".other", "@(.file|*)"))
    assert_true(matches_glob("x.y", "+(?)"))
    assert_true(matches_glob("xyz", "!()"))
    assert_true(matches_glob("@()", "@()"))
    assert_true(matches_glob("@(unclosed", "@(unclosed"))


def dialects_and_limits() raises:
    var windows = win32_value()
    assert_true(windows.matches_glob("C:\\posts\\entry.md", "c:/posts/*.md"))
    assert_true(windows.matches_glob("\\\\?\\C:\\posts\\entry.md", "c:/posts/*.md"))
    assert_false(posix_value().matches_glob("C:\\posts\\entry.md", "C:/posts/*.md"))
    var rejected = False
    try:
        _ = matches_glob("file", "*" * 65537)
    except error:
        rejected = "65536" in String(error)
    assert_true(rejected)
    rejected = False
    try:
        _ = expand_braces("{0..65536}")
    except error:
        rejected = "expansion budget" in String(error)
    assert_true(rejected)
    rejected = False
    try:
        _ = matches_glob("a", "@(" * 129 + "a" + ")" * 129)
    except error:
        rejected = "nesting budget" in String(error)
    assert_true(rejected)
    assert_equal(len(expand_braces("a{b,c}{d,e}")), 4)


def main() raises:
    ordinary_paths()
    alternatives_and_ranges()
    extended_patterns()
    dialects_and_limits()
