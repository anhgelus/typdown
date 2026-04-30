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

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const root = try Element.Root.init(alloc);
    while (l.peek()) |next| switch (next.kind) {
        .quote => {
            l.consume();
            continue;
        },
        .weak_delimiter => {
            l.consume();
            if (l.peek()) |it| if (it.kind != .quote) break;
            root.append(try Element.Literal.init(alloc, " "));
            continue;
        },
        .strong_delimiter => break,
        else => root.append(try paragraph.parseLine(alloc, l)),
    };
    const quote = try Element.Quote.init(alloc, root.element());
    const el = try Element.Figure.init(alloc, quote.element());
    const v = l.peek() orelse return el.element();
    if (v.kind == .strong_delimiter) {
        l.consume();
        return el.element();
    }
    const attr = try paragraph.parse(alloc, l);
    const p_el: *Element.paragraph.Block = @ptrCast(@alignCast(attr.ptr));
    el.caption = (try p_el.toRoot(alloc)).element();
    return el.element();
}

test {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "> hello world", "<figure><blockquote>hello world</blockquote></figure>");
    try doTest(parse, alloc, ">hello world", "<figure><blockquote>hello world</blockquote></figure>");
    try doTest(parse, alloc, ">   hello world", "<figure><blockquote>hello world</blockquote></figure>");

    try doTest(parse, alloc,
        \\> hello
        \\>world
    , "<figure><blockquote>hello world</blockquote></figure>");
    try doTest(parse, alloc,
        \\> hello
        \\>world
        \\attribution sur
        \\plusieurs lignes
    , "<figure><blockquote>hello world</blockquote><figcaption>attribution sur plusieurs lignes</figcaption></figure>");
}
