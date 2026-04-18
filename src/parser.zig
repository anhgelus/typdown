const std = @import("std");
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const Allocator = std.mem.Allocator;
const paragraph = @import("paragraph.zig");

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
            .literal, .bold, .italic, .code => try elements.append(alloc, try paragraph.parseParagraph(alloc, &l)),
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

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    const g = try parse(alloc, t);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("{s}\n", .{g});
        return err;
    };
}

test "parse paragraphs" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "hello world", "<p>hello world</p>");
    try doTest(alloc, "*hello* world", "<p><b>hello</b> world</p>");
    try doTest(alloc, "*he_ll_o* world", "<p><b>he<em>ll</em>o</b> world</p>");

    try doTest(alloc,
        \\hello
        \\world
        \\
        \\foo bar
        \\in new paragraph
    , "<p>hello world</p><p>foo bar in new paragraph</p>");
}
