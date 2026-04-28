const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const html = @import("html.zig");

pub const Void = @import("Void.zig");
pub const Content = @import("Content.zig");
pub const Literal = @import("Literal.zig");
pub const Root = @import("Root.zig");

pub const Error = html.Error || Allocator.Error;

pub const Node = struct {
    ptr: *anyopaque,
    vtable: struct { element: *const fn (*anyopaque) Self },
    node: std.DoublyLinkedList.Node = .{},

    pub fn from(n: *std.DoublyLinkedList.Node) *Node {
        const v: *Node = @fieldParentPtr("node", n);
        return v;
    }

    pub fn element(self: Node) Self {
        return self.vtable.element(self.ptr);
    }
};

const Self = @This();

vtable: struct {
    render: *const fn (*anyopaque, Allocator) Error![]const u8,
    node: *const fn (*anyopaque) *Node,
},
ptr: *anyopaque,

pub fn render(self: Self, alloc: Allocator) Error![]const u8 {
    return self.vtable.render(self.ptr, alloc);
}

pub fn node(self: Self) *Node {
    return self.vtable.node(self.ptr);
}

fn doTest(alloc: Allocator, el: Self, exp: []const u8) !void {
    const got = try el.render(alloc);
    defer alloc.free(got);
    std.testing.expect(eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "void" {
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

test "content" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var p = try Content.init(alloc, "p");
    var root = try Root.init(alloc);
    p.content = root.element();

    var content = try Literal.init(alloc, "hello world");
    root.append(content.element());

    try doTest(alloc, content.element(), "hello world");
    try doTest(alloc, p.element(), "<p>hello world</p>");

    var div = try Content.init(alloc, "div");
    var rootDiv = try Root.init(alloc);
    div.content = rootDiv.element();
    try div.base.appendClass("foo-bar");
    rootDiv.append(p.element());
    rootDiv.append((try Void.init(alloc, "br")).element());

    try doTest(alloc, div.element(), "<div class=\"foo-bar\"><p>hello world</p><br></div>");
}
