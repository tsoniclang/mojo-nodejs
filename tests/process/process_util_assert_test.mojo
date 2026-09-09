from std.collections import List
from std.testing import assert_equal, assert_true
from tsonic_node import (
    Buffer,
    TextDecoder,
    ok,
    spawn_sync,
    strict_equal,
    strip_vt_control_characters,
    style_text,
)
from tsonic_node.process import exit_code, set_exit_code


def main() raises:
    ok(True)
    strict_equal(4, 4)
    assert_equal(strip_vt_control_characters("\x1b[31mred\x1b[39m"), "red")
    assert_equal(style_text("bold", "value"), "\x1b[1mvalue\x1b[22m")
    assert_equal(TextDecoder().decode(Buffer.from_string("text")), "text")

    var arguments = List[String]()
    arguments.append("%s:%s")
    arguments.append("left")
    arguments.append("right")
    var result = spawn_sync("/usr/bin/printf", arguments^)
    assert_equal(result.status.value(), Int32(0))
    assert_equal(result.stdout.to_string(), "left:right")
    assert_equal(result.stderr.to_string(), "")
    assert_true(len(result.stdout) == 10)

    set_exit_code(Optional[Int32](2))
    assert_equal(exit_code().value(), Int32(2))
    set_exit_code(Optional[Int32]())
    assert_true(not Bool(exit_code()))
