const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidTitleContent} || paragraph.Error || Lexer.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const v = l.next().?;
    var el = try Element.init(alloc, .content, switch (v.content.len) {
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
    var next = l.next() orelse return el;
    if (!next.kind.isDelimiter()) return Error.InvalidTitleContent;
    return el;
}

test "parse title" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(parse, alloc, "# hey", "<h1>hey</h1>");
    try doTest(parse, alloc, "## hey", "<h2>hey</h2>");
    try doTest(parse, alloc, "### hey", "<h3>hey</h3>");

    try doTest(parse, alloc, "# hello *world*", "<h1>hello <b>world</b></h1>");

    try doTestError(parse, alloc, "# aa :::", Error.InvalidTitleContent);
}
