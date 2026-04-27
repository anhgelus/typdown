const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const parser = @import("parser.zig");
const link = @import("link.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{ ModifierNotClosed, IllegalPlacement } || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var content = try Element.Empty.init(alloc);
    const v = l.next().?;
    switch (v.kind) {
        .literal => {
            const el = try Element.Literal.init(alloc, v.content);
            try content.content.append(alloc, el.element());
        },
        .bold => try content.content.append(alloc, try parseModifier(alloc, l, .bold, "b")),
        .italic => try content.content.append(alloc, try parseModifier(alloc, l, .italic, "em")),
        .code => try content.content.append(alloc, try parseModifier(alloc, l, .code, "code")),
        else => return Error.IllegalPlacement,
    }
    return content.element();
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Token.Kind, comptime tag: []const u8) Error!Element {
    var el = try Element.Simple(tag).init(alloc);
    while (l.peek()) |next| {
        if (next.kind == knd) {
            // consuming the finisher
            l.consume();
            return el.element();
        }
        if (next.kind.isDelimiter()) return Error.ModifierNotClosed;
        try el.content.append(alloc, try parse(alloc, l));
    }
    return Error.ModifierNotClosed;
}
