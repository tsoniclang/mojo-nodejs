from std.collections import List
from std.ffi import c_int, external_call
from tsonic_js import JsString, JsValue
from tsonic_js.value import decode_structured_clone
from tsonic_runtime import GlobalCell
from .environment import restore_environment
from .native import adopt_channel, current_worker_id
from .ports import MessagePort, register_port, INITIALIZE, ONLINE


struct WorkerContext:
    var initialized: Bool
    var entry: Optional[String]
    var parent: Optional[MessagePort]
    var data: JsValue

    def __init__(out self):
        self.initialized = False
        self.entry = None
        self.parent = None
        self.data = JsValue.undefined()


def _initial_context() -> WorkerContext:
    return WorkerContext()


comptime _context = GlobalCell["tsonic.node.worker-threads.context", _initial_context]()


def source_module_entry() raises -> Optional[String]:
    if _context.get()[].initialized:
        raise Error("Worker module bootstrap cannot be repeated")
    _context.get()[].initialized = True
    var adopted = adopt_channel()
    if not adopted:
        return None
    var channel = adopted.value()
    channel.wait_message()
    var message = channel.receive()
    if not message:
        raise Error("Worker channel has no initialization message")
    var packet = message.take()
    if packet.kind != INITIALIZE:
        raise Error("Worker channel did not begin with initialization")
    var initialization = decode_structured_clone(packet.bytes^)
    if not initialization.is_array() or initialization.array_length() != 4:
        raise Error("Worker initialization inventory is invalid")
    var entry = initialization.array_at(0)
    var name = initialization.array_at(3)
    if not entry.is_string() or not name.is_string():
        raise Error("Worker initialization has no exact module identity or name")
    var native_name = name.string_value().to_native_strict()
    if native_name.find("\0") >= 0:
        raise Error("Worker name contains a null byte")
    if native_name.byte_length() != 0:
        var status = external_call["tsonic_node_worker_name", c_int](native_name.as_c_string_slice().ptr().as_unsafe_any_origin())
        if status != 0:
            raise Error("Unable to assign worker process name")
    restore_environment(initialization.array_at(2))
    _context.get()[].entry = entry.string_value().to_native_strict()
    _context.get()[].data = initialization.array_at(1)
    _context.get()[].parent = register_port(channel)
    channel.send(ONLINE, List[UInt8]())
    return _context.get()[].entry


def source_module_complete(success: Bool, message: String) raises:
    if not _context.get()[].parent:
        raise Error("Worker completion has no initialized parent channel")
    var channel = _context.get()[].parent.value()._state[].channel
    if not success:
        channel.send_failure(JsValue(JsString(message)))
    channel.flush()
    channel.close()
    if not success:
        external_call["exit", NoneType](c_int(1))


def is_main_thread() -> Bool:
    return not Bool(_context.get()[].parent)


def thread_id() -> Float64:
    return 0 if is_main_thread() else current_worker_id()


def worker_data() -> JsValue:
    return _context.get()[].data


def parent_port() -> Optional[MessagePort]:
    return _context.get()[].parent
