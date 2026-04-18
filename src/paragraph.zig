const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const parser = @import("parser.zig");

pub const Error = error{ModifierNotClosed} || Lexer.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var el = try Element.init(alloc, .content, "p");
    while (l.nextKind()) |kind| {
        switch (kind) {
            // because nextKind returns only an hint for the next rune
            .weak_delimiter => {
                var v = (try l.next(alloc)).?;
                defer v.deinit();
                if (v.kind == .strong_delimiter) return el;
                const next = l.nextKind() orelse return el;
                switch (next) {
                    .literal, .italic, .code, .bold => try el.appendContent(try Element.initLit(alloc, " ")),
                    else => return el,
                }
            },
            else => try el.appendContent(try parseContent(alloc, l)),
        }
    }
    return el;
}

pub fn parseContent(alloc: Allocator, l: *Lexer) Error!Element {
    var content = Element.initEmpty(alloc);
    const v = (try l.next(alloc)).?;
    switch (v.kind) {
        .literal => {
            const el = try Element.initLitEscaped(alloc, v.content.items);
            try content.appendContent(el);
        },
        .bold => try content.appendContent(try parseModifier(alloc, l, .bold, "b")),
        .italic => try content.appendContent(try parseModifier(alloc, l, .italic, "em")),
        .code => try content.appendContent(try parseModifier(alloc, l, .code, "code")),
        else => unreachable,
    }
    return content;
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Lexed.Kind, tag: []const u8) Error!Element {
    var el = try Element.init(alloc, .content, tag);
    while (l.nextKind()) |it| {
        if (it == knd) {
            // consuming the finisher
            var v = (try l.next(alloc)).?;
            v.deinit();
            return el;
        }
        if (it.isDelimiter()) return Error.ModifierNotClosed;
        try el.appendContent(try parseContent(alloc, l));
    }
    return Error.ModifierNotClosed;
}
