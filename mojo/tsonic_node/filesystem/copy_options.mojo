from std.utils import Variant
from tsonic_runtime import RaisingCallable, ClosedRaisingCoroutine


comptime CopyFilter = RaisingCallable[Tuple[String, String], Bool]
comptime CopyFilterFuture = ClosedRaisingCoroutine[Bool]
comptime CopyFilterResult = Variant[Bool, CopyFilterFuture]
comptime AsyncCopyFilter = RaisingCallable[
    Tuple[String, String], CopyFilterResult
]


struct CopyOptions(Copyable):
    var dereference: Optional[Bool]
    var error_on_exist: Optional[Bool]
    var force: Optional[Bool]
    var mode: Optional[Float64]
    var preserve_timestamps: Optional[Bool]
    var recursive: Optional[Bool]
    var verbatim_symlinks: Optional[Bool]
    var filter: Optional[CopyFilter]

    def __init__(out self):
        self.dereference = None
        self.error_on_exist = None
        self.force = None
        self.mode = None
        self.preserve_timestamps = None
        self.recursive = None
        self.verbatim_symlinks = None
        self.filter = None


struct AsyncCopyOptions(Copyable):
    var dereference: Optional[Bool]
    var error_on_exist: Optional[Bool]
    var force: Optional[Bool]
    var mode: Optional[Float64]
    var preserve_timestamps: Optional[Bool]
    var recursive: Optional[Bool]
    var verbatim_symlinks: Optional[Bool]
    var filter: Optional[AsyncCopyFilter]

    def __init__(out self):
        self.dereference = None
        self.error_on_exist = None
        self.force = None
        self.mode = None
        self.preserve_timestamps = None
        self.recursive = None
        self.verbatim_symlinks = None
        self.filter = None

    def controls(self) -> CopyOptions:
        var result = CopyOptions()
        result.dereference = self.dereference
        result.error_on_exist = self.error_on_exist
        result.force = self.force
        result.mode = self.mode
        result.preserve_timestamps = self.preserve_timestamps
        result.recursive = self.recursive
        result.verbatim_symlinks = self.verbatim_symlinks
        return result^
