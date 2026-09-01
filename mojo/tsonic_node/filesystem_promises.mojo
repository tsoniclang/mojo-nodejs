from std.collections import List

from .buffer import Buffer
from .filesystem import (
    MkdirOptions,
    RmOptions,
    Stats,
    copy_file as copy_file_sync,
    make_directory as make_directory_sync,
    make_directory_default as make_directory_default_sync,
    read_directory_names,
    read_file as read_file_sync,
    read_text_file_encoded,
    remove_path as remove_path_sync,
    remove_path_default as remove_path_default_sync,
    rename_path as rename_path_sync,
    stat as stat_sync,
    unlink as unlink_sync,
    write_file as write_file_sync,
    write_text_file as write_text_file_sync,
)


async def read_file(path: String) raises -> Buffer:
    return read_file_sync(path)


async def read_text_file(path: String, encoding: String) raises -> String:
    return read_text_file_encoded(path, encoding)


async def write_file(path: String, value: Buffer) raises:
    write_file_sync(path, value)


async def write_text_file(path: String, value: String) raises:
    write_text_file_sync(path, value)


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


async def remove_path(path: String, options: RmOptions) raises:
    remove_path_sync(path, options)


async def unlink(path: String) raises:
    unlink_sync(path)


async def copy_file(source: String, destination: String) raises:
    copy_file_sync(source, destination)


async def rename_path(source: String, destination: String) raises:
    rename_path_sync(source, destination)
