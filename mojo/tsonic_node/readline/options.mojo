from ..stream import Readable, Writable


struct ReadLineOptions(Copyable):
    var input: Readable
    var output: Optional[Writable]
    var terminal: Optional[Bool]
    var prompt: Optional[String]
    var historySize: Optional[Float64]
    var removeHistoryDuplicates: Optional[Bool]

    def __init__(out self):
        self.input = Readable()
        self.output = None
        self.terminal = None
        self.prompt = None
        self.historySize = None
        self.removeHistoryDuplicates = None
