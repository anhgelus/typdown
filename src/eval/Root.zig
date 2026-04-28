const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");

const Self = @This();

content: std.ArrayList(Element),
arena: Arena,

pub fn init(parent: Allocator) !*Self {
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

pub fn allocator(self: *Self) Allocator {
    return self.arena.allocator();
}

pub fn append(self: *Self, el: Element) !void {
    try self.content.append(self.allocator(), el);
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .html = html }, .ptr = self };
}

pub fn renderHTML(self: *Self, alloc: Allocator) HTML.Error![]const u8 {
    return try self.element().renderHTML(alloc);
}

fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
    const self: *Self = @ptrCast(@alignCast(context));
    const el = try HTML.Root.init(alloc);
    if (self.content.items.len == 0) return el.element();
    for (self.content.items) |it| el.append(try it.html(el.allocator()));
    return el.element();
}
