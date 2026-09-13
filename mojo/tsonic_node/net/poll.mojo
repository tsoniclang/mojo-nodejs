from ..internal.network_endpoint import (
    has_network_resolution,
    poll_network_resolution,
)
from .server import has_active_servers, poll_servers
from .socket import has_active_sockets, poll_sockets


def has_active_net() -> Bool:
    return (
        has_network_resolution() or has_active_servers() or has_active_sockets()
    )


def poll_net() raises -> Bool:
    var resolution_work = poll_network_resolution()
    var server_work = poll_servers()
    var socket_work = poll_sockets()
    return resolution_work or server_work or socket_work
