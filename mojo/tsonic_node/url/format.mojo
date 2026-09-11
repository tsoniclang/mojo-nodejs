from .legacy import LegacyUrl, parse_legacy, format_legacy
from .url import URL


def format_url(value: LegacyUrl) raises -> String:
    return format_legacy(value)


def format_url(value: URL) raises -> String:
    return value.href()


def format_url(value: String) raises -> String:
    return format_legacy(parse_legacy(value))
