from std.collections import List
from tsonic_js import JsValue, js_value_to_string


struct WorkerOptions(Copyable):
    var name: Optional[String]
    var argv: Optional[List[String]]
    var env: JsValue
    var worker_data: JsValue

    def __init__(out self, name: Optional[String] = None, argv: Optional[List[String]] = None, env: JsValue = JsValue.undefined(), worker_data: JsValue = JsValue.undefined()):
        self.name = name
        self.argv = argv
        self.env = env
        self.worker_data = worker_data


def packed_arguments(identity: String, options: WorkerOptions) raises -> String:
    _without_null(identity)
    var result = identity + "\0"
    if options.argv:
        for argument in options.argv.value():
            _without_null(argument)
            result += argument + "\0"
    return result^


def packed_environment(options: WorkerOptions) raises -> String:
    if options.env.is_undefined():
        return ""
    if not options.env.is_object():
        raise Error("Worker env requires a closed string-keyed object")
    var result = String()
    for index in range(options.env.object_length()):
        var key = options.env.object_key(index).to_native_strict()
        var item = options.env.object_value(index)
        if item.is_symbol():
            raise Error("Worker environment symbols cannot be converted to strings")
        var value = js_value_to_string(item).to_native_strict()
        _without_null(key)
        _without_null(value)
        if key.byte_length() == 0 or key.find("=") >= 0:
            raise Error("Worker environment has an invalid variable name")
        result += key + "=" + value + "\0"
    return result^


def _without_null(value: String) raises:
    if value.find("\0") >= 0:
        raise Error("Worker process option contains a null byte")
