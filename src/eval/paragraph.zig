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
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .html = html } };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        destroy(self, alloc);
    }

    fn destroy(context: *anyopaque, alloc: Allocator) void {
        var self: *Self = @ptrCast(@alignCast(context));
        self.content.deinit(alloc);
        alloc.destroy(self);
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try HTML.init(alloc, .content, "a");
        errdefer el.deinit();
        try el.appendContent(try self.content.html(alloc));
        try el.setAttribute("href", self.link);
        if (self.target) |target| try el.setAttribute("target", target);
        return el;
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
    const alloc = std.testing.allocator;

    const lit = (try Element.Literal.init(alloc, "hello world")).element();
    try doTest(alloc, lit, "hello world");

    var p = try Block.init(alloc);
    try p.content.append(alloc, lit);
    defer p.deinit(alloc);
    try doTest(alloc, p.element(), "<p>hello world</p>");

    const link = (try Link.init(alloc, (try Element.Literal.init(alloc, "foo")).element(), "example.org")).element();
    try doTest(alloc, link, "<a href=\"example.org\">foo</a>");

    try p.content.append(alloc, link);
    try doTest(alloc, p.element(), "<p>hello world<a href=\"example.org\">foo</a></p>");
}
