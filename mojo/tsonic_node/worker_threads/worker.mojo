from std.collections import List
from tsonic_js import JsValue
from .ports import MessagePort


struct WorkerOptions(Copyable):
    var name: Optional[String]
    var argv: Optional[List[String]]
    var env: JsValue
    var worker_data: JsValue

    def __init__(
        out self,
        name: Optional[String] = None,
        argv: Optional[List[String]] = None,
        env: JsValue = JsValue.undefined(),
        worker_data: JsValue = JsValue.undefined(),
    ):
        self.name = name
        self.argv = argv
        self.env = env
        self.worker_data = worker_data


struct Worker(ImplicitlyCopyable):
    var _thread_id: Int32

    def __init__(out self, thread_id: Int32):
        self._thread_id = thread_id


def is_main_thread() -> Bool:
    return True


def thread_id() -> Float64:
    return 0


def worker_data() -> JsValue:
    return JsValue.undefined()


def parent_port() -> Optional[MessagePort]:
    return None
