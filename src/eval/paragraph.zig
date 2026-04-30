const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");
const Node = Element.Node;

pub const Block = Element.Simple("p");

pub const Bold = Element.Simple("b");
pub const Italic = Element.Simple("em");
pub const Code = Element.Simple("code");

pub const Link = struct {
    link: []const u8,
    content: Element,
    target: ?[]const u8 = null,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element, link: []const u8) !*Self {
        const v = try alloc.create(Self);
        v.* = .{
            .content = content,
            .link = link,
        };
        v.node.ptr = v;
        return v;
    }

    pub fn element(self: *Self) Element {
        return Element.Wrapper(Self, html).init(self);
    }

    fn fromNode(context: *anyopaque) Element {
        const self: *Self = @ptrCast(@alignCast(context));
        return self.element();
    }

    fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
        var el = try HTML.Content.init(alloc, "a");
        el.content = try self.content.html(alloc);
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
    var root = try Element.Root.init(alloc);
    p.content = root.element();
    root.append(lit);
    try doTest(alloc, p.element(), "<p>hello world</p>");

    const link = (try Link.init(alloc, (try Element.Literal.init(alloc, "foo")).element(), "example.org")).element();
    try doTest(alloc, link, "<a href=\"example.org\">foo</a>");

    root.append(link);
    try doTest(alloc, p.element(), "<p>hello world<a href=\"example.org\">foo</a></p>");
}
