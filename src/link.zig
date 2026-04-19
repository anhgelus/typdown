const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidLink} || Lexer.Error || paragraph.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var el = try Element.init(alloc, .content, "a");
    errdefer el.deinit();
    const data = try parseData(alloc, l);
    const second = data.second orelse {
        el.deinit();
        return data.first.?;
    };
    defer alloc.free(second);
    var content = if (data.first) |first| first else try Element.initLitEscaped(alloc, second);
    errdefer content.deinit();
    try el.appendContent(content);
    try el.setAttribute("href", second);
    return el;
}

pub const Data = struct {
    first: ?Element,
    second: ?[]const u8,
};

pub fn parseData(alloc: Allocator, l: *Lexer) Error!Data {
    var el = Element.initEmpty(alloc);
    errdefer el.deinit();
    var v = (try l.next(alloc)).?;
    defer v.deinit();
    if (v.kind != .link) return Error.InvalidLink;
    if (!eql(u8, v.content.items, "[")) {
        const first = try Element.initLitEscaped(alloc, v.content.items);
        el.deinit();
        return .{ .first = first, .second = null };
    }
    while (l.nextKind()) |kind| {
        switch (kind) {
            .weak_delimiter, .strong_delimiter => return Error.InvalidLink,
            .link => {
                var next = (try l.next(alloc)).?;
                defer next.deinit();
                if (!eql(u8, next.content.items, "](")) return Error.InvalidLink;
                break;
            },
            else => {
                const content = try paragraph.parseContent(alloc, l);
                try el.appendContent(content);
            },
        }
    }
    var href = try l.next(alloc) orelse return Error.InvalidLink;
    defer href.deinit();
    if (href.kind != .literal) return Error.InvalidLink;
    var finisher = try l.next(alloc) orelse return Error.InvalidLink;
    defer finisher.deinit();
    if (finisher.kind != .link or !eql(u8, finisher.content.items, ")")) return Error.InvalidLink;
    return .{
        .first = if (el.content.items.len > 0) el else null,
        .second = try href.content.toOwnedSlice(alloc),
    };
}

test "parse links" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(parse, alloc, "[](bar)", "<a href=\"bar\">bar</a>");
    try doTest(parse, alloc, "[foo](bar)", "<a href=\"bar\">foo</a>");
    try doTest(parse, alloc, "[f*o*o](bar)", "<a href=\"bar\">f<b>o</b>o</a>");
    try doTest(parse, alloc, ")", ")");

    try doTestError(parse, alloc, "[foo :::](bar)", Error.IllegalPlacement);
    try doTestError(parse, alloc, "[foo", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo](", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo]()", Error.InvalidLink);
}
