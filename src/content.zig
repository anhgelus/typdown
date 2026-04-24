const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const parser = @import("parser.zig");
const link = @import("link.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{ ModifierNotClosed, IllegalPlacement } || Lexer.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var content = Element.initEmpty(alloc);
    errdefer content.deinit();
    const v = l.next().?;
    switch (v.kind) {
        .literal => {
            const el = try Element.initLitEscaped(alloc, v.content);
            try content.appendContent(el);
        },
        .bold => try content.appendContent(try parseModifier(alloc, l, .bold, "b")),
        .italic => try content.appendContent(try parseModifier(alloc, l, .italic, "em")),
        .code => try content.appendContent(try parseModifier(alloc, l, .code, "code")),
        else => return Error.IllegalPlacement,
    }
    return content;
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Token.Kind, tag: []const u8) Error!Element {
    var el = try Element.init(alloc, .content, tag);
    errdefer el.deinit();
    while (l.peek()) |next| {
        if (next.kind == knd) {
            // consuming the finisher
            l.consume();
            return el;
        }
        if (next.kind.isDelimiter()) return Error.ModifierNotClosed;
        try el.appendContent(try parse(alloc, l));
    }
    return Error.ModifierNotClosed;
}
