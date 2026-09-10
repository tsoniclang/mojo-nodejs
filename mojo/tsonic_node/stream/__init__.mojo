from .readable import Readable
from .writable import Writable


def stdin() -> Readable:
    return Readable(0)


def stdout() -> Writable:
    return Writable(1, False)


def stderr() -> Writable:
    return Writable(2, False)
