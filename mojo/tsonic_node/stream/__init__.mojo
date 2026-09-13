from .readable import Readable
from .writable import Writable
from ..internal.duplex import Duplex
from tsonic_runtime import GlobalCell


def stdin() -> Readable:
    return Readable(0)


def _initial_stdout() -> Writable:
    return Writable(1, False)


def _initial_stderr() -> Writable:
    return Writable(2, False)


comptime _stdout = GlobalCell["tsonic.node.stdout", _initial_stdout]()
comptime _stderr = GlobalCell["tsonic.node.stderr", _initial_stderr]()


def stdout() -> Writable:
    return _stdout.get()[]


def stderr() -> Writable:
    return _stderr.get()[]
