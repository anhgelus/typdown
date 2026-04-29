const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const Paragraph = Element.paragraph;
const parser = @import("parser.zig");
const link = @import("link.zig");
const content = @import("content.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = content.Error || link.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var el = try Paragraph.Block.init(alloc);
    var root = try Element.Root.init(alloc);
    el.content = root.element();
    while (l.peek()) |next| switch (next.kind) {
        .strong_delimiter => return el.element(),
        .weak_delimiter => {
            l.consume();
            const future = l.peek() orelse return el.element();
            if (!future.kind.isInParagraph()) return el.element();
            root.append((try Element.Literal.init(alloc, " ")).element());
        },
        else => root.append(try parseLine(alloc, l)),
    };
    return el.element();
}

pub fn parseLine(alloc: Allocator, l: *Lexer) Error!Element {
    var line = try Element.Root.init(alloc);
    while (l.peek()) |next| switch (next.kind) {
        .weak_delimiter, .strong_delimiter => return line.element(),
        .link => line.append(try link.parse(alloc, l)),
        else => line.append(try content.parse(alloc, l)),
    };
    return line.element();
}

test "parse paragraphs" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "hello world", "<p>hello world</p>");
    try doTest(parse, alloc, "*hello* world", "<p><b>hello</b> world</p>");
    try doTest(parse, alloc, "*he_ll_o* world", "<p><b>he<em>ll</em>o</b> world</p>");
    try doTest(parse, alloc, "(foo)", "<p>(foo)</p>");
    try doTest(parse, alloc, "[](bar)", "<p><a href=\"bar\">bar</a></p>");
    try doTest(parse, alloc, "[foo](bar)", "<p><a href=\"bar\">foo</a></p>");
    try doTest(parse, alloc, "hello [foo](bar) world", "<p>hello <a href=\"bar\">foo</a> world</p>");
    try doTest(parse, alloc, "$x$", "<p>" ++ @embedFile("data/test_content_1.svg") ++ "</p>");
    try doTest(parse, alloc, "$x^2$", "<p>" ++ @embedFile("data/test_content_2.svg") ++ "</p>");

    try doTestError(parse, alloc, "hello *world", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "hello *wo_rld*", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "*hell*o *wo_rld*", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "hello wo$rld", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "hello ::: world", Error.IllegalPlacement);
}
