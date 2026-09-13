from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import Buffer
from tsonic_node.crypto import (
    create_hash,
    random_bytes,
    random_fill,
    random_int,
    timing_safe_equal,
)
from tsonic_node.crypto_catalog import get_ciphers, get_curves, get_hashes


def main() raises:
    var hashes = get_hashes()
    assert_true(len(hashes) > 0)
    assert_true(len(get_ciphers()) > 0)
    assert_true(len(get_curves()) > 0)
    for index in range(1, len(hashes)):
        assert_true(hashes[index - 1] < hashes[index])
    var initial = create_hash("SHA256")
    _ = initial.update_string("a")
    var copied = initial.copy_hash()
    _ = initial.update_string("b")
    _ = copied.update_string("c")
    assert_equal(
        initial.digest("hex"),
        create_hash("SHA256").update_string("ab").digest("hex"),
    )
    assert_equal(
        copied.digest("hex"),
        create_hash("SHA256").update_string("ac").digest("hex"),
    )
    var rejected = False
    try:
        _ = initial.copy_hash()
    except:
        rejected = True
    assert_true(rejected)
    assert_true(
        timing_safe_equal(
            Buffer.from_string("same"), Buffer.from_string("same")
        )
    )
    assert_false(
        timing_safe_equal(
            Buffer.from_string("same"), Buffer.from_string("diff")
        )
    )
    rejected = False
    try:
        _ = timing_safe_equal(Buffer(), Buffer.from_string("x"))
    except:
        rejected = True
    assert_true(rejected)
    var buffer = Buffer.allocate(32)
    var retained_alias = buffer
    _ = random_fill(buffer)
    assert_true(buffer.equals(retained_alias))
    assert_equal(random_int(7, 8), 7.0)
    assert_equal(random_int(-1, 0), -1.0)
    for _ in range(32):
        var random = random_int(3)
        assert_true(random >= 0 and random < 3)
        assert_equal(random, Float64(Int(random)))
    rejected = False
    try:
        _ = random_int(3, 3)
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(len(random_bytes(1.5)), 1)
