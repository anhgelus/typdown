const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexed = @import("lexer/Lexed.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const paragraph = @import("paragraph.zig");

pub const Error = error{InvalidTitleContent} || paragraph.Error || Lexer.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    var v = (try l.next(alloc)).?;
    var el = try Element.init(alloc, .content, switch (v.content.items.len) {
        1 => "h1",
        2 => "h2",
        3 => "h3",
        4 => "h4",
        5 => "h5",
        6 => "h6",
        else => unreachable,
    });
    try el.appendContent(paragraph.parseLine(alloc, l) catch |err| switch (err) {
        paragraph.Error.IllegalPlacement => return Error.InvalidTitleContent,
        else => return err,
    });
    v = (try l.next(alloc)) orelse return el;
    if (!v.kind.isDelimiter()) return Error.InvalidTitleContent;
    v.deinit();
    return el;
}
