const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const Link = Element.paragraph.Link;
const content = @import("content.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidLink} || content.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const v = l.next().?;
    if (v.kind != .link) return Error.InvalidLink;
    if (!eql(u8, v.content, "[")) return (try Element.Literal.init(alloc, v.content)).element();
    var el = try Element.Root.init(alloc);
    l.isValid();
    while (l.peek()) |next| switch (next.kind) {
        .weak_delimiter, .strong_delimiter => return Error.InvalidLink,
        .link => {
            l.consume();
            if (!eql(u8, next.content, "](")) return Error.InvalidLink;
            break;
        },
        else => el.append(try content.parse(el.allocator(), l)),
    };
    l.isValid();
    const href = l.next() orelse return Error.InvalidLink;
    if (href.kind != .literal) return Error.InvalidLink;
    l.isValid();
    const finisher = l.next() orelse return Error.InvalidLink;
    if (!finisher.equals(.link, ")")) return Error.InvalidLink;
    const in: Element = if (el.content.first != null)
        el.element()
    else blk: {
        el.deinit();
        break :blk (try Element.Literal.init(alloc, href.content)).element();
    };
    return (try Link.init(alloc, in, href.content)).element();
}

test "parse links" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "[](bar)", "<a href=\"bar\">bar</a>");
    try doTest(parse, alloc, "[foo](bar)", "<a href=\"bar\">foo</a>");
    try doTest(parse, alloc, "[f*o*o](bar)", "<a href=\"bar\">f<b>o</b>o</a>");
    try doTest(parse, alloc, ")", ")");

    try doTestError(parse, alloc, "[foo", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo](", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo]()", Error.InvalidLink);
}
