const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Element = @import("Element.zig");
const Node = Element.Node;
const Error = Element.Error;

content: std.DoublyLinkedList = .{},
arena: Arena,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

const Self = @This();

pub fn init(parent: Allocator) Error!*Self {
    var s = Self{ .arena = .init(parent) };
    var alloc = s.arena.allocator();
    const v = try alloc.create(Self);
    v.* = s;
    v.node.ptr = v;
    return v;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{
        .render = render,
        .node = getNode,
    }, .ptr = self };
}

pub fn allocator(self: *Self) Allocator {
    return self.arena.allocator();
}

pub fn append(self: *Self, el: Element) void {
    self.content.append(&el.node().node);
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
    if (self.content.first == null) return "";
    var acc = try std.ArrayList(u8).initCapacity(alloc, 8);
    errdefer acc.deinit(alloc);

    var arena = Arena.init(alloc);
    defer arena.deinit();
    var v = self.content.first;
    while (v) |it| : (v = it.next) try acc.appendSlice(alloc, try Node.from(it).element().render(arena.allocator()));
    return acc.toOwnedSlice(alloc);
}
