const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const html = @import("html.zig");
const Element = @import("Element.zig");
const Error = Element.Error;

literal: []const u8,

const Self = @This();

pub fn init(alloc: Allocator, literal: []const u8) Error!*Element.Literal {
    const v = try alloc.create(Self);
    v.* = .{ .literal = try html.escape(alloc, literal) };
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .render = Self.render }, .ptr = self };
}

fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    return try alloc.dupe(u8, self.literal);
}
