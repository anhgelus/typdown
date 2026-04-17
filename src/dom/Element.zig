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
gpa: Allocator,
tag: ?[]const u8 = null,
attributes: std.StringArrayHashMap([]const u8),
class_list: std.BufSet,
content: std.ArrayList(Self) = .empty,
literal: ?[]const u8 = null,

/// Init a new Element with the given kind.
/// The tag will never be escaped.
pub fn init(gpa: Allocator, knd: Kind, tag: []const u8) Self {
    return .{
        .kind = knd,
        .gpa = gpa,
        .tag = tag,
        .attributes = .init(gpa),
        .class_list = .init(gpa),
    };
}

/// Init a new literal element.
/// The literal content will never be escaped, see initLitEscaped if you want to escape it.
/// The literal content must be free'd by the allocator (use Allocator.dupe if you want to use a const string).
pub fn initLit(gpa: Allocator, literal: []const u8) Self {
    return .{
        .kind = .literal,
        .gpa = gpa,
        .literal = literal,
        .attributes = .init(gpa),
        .class_list = .init(gpa),
    };
}

/// Init a new literal element that is escaped.
/// The literal content will be escaped, see initLit if you don't want this behavior.
pub fn initLitEscaped(gpa: Allocator, literal: []const u8) !Self {
    return .initLit(gpa, try html.escape(gpa, literal));
}

pub fn deinit(self: *Self) void {
    self.attributes.deinit();
    self.class_list.deinit();
    for (self.content.items) |it| {
        var v = it;
        v.deinit();
    }
    self.content.deinit(self.gpa);
    if (self.literal) |it| self.gpa.free(it);
}

pub fn render(self: *Self, gpa: Allocator) ![]const u8 {
    const attr = try self.renderAttribute(gpa);
    defer if (attr) |it| gpa.free(it);
    var acc = try std.ArrayList(u8).initCapacity(gpa, self.content.items.len + if (self.literal) |it| it.len else 0);
    errdefer acc.deinit(gpa);
    if (self.tag) |tag| {
        try acc.append(gpa, '<');
        try acc.appendSlice(gpa, tag);
        if (attr) |it| try acc.appendSlice(gpa, it);
        try acc.append(gpa, '>');
    }
    switch (self.kind) {
        .void => return acc.toOwnedSlice(gpa),
        .content => {
            for (self.content.items) |it| {
                var v = it;
                const sub = try v.render(gpa);
                defer gpa.free(sub);
                try acc.appendSlice(gpa, sub);
            }
        },
        .literal => try acc.appendSlice(gpa, self.literal.?),
    }
    if (self.tag) |tag| {
        try acc.appendSlice(gpa, "</");
        try acc.appendSlice(gpa, tag);
        try acc.append(gpa, '>');
    }
    return acc.toOwnedSlice(gpa);
}

fn renderAttribute(self: *Self, gpa: Allocator) !?[]const u8 {
    const class = try self.renderClass(gpa);
    defer if (class) |it| gpa.free(it);
    if (class) |it| try self.setAttribute("class", it);
    var iter = self.attributes.iterator();
    if (iter.len == 0) return null;
    var acc = try std.ArrayList(u8).initCapacity(gpa, iter.len);
    errdefer acc.deinit(gpa);
    try acc.append(gpa, ' ');
    var i: usize = 0;
    while (iter.next()) |it| : (i += 1) {
        try acc.appendSlice(gpa, it.key_ptr.*);
        try acc.appendSlice(gpa, "=\"");
        const escape = try html.escape(gpa, it.value_ptr.*);
        defer gpa.free(escape);
        try acc.appendSlice(gpa, escape);
        try acc.append(gpa, '"');
        if (i < iter.len - 1) try acc.append(gpa, ' ');
    }
    return try acc.toOwnedSlice(gpa);
}

fn renderClass(self: *const Self, gpa: Allocator) !?[]const u8 {
    var iter = self.class_list.iterator();
    if (iter.len == 0) return null;
    const n = self.class_list.count();
    var acc = try std.ArrayList(u8).initCapacity(gpa, n);
    errdefer acc.deinit(gpa);
    var i: usize = 0;
    while (iter.next()) |it| : (i += 1) {
        try acc.appendSlice(gpa, it.*);
        if (i < n - 1) try acc.append(gpa, ' ');
    }
    return try acc.toOwnedSlice(gpa);
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
    return self.content.append(self.gpa, content);
}

pub fn initImg(gpa: Allocator, src: []const u8, alt: []const u8) !Self {
    var el = init(gpa, .void, "img");
    try el.setAttribute("src", src);
    try el.setAttribute("alt", alt);
    return el;
}

pub fn initContent(gpa: Allocator, tag: []const u8, content: []Self) !Self {
    var el = init(gpa, .content, tag);
    for (content) |it| try el.appendContent(it);
    return el;
}

/// Init a paragraph tag with an automatically escaped content.
pub fn initParagraph(gpa: Allocator, content: []const u8) !Self {
    var el = init(gpa, .content, "p");
    try el.appendContent(try initLitEscaped(gpa, content));
    return el;
}

fn doTest(gpa: Allocator, el: *Self, exp: []const u8) !void {
    const got = try el.render(gpa);
    defer gpa.free(got);
    std.testing.expect(eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "void element" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer _ = arena.deinit();
    const gpa = arena.allocator();

    var br = init(gpa, .void, "br");
    defer br.deinit();

    try doTest(gpa, &br, "<br>");

    var img = init(gpa, .void, "img");
    defer img.deinit();
    try img.setAttribute("src", "foo");
    try img.setAttribute("alt", "bar");

    try doTest(gpa, &img, "<img src=\"foo\" alt=\"bar\">");

    var img2 = try initImg(gpa, "foo", "bar");
    defer img2.deinit();
    try doTest(gpa, &img2, "<img src=\"foo\" alt=\"bar\">");
}

test "content element" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer _ = arena.deinit();
    const gpa = arena.allocator();

    var p = init(gpa, .content, "p");
    defer p.deinit();

    var content = initLit(gpa, try gpa.dupe(u8, "hello world"));
    try p.appendContent(content);

    try doTest(gpa, &content, "hello world");
    try doTest(gpa, &p, "<p>hello world</p>");

    var p_managed = try initParagraph(gpa, "hello world");
    defer p_managed.deinit();

    try doTest(gpa, &p_managed, "<p>hello world</p>");

    var div = init(gpa, .content, "div");
    defer div.deinit();
    try div.appendClass("foo-bar");
    try div.appendContent(try initParagraph(gpa, "hello world"));
    try div.appendContent(try initImg(gpa, "example.org", "example"));

    try doTest(gpa, &div, "<div class=\"foo-bar\"><p>hello world</p><img src=\"example.org\" alt=\"example\"></div>");
}
