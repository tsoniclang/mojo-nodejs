from std.collections import List
from .descriptor import StreamDescriptor
from .read_buffer import ReadBuffer
from .native_read import NativeRead
from .pipe_sink import PipeSubscription
from .read_events import ReadEvents


@fieldwise_init
struct _ReadableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: ReadBuffer
    var paused: Bool
    var ended: Bool
    var closed: Bool
    var failed: Bool
    var eof: Bool
    var path: String
    var chunk_size: Int
    var position: Optional[Int64]
    var end: Optional[Int64]
    var bytes_read: Int64
    var auto_close: Bool
    var asynchronous: Bool
    var native_read: Optional[NativeRead]
    var pipes: List[PipeSubscription]
    var events: ReadEvents
    var registered: Bool
    var flowing: Bool
    var polling: Bool
    var resume_pending: Bool
    var readable_pending: Bool
