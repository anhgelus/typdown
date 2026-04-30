const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const testing = @import("testing.zig");
const doTest = testing.doMath;
const doTestError = testing.doError;

pub const Error = error{InvalidMathBlock} || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    _ = l.next();
    const beg = l.next() orelse return Error.InvalidMathBlock;
    if (!beg.kind.isDelimiter()) return Error.InvalidMathBlock;
    const math = try Element.Math.Block.init(alloc);
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    while (l.next()) |it| {
        if (it.kind == .math_block) return Error.InvalidMathBlock;
        try acc.appendSlice(alloc, it.content);
        // restore modifications done by the lexer
        if (it.kind.requiresSpace())
            try acc.append(alloc, ' ');
        if (it.kind.isDelimiter()) {
            const next = l.peek() orelse return Error.InvalidMathBlock;
            if (next.kind == .math_block) break;
        }
    }
    var end = l.next() orelse return Error.InvalidMathBlock;
    if (end.kind != .math_block) return Error.InvalidMathBlock;
    const el = try Element.Figure.init(alloc, math.element());
    math.content = try acc.toOwnedSlice(alloc);
    end = l.next() orelse return el.element();
    if (!end.kind.isDelimiter()) return Error.InvalidMathBlock;
    return el.element();
}

test {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc,
        \\$$$
        \\x
        \\$$$
    , "<figure>" ++ @embedFile("data/test_block_1.svg") ++ "</figure>");
    try doTest(parse, alloc,
        \\$$$
        \\x^2
        \\$$$
    , "<figure>" ++ @embedFile("data/test_block_2.svg") ++ "</figure>");
    try doTest(parse, alloc,
        \\$$$
        \\forall x in RR, quad f(x) = x^2
        \\$$$
    , "<figure>" ++ @embedFile("data/test_block_3.svg") ++ "</figure>");
}
