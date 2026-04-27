const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Parent.HTML;
const Parent = @import("Element.zig");

level: u3,
content: Parent,

const Self = @This();

pub fn init(alloc: Allocator, level: u3, content: Parent) !*Self {
    const v = try alloc.create(Self);
    v.* = .{ .level = level, .content = content };
    return v;
}

pub fn element(self: *Self) Parent {
    return .{ .ptr = self, .vtable = .{ .html = html } };
}

fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
    const self: *Self = @ptrCast(@alignCast(context));
    var el = try HTML.Content.init(alloc, switch (self.level) {
        1 => "h1",
        2 => "h2",
        3 => "h3",
        4 => "h4",
        5 => "h5",
        6 => "h6",
        else => unreachable,
    });
    try el.append(try self.content.html(alloc));
    return el.element();
}
