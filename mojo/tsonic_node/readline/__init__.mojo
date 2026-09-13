from .options import ReadLineOptions
from .interface import (
    Interface,
    QuestionCallback,
    has_pending_readline,
    poll_readline,
)


def create_interface(options: ReadLineOptions) raises -> Interface:
    return Interface(options)
