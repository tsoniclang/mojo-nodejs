from std.memory import ArcPointer
from std.ffi import external_call
from tsonic_runtime import RaisingCallable


struct _TlsServerNativeState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_tls_server_free", NoneType](
                self.handle.value()
            )
