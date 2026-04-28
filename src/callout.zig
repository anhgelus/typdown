const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const testing = @import("testing.zig");
const paragraph = @import("paragraph.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidCallout} || paragraph.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    _ = l.next();
    var beg = l.next() orelse return Error.InvalidCallout;
    var kind: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    switch (beg.kind) {
        .literal => {
            var iter = std.mem.splitAny(u8, beg.content, " ");
            kind = iter.first();
            if (iter.peek() != null) title = iter.buffer[iter.index.?..];
            beg = l.next() orelse return Error.InvalidCallout;
            if (!beg.kind.isDelimiter()) return Error.InvalidCallout;
        },
        else => if (!beg.kind.isDelimiter()) return Error.InvalidCallout,
    }
    var root = try Element.Root.init(alloc);
    while (l.peek()) |it| {
        if (it.kind == .callout) {
            l.consume();
            break;
        }
        if (it.kind.isDelimiter()) {
            const next = l.peek() orelse return Error.InvalidCallout;
            if (next.kind == .callout) {
                l.consume();
                break;
            }
        }
        root.append(try paragraph.parse(root.allocator(), l));
        _ = l.peek() orelse return Error.InvalidCallout;
    }
    var el = try Element.Callout.init(alloc, root.element());
    el.kind = kind;
    el.title = title;
    const end = l.next() orelse return el.element();
    if (!end.kind.isDelimiter()) return Error.InvalidCallout;
    return el.element();
}

test "callout" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc,
        \\:::
        \\hey
        \\:::
    , "<div class=\"callout\"><p>hey</p></div>");
    try doTest(parse, alloc,
        \\:::info
        \\hey
        \\:::
    , "<div data-callout=\"info\" class=\"callout\"><p>hey</p></div>");
    try doTest(parse, alloc,
        \\::: info Title
        \\hey
        \\:::
    , "<div data-callout=\"info\" class=\"callout\"><p>hey</p></div>");
    // cannot test content with \n

    try doTestError(parse, alloc, ":::", Error.InvalidCallout);
    try doTestError(parse, alloc,
        \\:::
        \\hey
    , Error.InvalidCallout);
    try doTestError(parse, alloc,
        \\:::
        \\hey:::
    , Error.IllegalPlacement);
    try doTestError(parse, alloc,
        \\:::
        \\hey
        \\::: nope
    , Error.InvalidCallout);
}
