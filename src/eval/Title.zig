const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");
const Node = Element.Node;

level: u3,
content: Element,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

const Self = @This();

pub fn init(alloc: Allocator, level: u3, content: Element) !*Self {
    const v = try alloc.create(Self);
    v.* = .{ .level = level, .content = content };
    v.node.ptr = v;
    return v;
}

pub fn element(self: *Self) Element {
    return Element.Wrapper(Self, html).init(self);
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
    var el = try HTML.Content.init(alloc, switch (self.level) {
        1 => "h1",
        2 => "h2",
        3 => "h3",
        4 => "h4",
        5 => "h5",
        6 => "h6",
        else => unreachable,
    });
    el.content = try self.content.html(alloc);
    return el.element();
}
