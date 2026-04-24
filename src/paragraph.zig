const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const parser = @import("parser.zig");
const link = @import("link.zig");
const content = @import("content.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = content.Error || link.Error || Lexer.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var el = try Element.init(alloc, .content, "p");
    errdefer el.deinit();
    while (l.nextKind()) |kind| {
        switch (kind) {
            // because nextKind returns only an hint for the next rune
            .weak_delimiter => {
                const v = l.next().?;
                if (v.kind == .strong_delimiter) return el;
                const next = l.nextKind() orelse return el;
                switch (next) {
                    .literal, .italic, .code, .bold, .link => try el.appendContent(try Element.initLit(alloc, " ")),
                    else => return el,
                }
            },
            else => try el.appendContent(try parseLine(alloc, l)),
        }
    }
    return el;
}

pub fn parseLine(alloc: Allocator, l: *Lexer) Error!Element {
    var line = Element.initEmpty(alloc);
    errdefer line.deinit();
    while (l.nextKind()) |kind| {
        switch (kind) {
            .weak_delimiter, .strong_delimiter => return line,
            .link => {
                var el = try link.parse(alloc, l);
                errdefer el.deinit();
                try line.appendContent(el);
            },
            else => {
                var el = try content.parse(alloc, l);
                errdefer el.deinit();
                try line.appendContent(el);
            },
        }
    }
    return line;
}

test "parse paragraphs" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(parse, alloc, "hello world", "<p>hello world</p>");
    try doTest(parse, alloc, "*hello* world", "<p><b>hello</b> world</p>");
    try doTest(parse, alloc, "*he_ll_o* world", "<p><b>he<em>ll</em>o</b> world</p>");
    try doTest(parse, alloc, "(foo)", "<p>(foo)</p>");
    try doTest(parse, alloc, "[](bar)", "<p><a href=\"bar\">bar</a></p>");
    try doTest(parse, alloc, "[foo](bar)", "<p><a href=\"bar\">foo</a></p>");
    try doTest(parse, alloc, "hello [foo](bar) world", "<p>hello <a href=\"bar\">foo</a> world</p>");

    try doTestError(parse, alloc, "hello *world", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "hello *wo_rld*", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "*hell*o *wo_rld*", Error.ModifierNotClosed);
    try doTestError(parse, alloc, "hello ::: world", Error.IllegalPlacement);
}
