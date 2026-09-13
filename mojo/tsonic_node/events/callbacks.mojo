from std.memory import ArcPointer
from std.utils import Variant
from tsonic_js import JsValue
from tsonic_runtime import RaisingCallable
from tsonic_runtime.callable import ErasedCallableEnvironment


comptime Listener0 = RaisingCallable[Tuple[], NoneType]
comptime Listener1 = RaisingCallable[Tuple[JsValue], NoneType]
comptime Listener2 = RaisingCallable[Tuple[JsValue, JsValue], NoneType]
comptime Listener3 = RaisingCallable[Tuple[JsValue, JsValue, JsValue], NoneType]
comptime EventCallback = Variant[Listener0, Listener1, Listener2, Listener3]


def callback_identity(
    callback: EventCallback,
) -> ArcPointer[ErasedCallableEnvironment]:
    if callback.isa[Listener0]():
        return callback.unsafe_get[Listener0]().identity()
    if callback.isa[Listener1]():
        return callback.unsafe_get[Listener1]().identity()
    if callback.isa[Listener2]():
        return callback.unsafe_get[Listener2]().identity()
    return callback.unsafe_get[Listener3]().identity()


def invoke_callback(
    callback: EventCallback, values: Tuple[JsValue, JsValue, JsValue]
) raises:
    if callback.isa[Listener0]():
        callback.unsafe_get[Listener0]().call(())
    elif callback.isa[Listener1]():
        callback.unsafe_get[Listener1]().call((values[0],))
    elif callback.isa[Listener2]():
        callback.unsafe_get[Listener2]().call((values[0], values[1]))
    else:
        callback.unsafe_get[Listener3]().call(values)


struct ListenerRegistration(ImplicitlyCopyable):
    var callback: EventCallback
    var once: Optional[ArcPointer[Bool]]

    def __init__(out self, callback: EventCallback, once: Bool):
        self.callback = callback
        self.once = ArcPointer(False) if once else Optional[ArcPointer[Bool]]()
