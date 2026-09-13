from std.collections import List
from std.memory import ArcPointer
from std.utils.lock import BlockingScopedLock, BlockingSpinLock
from tsonic_runtime import GlobalCell
from tsonic_runtime.numeric import source_number_to_uint32
from .core import Buffer


@fieldwise_init
struct _BufferPool:
    var lock: BlockingSpinLock
    var size: Float64
    var storage: Optional[ArcPointer[List[Byte]]]
    var position: Int


def _initial_pool() -> _BufferPool:
    return _BufferPool(BlockingSpinLock(), 8192.0, None, 0)


comptime _pool = GlobalCell["tsonic.node.buffer.pool", _initial_pool]()


def checked_buffer_size(size: Float64) raises -> Int:
    if not (size >= 0 and size <= 9007199254740991):
        raise Error("Buffer size is outside the valid range")
    return Int(size)


def buffer_pool_size() -> Float64:
    var pool = _pool.get()
    with BlockingScopedLock(pool[].lock):
        return pool[].size


def set_buffer_pool_size(value: Float64):
    var pool = _pool.get()
    with BlockingScopedLock(pool[].lock):
        pool[].size = value


def pooled_buffer(size: Int) raises -> Buffer:
    if size < 0:
        raise Error("Buffer size cannot be negative")
    if size == 0:
        return Buffer()
    var pool = _pool.get()
    with BlockingScopedLock(pool[].lock):
        var threshold = Int(source_number_to_uint32(pool[].size) >> 1)
        if size >= threshold:
            return Buffer.allocate(size)
        if (
            not pool[].storage
            or size > len(pool[].storage.value()[]) - pool[].position
        ):
            var storage = Buffer.allocate(checked_buffer_size(pool[].size))
            if len(storage) < size:
                raise Error(
                    "Buffer pool cannot contain the requested allocation"
                )
            pool[].storage = storage._bytes
            pool[].position = 0
        var result = Buffer(pool[].storage.value(), pool[].position, size)
        pool[].position = (pool[].position + size + 7) & ~7
        return result


def buffer_alloc_unsafe(size: Float64) raises -> Buffer:
    return pooled_buffer(checked_buffer_size(size))


def buffer_alloc_unsafe_slow(size: Float64) raises -> Buffer:
    return Buffer.allocate(checked_buffer_size(size))


def pooled_bytes(bytes: List[Byte]) raises -> Buffer:
    var result = pooled_buffer(len(bytes))
    for index in range(len(bytes)):
        result.set(index, UInt8(bytes[index]))
    return result
