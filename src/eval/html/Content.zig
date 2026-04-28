const std = @import("std");
const Allocator = std.mem.Allocator;
const Element = @import("Element.zig");
const Node = Element.Node;
const Error = Element.Error;

base: Element.Void,
content: ?Element = null,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

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
    };
    v.node.ptr = v;
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .render = render, .node = getNode }, .ptr = self };
}

fn getNode(context: *anyopaque) *Node {
    const self: *Self = @ptrCast(@alignCast(context));
    return &self.node;
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    var base = self.base;
    const b = try base.element().render(alloc);
    defer alloc.free(b);
    var acc = try std.ArrayList(u8).initCapacity(alloc, b.len * 2);
    try acc.appendSlice(alloc, b);

    if (self.content) |it| {
        const sub = try it.render(alloc);
        defer alloc.free(sub);
        try acc.appendSlice(alloc, sub);
    }

    try acc.appendSlice(alloc, "</");
    try acc.appendSlice(alloc, base.tag);
    try acc.append(alloc, '>');
    return acc.toOwnedSlice(alloc);
}
