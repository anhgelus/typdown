const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidTitleContent} || paragraph.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const v = l.next().?;
    const el = try Element.Title.init(alloc, @intCast(v.content.len), paragraph.parseLine(alloc, l) catch |err| switch (err) {
        paragraph.Error.IllegalPlacement => return Error.InvalidTitleContent,
        else => return err,
    });
    var next = l.next() orelse return el.element();
    if (!next.kind.isDelimiter()) return Error.InvalidTitleContent;
    return el.element();
}

test "parse title" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "# hey", "<h1>hey</h1>");
    try doTest(parse, alloc, "## hey", "<h2>hey</h2>");
    try doTest(parse, alloc, "### hey", "<h3>hey</h3>");

    try doTest(parse, alloc, "# hello *world*", "<h1>hello <b>world</b></h1>");

    try doTestError(parse, alloc, "# aa :::", Error.InvalidTitleContent);
}
