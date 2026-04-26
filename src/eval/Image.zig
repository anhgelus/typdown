const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");

const Self = @This();

src: []const u8,
alt: ?[]const u8 = null,
source: ?Element = null,

pub fn init(alloc: Allocator, src: []const u8) !*Self {
    const v = try alloc.create(Self);
    v.* = .{
        .src = src,
    };
    return v;
}

pub fn element(self: *Self) Element {
    return .{ .ptr = self, .vtable = .{ .deinit = destroy, .html = html } };
}

pub fn deinit(self: *Self, alloc: Allocator) void {
    destroy(self, alloc);
}

fn destroy(context: *anyopaque, alloc: Allocator) void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.source) |it| it.deinit(alloc);
    alloc.destroy(self);
}

fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
    const self: *Self = @ptrCast(@alignCast(context));

    var img = try HTML.init(alloc, .void, "img");
    errdefer img.deinit();
    try img.setAttribute("src", self.src);
    if (self.alt) |it| try img.setAttribute("alt", it);
    var el = try HTML.init(alloc, .content, "figure");
    errdefer el.deinit();
    try el.appendContent(img);

    const source = self.source orelse return el;
    var caption = try HTML.init(alloc, .content, "figcaption");
    errdefer caption.deinit();
    try caption.appendContent(try source.html(alloc));
    try el.appendContent(caption);
    return el;
}

test "html" {
    const alloc = std.testing.allocator;
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    var img = try init(alloc, "foo");
    defer img.deinit(alloc);
    const h = try img.element().renderHTML(alloc);
    defer alloc.free(h);
    try expect(eql(u8, h, "<figure><img src=\"foo\"></figure>"));

    img.alt = "bar";
    const h2 = try img.element().renderHTML(alloc);
    defer alloc.free(h2);
    try expect(eql(u8, h2, "<figure><img src=\"foo\" alt=\"bar\"></figure>"));

    const in = try Element.Empty.init(alloc);
    try in.content.append(alloc, (try Element.Literal.init(alloc, "caption")).element());
    img.source = in.element();
    const h3 = try img.element().renderHTML(alloc);
    defer alloc.free(h3);
    try expect(eql(u8, h3, "<figure><img src=\"foo\" alt=\"bar\"><figcaption>caption</figcaption></figure>"));
}
