const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const parser = @import("parser.zig");
const testing = @import("testing.zig");

pub const Error = error{ ModifierNotClosed, IllegalPlacement } || Lexer.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var el = try Element.init(alloc, .content, "p");
    errdefer el.deinit();
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
            else => try el.appendContent(try parseLine(alloc, l)),
        }
    }
    return el;
}

pub fn parseLine(alloc: Allocator, l: *Lexer) Error!Element {
    var content = Element.initEmpty(alloc);
    errdefer content.deinit();
    while (l.nextKind()) |kind| {
        switch (kind) {
            .weak_delimiter, .strong_delimiter => return content,
            else => {
                const el = try parseContent(alloc, l);
                try content.appendContent(el);
            },
        }
    }
    return content;
}

fn parseContent(alloc: Allocator, l: *Lexer) Error!Element {
    var content = Element.initEmpty(alloc);
    errdefer content.deinit();
    var v = (try l.next(alloc)).?;
    defer v.deinit();
    switch (v.kind) {
        .literal => {
            const el = try Element.initLitEscaped(alloc, v.content.items);
            try content.appendContent(el);
        },
        .bold => try content.appendContent(try parseModifier(alloc, l, .bold, "b")),
        .italic => try content.appendContent(try parseModifier(alloc, l, .italic, "em")),
        .code => try content.appendContent(try parseModifier(alloc, l, .code, "code")),
        else => return Error.IllegalPlacement,
    }
    return content;
}

fn parseModifier(alloc: Allocator, l: *Lexer, knd: Lexed.Kind, tag: []const u8) Error!Element {
    var el = try Element.init(alloc, .content, tag);
    errdefer el.deinit();
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

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    return testing.do(parse, alloc, t, v);
}

fn doTestError(alloc: Allocator, t: []const u8, err: Error) !void {
    return testing.doError(parse, alloc, t, err);
}

test "parse paragraphs" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "hello world", "<p>hello world</p>");
    try doTest(alloc, "*hello* world", "<p><b>hello</b> world</p>");
    try doTest(alloc, "*he_ll_o* world", "<p><b>he<em>ll</em>o</b> world</p>");

    try doTestError(alloc, "hello *world", Error.ModifierNotClosed);
    try doTestError(alloc, "hello *wo_rld*", Error.ModifierNotClosed);
    try doTestError(alloc, "*hell*o *wo_rld*", Error.ModifierNotClosed);
    try doTestError(alloc, "hello ::: world", Error.IllegalPlacement);
}
