from std.collections import List
from std.ffi import c_char, c_int, c_pid_t, external_call, get_errno
from std.io import FileDescriptor
from std.os import abort, remove, rmdir
from std.pathlib import Path
from std.sys._libc import (
    close,
    dup2,
    fcntl,
    FcntlCommands,
    FcntlFDFlags,
    pipe,
    waitpid,
)
from std.tempfile import mkdtemp

from .buffer import Buffer


@fieldwise_init
struct SpawnSyncResult(Copyable):
    var stdout: Buffer
    var stderr: Buffer
    var status: Optional[Int32]


def spawn_sync(
    command: String, arguments: List[String]
) raises -> SpawnSyncResult:
    var temporary_directory = mkdtemp(prefix="tsonic-spawn-")
    var stdout_path = temporary_directory + "/stdout"
    var stderr_path = temporary_directory + "/stderr"
    var stdout_file = open(stdout_path, "w")
    var stderr_file = open(stderr_path, "w")
    var control = Array[c_int, 2](fill=0)
    if pipe(control.unsafe_ptr()) != 0:
        stdout_file.close()
        stderr_file.close()
        _cleanup_capture(temporary_directory, stdout_path, stderr_path)
        raise Error("Unable to create the spawnSync control pipe")
    if (
        fcntl(
            control[1],
            FcntlCommands.F_SETFD,
            fcntl(control[1], FcntlCommands.F_GETFD, 0)
            | FcntlFDFlags.FD_CLOEXEC,
        )
        != 0
    ):
        _ = close(control[0])
        _ = close(control[1])
        stdout_file.close()
        stderr_file.close()
        _cleanup_capture(temporary_directory, stdout_path, stderr_path)
        raise Error("Unable to protect the spawnSync control pipe")

    var process_id = external_call["fork", c_pid_t]()
    if process_id < 0:
        _ = close(control[0])
        _ = close(control[1])
        stdout_file.close()
        stderr_file.close()
        _cleanup_capture(temporary_directory, stdout_path, stderr_path)
        raise Error("Unable to fork for spawnSync: ", get_errno())

    if process_id == 0:
        _ = close(control[0])
        if (
            dup2(c_int(stdout_file._get_raw_fd()), c_int(1)) < 0
            or dup2(c_int(stderr_file._get_raw_fd()), c_int(2)) < 0
        ):
            _report_exec_failure(control[1])
        stdout_file.close()
        stderr_file.close()
        var owned_arguments = List[String](capacity=len(arguments) + 1)
        owned_arguments.append(command)
        for argument in arguments:
            owned_arguments.append(argument)
        var native_arguments = List[OptionalPointer[c_char, ImmutAnyOrigin]](
            capacity=len(owned_arguments) + 1
        )
        for index in range(len(owned_arguments)):
            native_arguments.append(
                owned_arguments[index]
                .as_c_string_slice()
                .ptr()
                .as_unsafe_any_origin()
            )
        native_arguments.append(OptionalPointer[c_char, ImmutAnyOrigin]())
        _ = external_call["execvp", c_int](
            owned_arguments[0].as_c_string_slice().ptr().as_unsafe_any_origin(),
            native_arguments.unsafe_ptr(),
        )
        _report_exec_failure(control[1])

    _ = close(control[1])
    stdout_file.close()
    stderr_file.close()
    var native_status: c_int = 0
    if waitpid(process_id, Pointer(to=native_status), 0) < 0:
        _ = close(control[0])
        _cleanup_capture(temporary_directory, stdout_path, stderr_path)
        raise Error("Unable to wait for spawnSync: ", get_errno())

    var failure = Array[Byte, 1](fill=0)
    var control_reader = FileDescriptor(Int(control[0]))
    var failure_count = control_reader.read_bytes(Span(failure))
    _ = close(control[0])
    var standard_output = Buffer(Path(stdout_path).read_bytes())
    var standard_error = Buffer(Path(stderr_path).read_bytes())
    _cleanup_capture(temporary_directory, stdout_path, stderr_path)
    if failure_count > 0:
        return SpawnSyncResult(standard_output^, standard_error^, None)
    if (native_status & 0x7F) == 0:
        return SpawnSyncResult(
            standard_output^,
            standard_error^,
            Optional(Int32((native_status & 0xFF00) >> 8)),
        )
    return SpawnSyncResult(standard_output^, standard_error^, None)


def _report_exec_failure(control: c_int) -> Never:
    var marker = Array[Byte, 1](fill=1)
    var control_writer = FileDescriptor(Int(control))
    control_writer.write_bytes(Span(marker))
    external_call["_exit", NoneType](c_int(127))
    abort("_exit returned while handling a spawnSync failure")


def _cleanup_capture(
    directory: String, stdout_path: String, stderr_path: String
):
    try:
        remove(stdout_path)
    except:
        pass
    try:
        remove(stderr_path)
    except:
        pass
    try:
        rmdir(directory)
    except:
        pass
