from std.collections import List

from ..buffer import Buffer
from .core import (
    MkdirOptions,
    RmOptions,
    Stats,
    copy_file as copy_file_sync,
    make_directory as make_directory_sync,
    make_directory_default as make_directory_default_sync,
    read_directory_names,
    remove_directory as remove_directory_sync,
    remove_path as remove_path_sync,
    remove_path_default as remove_path_default_sync,
    rename_path as rename_path_sync,
    stat as stat_sync,
    unlink as unlink_sync,
    real_path as real_path_sync,
    symbolic_link as symbolic_link_sync,
    make_temp_directory as make_temp_directory_sync,
)
from .contents import (
    read_file as read_file_sync,
    read_text_file_encoded,
    write_file as write_file_sync,
    write_text_file as write_text_file_sync,
    append_file as append_file_sync,
    append_text_file as append_text_file_sync,
)
from .descriptors import (
    access as access_sync,
    chmod as chmod_sync,
    truncate_file as truncate_file_sync,
)
from .links import read_link as read_link_sync


async def append_file(path: String, value: Buffer) raises:
    append_file_sync(path, value)


async def append_text_file(
    path: String, value: String, encoding: String = "utf8"
) raises:
    append_text_file_sync(path, value, encoding)


async def real_path(path: String) raises -> String:
    return real_path_sync(path)


async def symbolic_link(target: String, path: String) raises:
    symbolic_link_sync(target, path)


async def make_temp_directory(prefix: String) raises -> String:
    return make_temp_directory_sync(prefix)


async def read_file(path: String) raises -> Buffer:
    return read_file_sync(path)


async def read_text_file(path: String, encoding: String) raises -> String:
    return read_text_file_encoded(path, encoding)


async def write_file(path: String, value: Buffer) raises:
    write_file_sync(path, value)


async def write_text_file(
    path: String, value: String, encoding: String = "utf8"
) raises:
    write_text_file_sync(path, value, encoding)


async def read_directory(path: String) raises -> List[String]:
    return read_directory_names(path)


async def stat(path: String) raises -> Stats:
    return stat_sync(path)


async def make_directory_default(path: String) raises:
    make_directory_default_sync(path)


async def make_directory(path: String, options: MkdirOptions) raises:
    make_directory_sync(path, options)


async def remove_path_default(path: String) raises:
    remove_path_default_sync(path)


async def remove_directory(path: String) raises:
    remove_directory_sync(path)


async def remove_path(path: String, options: RmOptions) raises:
    remove_path_sync(path, options)


async def unlink(path: String) raises:
    unlink_sync(path)


async def copy_file(source: String, destination: String) raises:
    copy_file_sync(source, destination)


async def rename_path(source: String, destination: String) raises:
    rename_path_sync(source, destination)


async def access(path: String, mode: Float64 = 0) raises:
    access_sync(path, mode)


async def chmod(path: String, mode: Float64) raises:
    chmod_sync(path, mode)


async def read_link(path: String) raises -> String:
    return read_link_sync(path)


async def truncate_file(path: String, length: Float64 = 0) raises:
    truncate_file_sync(path, length)
