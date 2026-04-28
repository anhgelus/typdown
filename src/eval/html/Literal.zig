const std = @import("std");
const Allocator = std.mem.Allocator;
const html = @import("html.zig");
const Element = @import("Element.zig");
const Node = Element.Node;
const Error = Element.Error;

literal: []const u8,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

const Self = @This();

pub fn init(alloc: Allocator, literal: []const u8) Error!*Element.Literal {
    const v = try alloc.create(Self);
    v.* = .{ .literal = try html.escape(alloc, literal) };
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
    return try alloc.dupe(u8, self.literal);
}
