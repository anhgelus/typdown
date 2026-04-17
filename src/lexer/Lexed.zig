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

gpa: Allocator,
kind: Kind,
content: std.ArrayList(u8),

const Self = @This();

pub fn init(gpa: Allocator, kind: Kind, content: std.ArrayList(u8)) Self {
    return .{
        .gpa = gpa,
        .kind = kind,
        .content = content,
    };
}

pub fn deinit(self: *Self) void {
    self.content.deinit(self.gpa);
}

pub fn clone(self: *const Self, gpa: Allocator) Allocator.Error!std.ArrayList(u8) {
    return self.content.clone(gpa);
}

pub fn equals(self: *const Self, kind: Kind, content: []const u8) bool {
    if (self.kind != kind) return false;
    return std.mem.eql(u8, self.content.items, content);
}
