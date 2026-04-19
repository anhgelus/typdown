const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");

pub const Error = error{InvalidTitleContent} || paragraph.Error || Lexer.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var v = (try l.next(alloc)).?;
    defer v.deinit();
    var el = try Element.init(alloc, .content, switch (v.content.items.len) {
        1 => "h1",
        2 => "h2",
        3 => "h3",
        4 => "h4",
        5 => "h5",
        6 => "h6",
        else => unreachable,
    });
    errdefer el.deinit();
    try el.appendContent(paragraph.parseLine(alloc, l) catch |err| switch (err) {
        paragraph.Error.IllegalPlacement => return Error.InvalidTitleContent,
        else => return err,
    });
    var next = (try l.next(alloc)) orelse return el;
    defer next.deinit();
    if (!next.kind.isDelimiter()) return Error.InvalidTitleContent;
    return el;
}

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    return testing.do(parse, alloc, t, v);
}

fn doTestError(alloc: Allocator, t: []const u8, err: Error) !void {
    return testing.doError(parse, alloc, t, err);
}

test "parse title" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "# hey", "<h1>hey</h1>");
    try doTest(alloc, "## hey", "<h2>hey</h2>");
    try doTest(alloc, "### hey", "<h3>hey</h3>");

    try doTest(alloc, "# hello *world*", "<h1>hello <b>world</b></h1>");

    try doTestError(alloc, "# aa :::", Error.InvalidTitleContent);
}
