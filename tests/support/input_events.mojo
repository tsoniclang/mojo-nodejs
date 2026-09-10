from tsonic_node.readline import poll_readline
from tsonic_node.stream.readable import poll_readables
from tsonic_node.stream.completion import poll_streams


def poll_input_events() raises -> Bool:
    var worked = poll_readline()
    worked = poll_readables() or worked
    worked = poll_streams() or worked
    return worked
