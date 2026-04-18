const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");
const title = @import("title.zig");

pub const Error = error{
    FeatureNotSupported,
} || Lexer.Error || paragraph.Error || title.Error;

pub fn parse(parent: Allocator, content: []const u8) Error![]const u8 {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    const alloc = arena.allocator();

    var elements = try std.ArrayList(Element).initCapacity(alloc, 2);

    var l = try Lexer.init(content);
    base: while (l.nextKind()) |it| {
        try elements.append(alloc, switch (it) {
            .literal, .bold, .italic, .code => try paragraph.parse(alloc, &l),
            .title => try title.parse(alloc, &l),
            .weak_delimiter, .strong_delimiter => {
                var v = (try l.next(alloc)).?;
                v.deinit();
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

fn doTestError(alloc: Allocator, t: []const u8, err: Error) !void {
    _ = parse(alloc, t) catch |e| return std.testing.expect(err == e);
    return std.testing.expect(false);
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

    try doTestError(alloc, "hello *world", Error.ModifierNotClosed);
    try doTestError(alloc, "hello *wo_rld*", Error.ModifierNotClosed);
    try doTestError(alloc, "*hell*o *wo_rld*", Error.ModifierNotClosed);
}

test "parse title" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "# hey", "<h1>hey</h1>");
    try doTest(alloc, "## hey", "<h2>hey</h2>");
    try doTest(alloc, "### hey", "<h3>hey</h3>");

    try doTest(alloc,
        \\# title
        \\hello world ;3
        \\## subtitle
        \\hehe
    , "<h1>title</h1><p>hello world ;3</p><h2>subtitle</h2><p>hehe</p>");

    try doTestError(alloc, "# aa :::", Error.InvalidTitleContent);
}
