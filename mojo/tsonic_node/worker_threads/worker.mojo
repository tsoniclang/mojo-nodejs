from std.collections import List
from std.time import sleep
from tsonic_js import JsString, JsValue, js_value_from_array_values
from tsonic_js.value import encode_structured_clone
from ..internal.network_endpoint import monotonic_milliseconds
from .environment import environment_snapshot
from .native import spawn_channel
from .options import WorkerOptions, packed_arguments, packed_environment
from .ports import (
    MessagePort,
    Listener0,
    Listener1,
    register_port,
    poll_worker_threads,
    INITIALIZE,
)


struct Worker(ImplicitlyCopyable):
    var _port: MessagePort

    def __init__(out self, port: MessagePort):
        self._port = port

    def post_message(self, value: JsValue) raises:
        self._port.post_message(value)

    async def terminate(self) raises -> Float64:
        self._port._state[].terminating = True
        self._port._state[].channel.terminate()
        var deadline = monotonic_milliseconds() + 30000
        while not self._port._state[].exited:
            _ = poll_worker_threads()
            if monotonic_milliseconds() >= deadline:
                raise Error(
                    "Worker termination did not complete within its resource"
                    " deadline"
                )
            if not self._port._state[].exited:
                sleep(0.001)
        return Float64(self._port._state[].exit_code.value())

    def thread_id(self) -> Float64:
        return (
            -1 if self._port._state[]
            .exited else self._port._state[]
            .channel.id()
        )

    def ref_chain(mut self) -> Self:
        _ = self._port.ref_chain()
        return self

    def unref_chain(mut self) -> Self:
        _ = self._port.unref_chain()
        return self

    def on_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        _ = self._port._state[].events.on_callable(event, callback)
        return self

    def on_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        _ = self._port._state[].events.on_callable1(event, callback)
        return self

    def once_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        _ = self._port._state[].events.once_callable(event, callback)
        return self

    def once_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        _ = self._port._state[].events.once_callable1(event, callback)
        return self

    def off_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        _ = self._port._state[].events.off_callable(event, callback)
        return self

    def off_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        _ = self._port._state[].events.off_callable1(event, callback)
        return self


def worker_new(
    identity: String, options: WorkerOptions = WorkerOptions()
) raises -> Worker:
    var name = options.name.value() if options.name else String()
    if name.find("\0") >= 0:
        raise Error("Worker name contains a null byte")
    var initialization = js_value_from_array_values(
        [
            JsValue(JsString(identity)),
            options.worker_data,
            environment_snapshot(),
            JsValue(JsString(name)),
        ]
    )
    var payload = encode_structured_clone(initialization)
    var arguments = packed_arguments(identity, options)
    var environment = packed_environment(options)
    var channel = spawn_channel(
        arguments, environment, options.env.is_undefined()
    )
    channel.send(INITIALIZE, payload)
    return Worker(register_port(channel, True))
