const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const List = std.ArrayList;
const html = @import("html.zig");

pub const Error = html.Error || Allocator.Error;

const Element = @This();

vtable: struct {
    render: *const fn (self: *anyopaque, alloc: Allocator) Error![]const u8,
},
ptr: *anyopaque,

pub fn render(self: Element, alloc: Allocator) Error![]const u8 {
    return self.vtable.render(self.ptr, alloc);
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

pub const Void = struct {
    alloc: Allocator,
    tag: []const u8,
    attributes: std.StringArrayHashMap([]const u8),
    class_list: std.BufSet,

    pub const Self = @This();

    pub fn init(alloc: Allocator, tag: []const u8) Error!*Self {
        const v = try alloc.create(Self);
        v.* = .{
            .alloc = alloc,
            .tag = tag,
            .attributes = .init(alloc),
            .class_list = .init(alloc),
        };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .vtable = .{ .render = Self.render }, .ptr = self };
    }

    pub fn setAttribute(self: *Self, k: []const u8, v: []const u8) Error!void {
        try self.attributes.put(try self.alloc.dupe(u8, k), try self.alloc.dupe(u8, v));
    }

    pub fn removeAttribute(self: *Self, k: []const u8) void {
        _ = self.attributes.orderedRemove(k);
    }

    pub fn hasAttribute(self: *Self, k: []const u8) bool {
        return self.attributes.contains(k);
    }

    pub fn appendClass(self: *Self, v: []const u8) Error!void {
        try self.class_list.insert(v);
    }

    pub fn hasClass(self: *Self, v: []const u8) bool {
        return self.class_list.contains(v);
    }

    pub fn removeClass(self: *Self, v: []const u8) void {
        self.class_list.remove(v);
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
};

pub const Content = struct {
    base: Void,
    content: List(Element),

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
            .content = try .initCapacity(alloc, 2),
        };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .vtable = .{ .render = Self.render }, .ptr = self };
    }

    pub fn append(self: *Self, content: Element) Error!void {
        return self.content.append(self.base.alloc, content);
    }

    fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
        const self: *Self = @ptrCast(@alignCast(context));
        var base = self.base;
        const b = try base.element().render(alloc);
        defer alloc.free(b);
        var acc = try List(u8).initCapacity(alloc, b.len + self.content.items.len);
        try acc.appendSlice(alloc, b);
        for (self.content.items) |it| {
            var v = it;
            const sub = try v.render(alloc);
            defer alloc.free(sub);
            try acc.appendSlice(alloc, sub);
        }
        try acc.appendSlice(alloc, "</");
        try acc.appendSlice(alloc, base.tag);
        try acc.append(alloc, '>');
        return acc.toOwnedSlice(alloc);
    }
};

pub const Literal = struct {
    literal: []const u8,

    const Self = @This();

    pub fn init(alloc: Allocator, literal: []const u8) Error!*Literal {
        const v = try alloc.create(Self);
        v.* = .{ .literal = try html.escape(alloc, literal) };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .vtable = .{ .render = Self.render }, .ptr = self };
    }

    fn render(context: *anyopaque, alloc: Allocator) Error![]const u8 {
        const self: *Self = @ptrCast(@alignCast(context));
        return try alloc.dupe(u8, self.literal);
    }
};

pub const Root = struct {
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
};

fn doTest(alloc: Allocator, el: Element, exp: []const u8) !void {
    const got = try el.render(alloc);
    defer alloc.free(got);
    std.testing.expect(eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "void element" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var br = try Void.init(alloc, "br");

    try doTest(alloc, br.element(), "<br>");

    var img = try Void.init(alloc, "img");
    try img.setAttribute("src", "foo");
    try img.setAttribute("alt", "bar");

    try doTest(alloc, img.element(), "<img src=\"foo\" alt=\"bar\">");
}

test "content element" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var p = try Content.init(alloc, "p");

    var content = try Literal.init(alloc, "hello world");
    try p.append(content.element());

    try doTest(alloc, content.element(), "hello world");
    try doTest(alloc, p.element(), "<p>hello world</p>");

    var div = try Content.init(alloc, "div");
    try div.base.appendClass("foo-bar");
    try div.append(p.element());
    try div.append((try Void.init(alloc, "br")).element());

    try doTest(alloc, div.element(), "<div class=\"foo-bar\"><p>hello world</p><br></div>");
}

test "root element" {
    const root = try Root.init(std.testing.allocator);
    defer root.deinit();
    const alloc = root.allocator();

    var p = try Content.init(alloc, "p");
    var content = try Literal.init(alloc, "hello world");
    try p.append(content.element());
    try root.append(p.element());

    var br = try Void.init(alloc, "br");
    try root.append(br.element());

    try doTest(alloc, root.element(), "<p>hello world</p><br>");
}
