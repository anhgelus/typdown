const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidCodeBlock} || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    _ = l.next();
    var beg = l.next() orelse return Error.InvalidCodeBlock;
    var data: ?[]const u8 = null;
    switch (beg.kind) {
        .literal => {
            data = beg.content;
            beg = l.next() orelse return Error.InvalidCodeBlock;
            if (!beg.kind.isDelimiter()) return Error.InvalidCodeBlock;
        },
        else => if (!beg.kind.isDelimiter()) return Error.InvalidCodeBlock,
    }
    const code = try Element.Code.init(alloc);
    code.attribute = data;
    while (l.next()) |it| {
        if (it.kind == .code_block) return Error.InvalidCodeBlock;
        if (it.kind.isDelimiter()) {
            const next = l.peek() orelse return Error.InvalidCodeBlock;
            if (next.kind == .code_block) break;
        }
        try code.content.append(alloc, (try Element.Literal.init(alloc, it.content)).element());
        // restore modifications done by the lexer
        if (it.kind.requiresSpace())
            try code.content.append(alloc, (try Element.Literal.init(alloc, " ")).element());
    }
    var end = l.next() orelse return Error.InvalidCodeBlock;
    if (end.kind != .code_block) return Error.InvalidCodeBlock;
    const el = try Element.Figure.init(alloc, code.element());
    end = l.next() orelse return el.element();
    if (!end.kind.isDelimiter()) return Error.InvalidCodeBlock;
    return el.element();
}

test "code" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc,
        \\```
        \\hey
        \\```
    , "<figure><pre><code>hey</code></pre></figure>");
    try doTest(parse, alloc,
        \\```td another
        \\hey
        \\```
    , "<figure><pre data-code=\"td another\"><code>hey</code></pre></figure>");
    // cannot test content with \n

    try doTestError(parse, alloc, "```", Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey
    , Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey```
    , Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey
        \\``` nope
    , Error.InvalidCodeBlock);
}
