from ..validation import checked_integer
from ..system_errors import get_system_error_name, get_system_error_message


def checked_path(value: String) raises:
    if value.find("\0") >= 0:
        raise Error("A filesystem path cannot contain a null character")


def check_status(status: Int32, operation: String) raises:
    if status < 0:
        raise Error(operation, ": ", get_system_error_name(Float64(status)), ": ",
                    get_system_error_message(Float64(status)))
