const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = std.ArrayList;
const Element = @import("Element.zig");
const Error = Element.Error;

content: List(Element),
arena: Arena,

const Self = @This();

pub fn init(parent: Allocator) Error!*Self {
    var s = Self{
        .content = undefined,
        .arena = .init(parent),
    };
    var alloc = s.arena.allocator();
    s.content = try .initCapacity(alloc, 2);
    const v = try alloc.create(Self);
    v.* = s;
    return v;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .render = Self.render, }, .ptr = self };
}

pub fn allocator(self: *Self) Allocator {
    return self.arena.allocator();
}

pub fn append(self: *Self, el: Element) Error!void {
    try self.content.append(self.allocator(), el);
}

fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.content.items.len == 0) return "";
    var acc = try List(u8).initCapacity(alloc, self.content.items.len);
    errdefer acc.deinit(alloc);

    var arena = Arena.init(alloc);
    defer arena.deinit();
    for (self.content.items) |it| {
        const res = try it.render(arena.allocator());
        try acc.appendSlice(alloc, res);
    }
    return acc.toOwnedSlice(alloc);
}
