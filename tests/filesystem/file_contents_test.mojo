from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node.buffer import buffer_from_string_encoded
from tsonic_node.filesystem import (
    RmOptions,
    append_file,
    append_text_file,
    exists,
    read_file,
    read_text_file_encoded,
    remove_path,
    write_file,
    write_text_file,
)
from tsonic_node.filesystem import promises
from tsonic_runtime import create_raising_task


def check_codec(
    path: String,
    source: String,
    encoding: String,
    expected_hex: String,
    decoded: String,
) raises:
    write_text_file(path, source, encoding)
    assert_equal(read_file(path).to_string("hex"), expected_hex)
    assert_equal(read_text_file_encoded(path, encoding), decoded)
    append_text_file(path, source, encoding)
    assert_equal(read_file(path).to_string("hex"), expected_hex + expected_hex)


async def check_promises(path: String) raises:
    await create_raising_task(promises.write_text_file(path, "41ff00", "hex"))
    await create_raising_task(promises.append_text_file(path, "Qg==", "base64"))
    var encoded = await create_raising_task(
        promises.read_text_file(path, "hex")
    )
    assert_equal(encoded, "41ff0042")
    var buffer = await create_raising_task(promises.read_file(path))
    assert_equal(len(buffer), 4)
    await create_raising_task(promises.write_text_file(path, "unchanged"))
    var rejected = False
    try:
        await create_raising_task(
            promises.write_text_file(path, "bad", "invalid-encoding")
        )
    except:
        rejected = True
    assert_true(rejected)
    var text = await create_raising_task(promises.read_text_file(path, "utf8"))
    assert_equal(text, "unchanged")


def main() raises:
    var root = mkdtemp(prefix="tsonic-file-codecs-")
    var path = root + "/contents"
    try:
        check_codec(path, "é😀", "UTF-8", "c3a9f09f9880", "é😀")
        check_codec(path, "é", "latin1", "e9", "é")
        check_codec(path, "é", "binary", "e9", "é")
        check_codec(path, "é", "ascii", "e9", "i")
        check_codec(path, "A😀", "utf16le", "41003dd800de", "A😀")
        check_codec(path, "é", "ucs-2", "e900", "é")
        check_codec(path, "41ff00", "hex", "41ff00", "41ff00")
        check_codec(path, "AP8=", "base64", "00ff", "AP8=")
        check_codec(path, "AP8", "base64url", "00ff", "AP8")
        write_file(path, buffer_from_string_encoded("610062ff", "hex"))
        assert_equal(read_text_file_encoded(path, "utf8"), "a\0b�")
        append_file(path, buffer_from_string_encoded("00", "hex"))
        assert_equal(read_text_file_encoded(path, "hex"), "610062ff00")
        write_text_file(path, "kept")
        var rejected = 0
        try:
            write_text_file(path, "lost", "invalid-encoding")
        except:
            rejected += 1
        try:
            append_text_file(path, "lost", "invalid-encoding")
        except:
            rejected += 1
        try:
            write_file(
                path + "\0suffix", buffer_from_string_encoded("41", "hex")
            )
        except:
            rejected += 1
        assert_equal(rejected, 3)
        assert_equal(read_text_file_encoded(path, "utf8"), "kept")
        try:
            write_text_file(root + "/absent", "lost", "invalid-encoding")
        except:
            rejected += 1
        assert_equal(rejected, 4)
        assert_false(exists(root + "/absent"))
        write_file(path, buffer_from_string_encoded("00d8", "hex"))
        try:
            _ = read_text_file_encoded(path, "utf16le")
        except:
            rejected += 1
        assert_equal(rejected, 5)
        var task = create_raising_task(check_promises(path))
        task^.wait()
    finally:
        remove_path(root, RmOptions(recursive=True))
