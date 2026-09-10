from std.testing import assert_equal, assert_true
from tsonic_node import (
    Buffer,
    create_hash,
    create_hmac,
    random_bytes,
    random_uuid,
)


def main() raises:
    assert_equal(
        create_hmac("sha256", "Jefe")
        .update_string("what do ya want for nothing?")
        .digest("hex"),
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
    )
    assert_equal(
        create_hmac("sha256", "").digest("hex"),
        "b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
    )
    var key = Buffer.from_string("xJefey").subarray(1, Float64(5))
    var mac = create_hmac("sha256", key)
    var shared = mac
    _ = mac.update_buffer(
        Buffer.from_string("xwhat do ya want for nothing?y").subarray(
            1, Float64(29)
        )
    )
    assert_equal(
        shared.digest().to_string("hex"),
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
    )
    assert_equal(mac.digest("hex"), "")
    var rejected = False
    try:
        _ = mac.update_string("later")
    except:
        rejected = True
    assert_true(rejected)
    var hash = create_hash("sha256")
    var hash_alias = hash
    _ = hash.update_string("a").update_string("bc")
    assert_equal(
        hash_alias.digest().to_string("hex"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    rejected = False
    try:
        _ = hash.digest("hex")
    except:
        rejected = True
    assert_true(rejected)
    for invalid in ["missing-algorithm", "sha256\0ignored"]:
        rejected = False
        try:
            _ = create_hash(invalid)
        except:
            rejected = True
        assert_true(rejected)
    assert_equal(len(random_bytes(0)), 0)
    assert_equal(len(random_bytes(1.5)), 1)
    assert_equal(len(random_bytes(32)), 32)
    for invalid in [
        -1.0,
        Float64(FloatLiteral.nan),
        Float64(FloatLiteral.infinity),
        2147483648.0,
    ]:
        rejected = False
        try:
            _ = random_bytes(invalid)
        except:
            rejected = True
        assert_true(rejected)
    for _ in range(16):
        var identifier = random_uuid()
        assert_equal(identifier.byte_length(), 36)
        assert_equal(identifier[byte=8:9], "-")
        assert_equal(identifier[byte=13:14], "-")
        assert_equal(identifier[byte=18:19], "-")
        assert_equal(identifier[byte=23:24], "-")
        assert_equal(identifier[byte=14:15], "4")
        var variant = identifier[byte=19:20]
        assert_true(
            variant == "8" or variant == "9" or variant == "a" or variant == "b"
        )
