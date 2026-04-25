const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");
const title = @import("title.zig");
const link = @import("link.zig");

pub const Error = error{
    FeatureNotSupported,
} || Lexer.Error || paragraph.Error || title.Error || link.Error || Allocator.Error;

pub fn parseReader(parent: Allocator, r: *std.io.Reader) ![]const u8 {
    var l = try Lexer.initReader(parent, r);
    defer parent.free(l.iter.bytes);
    return gen(parent, &l);
}

pub fn parse(parent: Allocator, content: []const u8) Error![]const u8 {
    var l = try Lexer.init(content);
    return gen(parent, &l);
}

fn gen(parent: Allocator, l: *Lexer) Error![]const u8 {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    const alloc = arena.allocator();

    var elements = try std.ArrayList(Element).initCapacity(alloc, 2);

    base: while (l.peek()) |it| {
        try elements.append(alloc, switch (it.kind) {
            // block paragraph
            .literal, .bold, .italic, .code, .link => try paragraph.parse(alloc, l),
            // other blocks
            .title => try title.parse(alloc, l),
            .weak_delimiter, .strong_delimiter => {
                l.consume();
                continue :base;
            },
            else => return Error.FeatureNotSupported,
        });
    }

    var res = try std.ArrayList(u8).initCapacity(parent, elements.items.len);
    errdefer res.deinit(parent);
    for (elements.items) |it| {
        var v = it;
        try res.appendSlice(parent, try v.render(alloc));
    }
    return res.toOwnedSlice(parent);
}

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    const g = try parse(alloc, t);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("{s}\n", .{g});
        return err;
    };
}

test "parse multilines" {
    const alloc = std.testing.allocator;

    try doTest(alloc,
        \\hello
        \\world
        \\
        \\foo bar
        \\in new paragraph
    , "<p>hello world</p><p>foo bar in new paragraph</p>");

    try doTest(alloc,
        \\# title
        \\hello world ;3
        \\## subtitle
        \\hehe
    , "<h1>title</h1><p>hello world ;3</p><h2>subtitle</h2><p>hehe</p>");
}
