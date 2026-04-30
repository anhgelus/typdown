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
    var content = try Element.Root.init(alloc);
    const v = l.next().?;
    switch (v.kind) {
        .literal => {
            const el = try Element.Literal.init(alloc, v.content);
            content.append(el);
        },
        .bold => content.append(try parseModifier(alloc, l, .bold, "b")),
        .italic => content.append(try parseModifier(alloc, l, .italic, "em")),
        .code => content.append(try parseModifier(alloc, l, .code, "code")),
        .math => content.append(try parseMath(alloc, l)),
        else => return Error.IllegalPlacement,
    }
    return content.element();
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Token.Kind, comptime tag: []const u8) Error!Element {
    var el = try Element.Simple(tag).init(alloc);
    var root = try Element.Root.init(alloc);
    el.content = root.element();
    while (l.peek()) |next| {
        if (next.kind == knd) {
            // consuming the finisher
            l.consume();
            return el.element();
        }
        if (next.kind.isDelimiter()) return Error.ModifierNotClosed;
        root.append(try parse(alloc, l));
    }
    return Error.ModifierNotClosed;
}

fn parseMath(alloc: Allocator, l: *Lexer) Error!Element {
    const el = try Element.Math.Content.init(alloc);
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    while (l.next()) |it| {
        if (it.kind == .math) {
            el.content = try acc.toOwnedSlice(alloc);
            return el.element();
        }
        if (it.kind.isDelimiter()) return Error.ModifierNotClosed;
        try acc.appendSlice(alloc, it.content);
    }
    return Error.ModifierNotClosed;
}
