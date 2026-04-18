const std = @import("std");
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const Allocator = std.mem.Allocator;

pub const Error = error{
    InvalidSequence,
    UnclosedModifier,
    FeatureNotSupported,
} || Lexer.Error;

pub fn parse(parent: Allocator, content: []const u8) Error![]const u8 {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    const alloc = arena.allocator();

    var elements = try std.ArrayList(Element).initCapacity(alloc, 2);

    var l = try Lexer.init(content);
    while (l.nextKind()) |it| {
        switch (it) {
            .literal, .bold, .italic, .code => try elements.append(alloc, try parseContent(alloc, &l)),
            else => return Error.FeatureNotSupported,
        }
    }

    var res = try std.ArrayList(u8).initCapacity(parent, elements.items.len);
    for (elements.items) |it| {
        var v = it;
        try res.appendSlice(parent, try v.render(alloc));
    }
    return res.toOwnedSlice(parent);
}

fn parseContent(alloc: Allocator, l: *Lexer) Error!Element {
    var content = Element.initEmpty(alloc);
    const v = (try l.next(alloc)).?;
    switch (v.kind) {
        .literal => {
            const el = try Element.initLitEscaped(alloc, v.content.items);
            try content.appendContent(el);
        },
        .bold => try content.appendContent(try parseModifier(alloc, l, .bold, "b")),
        .italic => try content.appendContent(try parseModifier(alloc, l, .italic, "em")),
        .code => try content.appendContent(try parseModifier(alloc, l, .code, "code")),
        else => return Error.InvalidSequence,
    }
    return content;
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Lexed.Kind, tag: []const u8) Error!Element {
    var el = try Element.init(alloc, .content, tag);
    while (l.nextKind()) |it| {
        if (it == knd) {
            // consuming the finisher
            var v = (try l.next(alloc)).?;
            v.deinit();
            break;
        }
        if (it.isDelimiter()) return Error.UnclosedModifier;
        try el.appendContent(try parseContent(alloc, l));
    }
    return el;
}

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    const g = try parse(alloc, t);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("{s}\n", .{g});
        return err;
    };
}

test "parse content" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "hello world", "hello world");
    try doTest(alloc, "*hello* world", "<b>hello</b> world");
    try doTest(alloc, "*he_ll_o* world", "<b>he<em>ll</em>o</b> world");
}
