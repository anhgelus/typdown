const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const html = @import("html.zig");

pub const Kind = enum {
    void,
    content,
    literal,
};

const Self = @This();

kind: Kind,
alloc: Allocator,
tag: ?[]const u8 = null,
attributes: std.StringArrayHashMap([]const u8),
class_list: std.BufSet,
content: std.ArrayList(Self) = .empty,
literal: ?[]const u8 = null,

pub fn init(alloc: Allocator, knd: Kind, tag: []const u8) Self {
    return .{
        .kind = knd,
        .alloc = alloc,
        .tag = tag,
        .attributes = .init(alloc),
        .class_list = .init(alloc),
    };
}

pub fn initLit(alloc: Allocator, literal: []const u8) Self {
    return .{
        .kind = .literal,
        .alloc = alloc,
        .literal = literal,
        .attributes = .init(alloc),
        .class_list = .init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.attributes.deinit();
    self.class_list.deinit();
    for (self.content.items) |it| {
        var v = it;
        v.deinit();
    }
    self.content.deinit(self.alloc);
}

pub fn render(self: *Self, alloc: Allocator) ![]const u8 {
    const attr = try self.renderAttribute(alloc);
    defer if (attr) |it| alloc.free(it);
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    errdefer acc.deinit(alloc);
    if (self.tag) |tag| {
        try acc.append(alloc, '<');
        try acc.appendSlice(alloc, tag);
        if (attr) |it| try acc.appendSlice(alloc, it);
        try acc.append(alloc, '>');
    }
    switch (self.kind) {
        .void => return acc.toOwnedSlice(alloc),
        .content => {
            for (self.content.items) |it| {
                var v = it;
                const sub = try v.render(alloc);
                defer alloc.free(sub);
                try acc.appendSlice(alloc, sub);
            }
        },
        .literal => try acc.appendSlice(alloc, self.literal.?),
    }
    if (self.tag) |tag| {
        try acc.appendSlice(alloc, "</");
        try acc.appendSlice(alloc, tag);
        try acc.append(alloc, '>');
    }
    return acc.toOwnedSlice(alloc);
}

fn renderAttribute(self: *Self, alloc: Allocator) !?[]const u8 {
    const class = try self.renderClass(alloc);
    defer if (class) |it| alloc.free(it);
    if (class) |it| try self.setAttribute("class", it);
    var iter = self.attributes.iterator();
    if (iter.len == 0) return null;
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
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

fn renderClass(self: *const Self, alloc: Allocator) !?[]const u8 {
    var iter = self.class_list.iterator();
    if (iter.len == 0) return null;
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    errdefer acc.deinit(alloc);
    const n = self.class_list.count();
    var i: usize = 0;
    while (iter.next()) |it| : (i += 1) {
        try acc.appendSlice(alloc, it.*);
        if (i < n - 1) try acc.append(alloc, ' ');
    }
    return try acc.toOwnedSlice(alloc);
}

pub fn setAttribute(self: *Self, k: []const u8, v: []const u8) !void {
    try self.attributes.put(k, v);
}

pub fn removeAttribute(self: *Self, k: []const u8) void {
    _ = self.attributes.orderedRemove(k);
}

pub fn hasAttribute(self: *Self, k: []const u8) bool {
    return self.attributes.contains(k);
}

pub fn appendClass(self: *Self, v: []const u8) !void {
    try self.class_list.insert(v);
}

pub fn hasClass(self: *Self, v: []const u8) bool {
    return self.class_list.contains(v);
}

pub fn removeClass(self: *Self, v: []const u8) void {
    self.class_list.remove(v);
}

pub fn appendContent(self: *Self, content: Self) !void {
    return self.content.append(self.alloc, content);
}

pub fn initImg(alloc: Allocator, src: []const u8, alt: []const u8) !Self {
    var el = init(alloc, .void, "img");
    try el.setAttribute("src", src);
    try el.setAttribute("alt", alt);
    return el;
}

pub fn initContent(alloc: Allocator, tag: []const u8, content: []Self) !Self {
    var el = init(alloc, .content, tag);
    for (content) |it| try el.appendContent(it);
    return el;
}

pub fn initParagraph(alloc: Allocator, content: []const u8) !Self {
    var el = init(alloc, .content, "p");
    try el.appendContent(initLit(alloc, content));
    return el;
}

fn doTest(alloc: Allocator, el: *Self, exp: []const u8) !void {
    const got = try el.render(alloc);
    defer alloc.free(got);
    std.testing.expect(eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "void element" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    var br = init(alloc, .void, "br");
    defer br.deinit();

    try doTest(alloc, &br, "<br>");

    var img = init(alloc, .void, "img");
    defer img.deinit();
    try img.setAttribute("src", "foo");
    try img.setAttribute("alt", "bar");

    try doTest(alloc, &img, "<img src=\"foo\" alt=\"bar\">");

    var img2 = try initImg(alloc, "foo", "bar");
    defer img2.deinit();
    try doTest(alloc, &img2, "<img src=\"foo\" alt=\"bar\">");
}

test "content element" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    var p = init(alloc, .content, "p");
    defer p.deinit();

    var content = initLit(alloc, "hello world");
    try p.appendContent(content);

    try doTest(alloc, &content, "hello world");
    try doTest(alloc, &p, "<p>hello world</p>");

    var p_managed = try initParagraph(alloc, "hello world");
    defer p_managed.deinit();

    try doTest(alloc, &p_managed, "<p>hello world</p>");

    var div = init(alloc, .content, "div");
    defer div.deinit();
    try div.appendClass("foo-bar");
    try div.appendContent(try initParagraph(alloc, "hello world"));
    try div.appendContent(try initImg(alloc, "example.org", "example"));

    try doTest(alloc, &div, "<div class=\"foo-bar\"><p>hello world</p><img src=\"example.org\" alt=\"example\"></div>");
}
