from std.ffi import c_int, external_call
from std.utils import Variant


struct LookupOptions(Copyable):
    var family: Optional[Variant[Float64, String]]
    var hints: Optional[Float64]
    var all: Optional[Bool]
    var verbatim: Optional[Bool]
    var order: Optional[String]

    def __init__(out self):
        self.family = None
        self.hints = None
        self.all = None
        self.verbatim = None
        self.order = None

    def selected_family(self) raises -> Int32:
        if not self.family:
            return 0
        var value = self.family.value()
        if value.isa[String]():
            var name = value.unsafe_get[String]()
            if name == "IPv4":
                return 4
            if name == "IPv6":
                return 6
        else:
            var number = value.unsafe_get[Float64]()
            if number == 0 or number == 4 or number == 6:
                return Int32(number)
        raise Error("DNS family must be 0, 4, 6, IPv4 or IPv6")

    def selected_hints(self) raises -> Int32:
        if not self.hints:
            return 0
        var value = self.hints.value()
        if not (value >= 0 and value <= 2147483647.0):
            raise Error("DNS hints must be a supported integer mask")
        var selected = Int32(value)
        var allowed = Int32(addrconfig()) | Int32(v4mapped()) | Int32(all_addresses())
        if Float64(selected) != value or selected & ~allowed != 0:
            raise Error("DNS hints must be a supported integer mask")
        return selected

    def selected_order(self) raises -> Int32:
        if self.order:
            var name = self.order.value()
            if name == "verbatim":
                return 0
            if name == "ipv4first":
                return 4
            if name == "ipv6first":
                return 6
            raise Error("Invalid DNS result order")
        return 4 if self.verbatim and not self.verbatim.value() else 0

    def selected_all(self) -> Bool:
        return self.all.value() if self.all else False


def family_options(family: Float64) -> LookupOptions:
    var options = LookupOptions()
    options.family = Variant[Float64, String](family)
    return options^


def addrconfig() -> Float64:
    return Float64(external_call["tsonic_node_dns_lookup_hint", c_int](c_int(0)))


def v4mapped() -> Float64:
    return Float64(external_call["tsonic_node_dns_lookup_hint", c_int](c_int(1)))


def all_addresses() -> Float64:
    return Float64(external_call["tsonic_node_dns_lookup_hint", c_int](c_int(2)))
