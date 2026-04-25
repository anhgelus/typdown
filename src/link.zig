const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const Link = Element.Paragraph.Link;
const content = @import("content.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidLink} || Lexer.Error || content.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const data = try parseData(alloc, l);
    const second = data.second orelse return data.first.?;
    var in = if (data.first) |first| first else (try Element.Literal.init(alloc, second)).element();
    errdefer in.deinit(alloc);
    return (try Link.init(alloc, in, data.second.?)).element();
}

pub const Data = struct {
    first: ?Element,
    second: ?[]const u8,
};

pub fn parseData(alloc: Allocator, l: *Lexer) Error!Data {
    const v = l.next().?;
    if (v.kind != .link) return Error.InvalidLink;
    if (!eql(u8, v.content, "[")) {
        const el = try Element.Literal.init(alloc, v.content);
        return .{ .first = el.element(), .second = null };
    }
    var el = try Element.Empty.init(alloc);
    errdefer el.deinit(alloc);
    while (l.peek()) |next| {
        switch (next.kind) {
            .weak_delimiter, .strong_delimiter => return Error.InvalidLink,
            .link => {
                l.consume();
                if (!eql(u8, next.content, "](")) return Error.InvalidLink;
                break;
            },
            else => {
                const in = try content.parse(alloc, l);
                try el.content.append(alloc, in);
            },
        }
    }
    const href = l.next() orelse return Error.InvalidLink;
    if (href.kind != .literal) return Error.InvalidLink;
    const finisher = l.next() orelse return Error.InvalidLink;
    if (!finisher.equals(.link, ")")) return Error.InvalidLink;
    var res = Data{
        .first = el.element(),
        .second = href.content,
    };
    if (el.content.items.len == 0) {
        res.first = null;
        el.deinit(alloc);
    }
    return res;
}

test "parse links" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "[](bar)", "<a href=\"bar\">bar</a>");
    try doTest(parse, alloc, "[foo](bar)", "<a href=\"bar\">foo</a>");
    try doTest(parse, alloc, "[f*o*o](bar)", "<a href=\"bar\">f<b>o</b>o</a>");
    try doTest(parse, alloc, ")", ")");

    try doTestError(parse, alloc, "[foo :::](bar)", Error.IllegalPlacement);
    try doTestError(parse, alloc, "[foo", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo](", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo]()", Error.InvalidLink);
}
