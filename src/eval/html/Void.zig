const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const html = @import("html.zig");
const Element = @import("Element.zig");
const Node = Element.Node;
const Error = Element.Error;

alloc: Allocator,
tag: []const u8,
attributes: std.StringArrayHashMap([]const u8),
class_list: std.BufSet,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

pub const Self = @This();

pub fn init(alloc: Allocator, tag: []const u8) Error!*Self {
    const v = try alloc.create(Self);
    v.* = .{
        .alloc = alloc,
        .tag = tag,
        .attributes = .init(alloc),
        .class_list = .init(alloc),
    };
    v.node.ptr = v;
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .vtable = .{ .render = render, .node = getNode }, .ptr = self };
}

pub fn setAttribute(self: *Self, k: []const u8, v: []const u8) Error!void {
    try self.attributes.put(try self.alloc.dupe(u8, k), try html.escape(self.alloc, v));
}

pub fn removeAttribute(self: *Self, k: []const u8) void {
    _ = self.attributes.orderedRemove(k);
}

pub fn hasAttribute(self: *Self, k: []const u8) bool {
    return self.attributes.contains(k);
}

pub fn appendClass(self: *Self, v: []const u8) Error!void {
    try self.class_list.insert(try html.escape(self.alloc, v));
}

pub fn hasClass(self: *Self, v: []const u8) bool {
    return self.class_list.contains(v);
}

pub fn removeClass(self: *Self, v: []const u8) void {
    self.class_list.remove(v);
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
    const attr = try renderAttribute(alloc, &self.attributes, &self.class_list);
    defer if (attr) |it| alloc.free(it);
    var acc = try List(u8).initCapacity(alloc, self.tag.len + 2);
    errdefer acc.deinit(alloc);
    try acc.append(alloc, '<');
    try acc.appendSlice(alloc, self.tag);
    if (attr) |it| try acc.appendSlice(alloc, it);
    try acc.append(alloc, '>');
    return acc.toOwnedSlice(alloc);
}

fn renderAttribute(alloc: Allocator, attributes: *std.StringArrayHashMap([]const u8), class_list: *std.BufSet) Error!?[]const u8 {
    const class = try renderClass(alloc, class_list);
    defer if (class) |it| {
        _ = attributes.orderedRemove("class");
        alloc.free(it);
    };
    if (class) |it| try attributes.put("class", it);
    var iter = attributes.iterator();
    if (iter.len == 0) return null;
    var acc = try List(u8).initCapacity(alloc, iter.len);
    errdefer acc.deinit(alloc);
    try acc.append(alloc, ' ');
    var i: usize = 0;
    while (iter.next()) |it| : (i += 1) {
        try acc.appendSlice(alloc, it.key_ptr.*);
        try acc.appendSlice(alloc, "=\"");
        const escape = try html.escape(alloc, it.value_ptr.*);
        defer alloc.free(escape);
        try acc.appendSlice(alloc, escape);
        try acc.append(alloc, '"');
        if (i < iter.len - 1) try acc.append(alloc, ' ');
    }
    return try acc.toOwnedSlice(alloc);
}

fn renderClass(alloc: Allocator, class_list: *std.BufSet) Error!?[]const u8 {
    const n = class_list.count();
    if (n == 0) return null;
    var acc = try List(u8).initCapacity(alloc, n);
    errdefer acc.deinit(alloc);
    var iter = class_list.iterator();
    var i: usize = 0;
    while (iter.next()) |it| : (i += 1) {
        try acc.appendSlice(alloc, it.*);
        if (i < n - 1) try acc.append(alloc, ' ');
    }
    return try acc.toOwnedSlice(alloc);
}
