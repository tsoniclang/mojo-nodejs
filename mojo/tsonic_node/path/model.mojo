struct PathParts(Copyable):
    var root: String
    var directory: String
    var base: String
    var name: String
    var extension: String

    def __init__(out self, var root: String = "", var directory: String = "", var base: String = "", var name: String = "", var extension: String = ""):
        self.root = root^
        self.directory = directory^
        self.base = base^
        self.name = name^
        self.extension = extension^


struct PathInput(Copyable):
    var root: Optional[String]
    var directory: Optional[String]
    var base: Optional[String]
    var name: Optional[String]
    var extension: Optional[String]

    def __init__(out self):
        self.root = None
        self.directory = None
        self.base = None
        self.name = None
        self.extension = None
