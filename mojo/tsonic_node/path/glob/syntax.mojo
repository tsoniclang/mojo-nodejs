from std.collections import List
from tsonic_js import JsString
from .characters import escaped_unit, parse_class
from .limits import require_depth, require_source_size


comptime sequence_kind = 0
comptime literal_kind = 1
comptime class_kind = 2


@fieldwise_init
struct GlobNode:
    var kind: Int
    var expression: String
    var literal: Optional[JsString]
    var children: List[Int]


def _extended(unit: UInt16) -> Bool:
    return unit == 33 or unit == 42 or unit == 43 or unit == 63 or unit == 64


struct GlobSyntax:
    var nodes: List[GlobNode]
    var pattern: JsString
    var root: Int
    var unicode: Bool

    def __init__(out self, pattern: String) raises:
        self.nodes = List[GlobNode]()
        self.pattern = JsString(pattern)
        self.root = 0
        self.unicode = False
        self.root = self._sequence(0, len(self.pattern), 0)

    def _append(mut self, var node: GlobNode) -> Int:
        var result = len(self.nodes)
        self.nodes.append(node^)
        return result

    def _literal(mut self, mut sequence: List[Int], mut units: List[UInt16]):
        if not len(units):
            return
        var expression = String()
        for unit in units:
            expression += escaped_unit(unit)
        var literal = JsString(code_units=units^)
        units = List[UInt16]()
        sequence.append(self._append(GlobNode(literal_kind, expression^, Optional(literal), List[Int]())))

    def _group_end(self, start: Int, limit: Int) raises -> Int:
        var depth = 1
        var index = start
        while index < limit:
            var unit = self.pattern.code_unit_at(index).value()
            if unit == 91:
                var character_class = parse_class(self.pattern, index)
                if character_class:
                    index = character_class.value().end
                    continue
            if _extended(unit) and index + 1 < limit and self.pattern.code_unit_at(index + 1).value() == 40:
                depth += 1
                require_depth(depth)
                index += 2
                continue
            if unit == 41:
                depth -= 1
                if depth == 0:
                    return index
            index += 1
        return -1

    def _alternatives(mut self, start: Int, end: Int, depth: Int) raises -> List[Int]:
        var result = List[Int]()
        var beginning = start
        var index = start
        while index < end:
            var unit = self.pattern.code_unit_at(index).value()
            if unit == 91:
                var character_class = parse_class(self.pattern, index)
                if character_class:
                    index = character_class.value().end
                    continue
            if _extended(unit) and index + 1 < end and self.pattern.code_unit_at(index + 1).value() == 40:
                var closing = self._group_end(index + 2, end)
                if closing >= 0:
                    index = closing + 1
                    continue
            if unit == 124:
                result.append(self._sequence(beginning, index, depth))
                beginning = index + 1
            index += 1
        result.append(self._sequence(beginning, end, depth))
        return result^

    def _sequence(mut self, start: Int, end: Int, depth: Int) raises -> Int:
        require_depth(depth)
        var children = List[Int]()
        var units = List[UInt16]()
        var index = start
        while index < end:
            var unit = self.pattern.code_unit_at(index).value()
            if _extended(unit) and index + 1 < end and self.pattern.code_unit_at(index + 1).value() == 40:
                var closing = self._group_end(index + 2, end)
                if closing >= 0:
                    if index == start and closing + 1 == end and closing == index + 2 and unit != 33:
                        units.append(unit)
                        units.append(40)
                        units.append(41)
                        index = closing + 1
                        continue
                    self._literal(children, units)
                    var alternatives = self._alternatives(index + 2, closing, depth + 1)
                    children.append(self._append(GlobNode(Int(unit), "", None, alternatives^)))
                    index = closing + 1
                    continue
            if unit == 91:
                var character_class = parse_class(self.pattern, index)
                if character_class:
                    var selected = character_class.value()
                    self.unicode = self.unicode or selected.unicode
                    if selected.literal:
                        units.append(selected.literal.value())
                    else:
                        self._literal(children, units)
                        children.append(self._append(GlobNode(class_kind, selected.source, None, List[Int]())))
                    index = selected.end
                    continue
            if unit == 42 or unit == 63:
                self._literal(children, units)
                if unit != 42 or not len(children) or self.nodes[children[len(children) - 1]].kind != 42 or len(self.nodes[children[len(children) - 1]].children):
                    children.append(self._append(GlobNode(Int(unit), "", None, List[Int]())))
            else:
                units.append(unit)
            index += 1
        self._literal(children, units)
        return self._append(GlobNode(sequence_kind, "", None, children^))

    def literal(self) -> Optional[JsString]:
        var units = List[UInt16]()
        for child in self.nodes[self.root].children:
            if self.nodes[child].kind != literal_kind:
                return None
            var text = self.nodes[child].literal.value()
            for index in range(len(text)):
                units.append(text.code_unit_at(index).value())
        return Optional(JsString(code_units=units^))

    def expression(self) raises -> String:
        return self._expression(self.root, "", True, 0)

    def _expression(self, sequence: Int, following: String, beginning: Bool, depth: Int) raises -> String:
        require_depth(depth)
        ref children = self.nodes[sequence].children
        var starts = List[Bool]()
        var at_start = beginning
        for child in children:
            starts.append(at_start)
            if self.nodes[child].kind != 33:
                at_start = False
        var expression = String()
        for position in range(len(children) - 1, -1, -1):
            ref node = self.nodes[children[position]]
            var start = starts[position]
            var part = String()
            if node.kind == literal_kind:
                part = node.expression
                if start and node.literal.value().code_unit_at(0).value() == 46:
                    var literal_dots = len(children) == 1 and (node.literal.value() == JsString(".") or node.literal.value() == JsString(".."))
                    if not literal_dots:
                        part = "(?!\\.\\.?$)" + part
            elif node.kind == class_kind:
                part = ("(?!\\.)" if start else "") + node.expression
            elif not len(node.children):
                if node.kind == 42:
                    part = "[^/]+?" if beginning and len(children) == 1 else "[^/]*?"
                else:
                    part = "[^/]"
                if start:
                    part = "(?!\\.)" + part
            else:
                var continuation = expression + following
                var body = self._group_body(node.children, continuation, start, depth + 1, node.kind == 33)
                if node.kind == 33:
                    if not body:
                        part = "[^/]+?"
                    else:
                        part = "(?!(?:" + body + ")$)[^/]*?"
                    if start:
                        part = "(?!\\.)" + part
                elif node.kind == 64:
                    part = "(?:" + body + ")"
                elif node.kind == 63:
                    part = "(?:" + body + ")?"
                else:
                    var rest = self._group_body(node.children, continuation, False, depth + 1, False)
                    part = "(?:" + body + ")(?:" + rest + ")*?"
                    if node.kind == 42:
                        part = "(?:" + part + ")?"
            expression = part + expression
            require_source_size(expression.byte_length())
        return expression^

    def _group_body(self, children: List[Int], following: String, beginning: Bool, depth: Int, negative: Bool) raises -> String:
        var output = String()
        var alternatives = 0
        for child in children:
            var part = self._expression(child, following, beginning, depth)
            if negative:
                part += following
            if not part:
                continue
            if alternatives:
                output += "|"
            output += part
            alternatives += 1
            require_source_size(output.byte_length())
        return output^
