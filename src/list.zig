const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = paragraph.Error || Allocator.Error;

pub fn parseOrdored(alloc: Allocator, l: *Lexer) Error!Element {
    const el = try Element.list.Ordored.init(alloc);
    errdefer el.deinit(alloc);
    try parse(alloc, &el.content, l, .list_ordored);
    return el.element();
}

pub fn parseUnordored(alloc: Allocator, l: *Lexer) Error!Element {
    const el = try Element.list.Unordored.init(alloc);
    errdefer el.deinit(alloc);
    try parse(alloc, &el.content, l, .list_unordored);
    return el.element();
}

fn parse(alloc: Allocator, content: *std.ArrayList(Element), l: *Lexer, comptime kind: Token.Kind) !void {
    while (l.peek()) |next| switch (next.kind) {
        kind => {
            l.consume();
            continue;
        },
        .weak_delimiter => {
            l.consume();
            if (l.peek()) |it| if (it.kind != kind) return;
            continue;
        },
        .strong_delimiter => return,
        else => try content.append(alloc, try paragraph.parseLine(alloc, l)),
    };
}

test "parse ordored list" {
    const alloc = std.testing.allocator;

    try doTest(parseOrdored, alloc,
        \\. one
        \\. two
    , "<ol><li>one</li><li>two</li></ol>");
    try doTest(parseOrdored, alloc,
        \\. one
        \\. two
        \\no more
    , "<ol><li>one</li><li>two</li></ol>");

    try doTestError(parseOrdored, alloc, ".one :::", Error.IllegalPlacement);
}

test "parse unordored list" {
    const alloc = std.testing.allocator;

    try doTest(parseUnordored, alloc,
        \\- one
        \\- two
    , "<ul><li>one</li><li>two</li></ul>");
    try doTest(parseUnordored, alloc,
        \\- one
        \\- two
        \\no more
    , "<ul><li>one</li><li>two</li></ul>");

    try doTestError(parseOrdored, alloc, "- one :::", Error.IllegalPlacement);
}
