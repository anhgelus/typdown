const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Kind = enum {
    literal,
    delimiter,
    title,
    quote,
    code,
    code_block,
    math,
    math_block,
    image,
    link,
    bold,
    italic,
    ref,
    callout,
    list_ordored,
    list_unordored,
    tag,
};

allocator: Allocator,
kind: Kind,
content: std.ArrayList(u8),

const Self = @This();

pub fn init(alloc: Allocator, kind: Kind, content: std.ArrayList(u8)) Self {
    return .{
        .allocator = alloc,
        .kind = kind,
        .content = content,
    };
}

pub fn deinit(self: *Self) void {
    self.content.deinit(self.allocator);
}

pub fn clone(self: *const Self, alloc: Allocator) Allocator.Error!std.ArrayList(u8) {
    return self.content.clone(alloc);
}

pub fn equals(self: *const Self, kind: Kind, content: []const u8) bool {
    if (self.kind != kind) return false;
    return std.mem.eql(u8, self.content.items, content);
}
