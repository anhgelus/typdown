const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");
const Node = Element.Node;

const Self = @This();

src: []const u8,
alt: ?[]const u8 = null,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

pub fn init(alloc: Allocator, src: []const u8) !*Self {
    const v = try alloc.create(Self);
    v.* = .{ .src = src };
    v.node.ptr = v;
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .ptr = self, .vtable = .{ .html = html, .node = getNode } };
}

fn getNode(context: *anyopaque) *Node {
    const self: *Self = @ptrCast(@alignCast(context));
    return &self.node;
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
    const self: *Self = @ptrCast(@alignCast(context));
    var img = try HTML.Void.init(alloc, "img");
    try img.setAttribute("src", self.src);
    if (self.alt) |it| try img.setAttribute("alt", it);
    return img.element();
}

test "html" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    var img = try init(alloc, "foo");
    const h = try img.element().renderHTML(alloc);
    defer alloc.free(h);
    try expect(eql(u8, h, "<img src=\"foo\">"));

    img.alt = "bar";
    const h2 = try img.element().renderHTML(alloc);
    defer alloc.free(h2);
    try expect(eql(u8, h2, "<img src=\"foo\" alt=\"bar\">"));
}
