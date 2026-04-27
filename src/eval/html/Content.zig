const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Element = @import("Element.zig");
const Error = Element.Error;

base: Element.Void,
content: List(Element),

pub const Self = @This();

pub fn init(alloc: Allocator, tag: []const u8) Error!*Self {
    const v = try alloc.create(Self);
    v.* = .{
        .base = .{
            .alloc = alloc,
            .tag = tag,
            .attributes = .init(alloc),
            .class_list = .init(alloc),
        },
        .content = try .initCapacity(alloc, 2),
    };
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .render = Self.render }, .ptr = self };
}

pub fn append(self: *Self, content: Element) Error!void {
    return self.content.append(self.base.alloc, content);
}

fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    var base = self.base;
    const b = try base.element().render(alloc);
    defer alloc.free(b);
    var acc = try List(u8).initCapacity(alloc, b.len + self.content.items.len);
    try acc.appendSlice(alloc, b);
    for (self.content.items) |it| {
        var v = it;
        const sub = try v.render(alloc);
        defer alloc.free(sub);
        try acc.appendSlice(alloc, sub);
    }
    try acc.appendSlice(alloc, "</");
    try acc.appendSlice(alloc, base.tag);
    try acc.append(alloc, '>');
    return acc.toOwnedSlice(alloc);
}
