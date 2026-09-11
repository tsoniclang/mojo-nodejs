from std.collections import List
from std.utils import Variant
from tsonic_js import JsValue
from tsonic_runtime import RaisingCallable


comptime LookupCallback = RaisingCallable[
    Tuple[JsValue, Optional[String], Optional[Float64]], NoneType
]
comptime AddressListCallback = RaisingCallable[
    Tuple[JsValue, Optional[List[String]]], NoneType
]


@fieldwise_init
struct LookupAddress(Copyable):
    var address: String
    var family: Int32

    def address_value(self) -> String:
        return self.address

    def family_value(self) -> Float64:
        return Float64(self.family)


comptime LookupResult = Variant[LookupAddress, List[LookupAddress]]
comptime LookupCallbackResult = Variant[String, List[LookupAddress]]
comptime LookupAllCallback = RaisingCallable[
    Tuple[JsValue, Optional[List[LookupAddress]]], NoneType
]
comptime LookupAnyCallback = RaisingCallable[
    Tuple[JsValue, Optional[LookupCallbackResult], Optional[Float64]], NoneType
]
