const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");

pub const Block = Element.Simple("p");

pub const Bold = Element.Simple("b");
pub const Italic = Element.Simple("em");
pub const Code = Element.Simple("code");

pub const Link = struct {
    link: []const u8,
    content: Element,
    target: ?[]const u8 = null,

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element, link: []const u8) !*Self {
        const v = try alloc.create(Self);
        v.* = .{
            .content = content,
            .link = link,
        };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .ptr = self, .vtable = .{ .html = html } };
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try HTML.Content.init(alloc, "a");
        try el.append(try self.content.html(alloc));
        try el.base.setAttribute("href", self.link);
        if (self.target) |target| try el.base.setAttribute("target", target);
        return el.element();
    }
};

fn doTest(alloc: Allocator, el: Element, exp: []const u8) !void {
    const got = try el.renderHTML(alloc);
    defer alloc.free(got);
    std.testing.expect(std.mem.eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "paragraph" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lit = (try Element.Literal.init(alloc, "hello world")).element();
    try doTest(alloc, lit, "hello world");

    var p = try Block.init(alloc);
    try p.content.append(alloc, lit);
    try doTest(alloc, p.element(), "<p>hello world</p>");

    const link = (try Link.init(alloc, (try Element.Literal.init(alloc, "foo")).element(), "example.org")).element();
    try doTest(alloc, link, "<a href=\"example.org\">foo</a>");

    try p.content.append(alloc, link);
    try doTest(alloc, p.element(), "<p>hello world<a href=\"example.org\">foo</a></p>");
}
