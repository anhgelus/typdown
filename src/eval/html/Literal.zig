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

pub fn initNoEscape(alloc: Allocator, literal: []const u8) Error!*Element.Literal {
    const v = try alloc.create(Self);
    v.* = .{ .literal = try alloc.dupe(u8, literal) };
    v.node.ptr = v;
    return v;
}

pub fn element(self: *Self) Element {
    return (Element.Wrapper(Self){ .ptr = self }).element();
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

pub fn render(self: *Self, alloc: Allocator) Error![]const u8 {
    return try alloc.dupe(u8, self.literal);
}
