const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const List = std.ArrayList;
const html = @import("html.zig");

pub const Void = @import("Void.zig");
pub const Content  = @import("Content.zig");
pub const Literal = @import("Literal.zig");
pub const Root = @import("Root.zig");

pub const Error = html.Error || Allocator.Error;

const Element = @This();

vtable: struct {
    render: *const fn (self: *anyopaque, alloc: Allocator) Error![]const u8,
},
ptr: *anyopaque,

pub fn render(self: Element, alloc: Allocator) Error![]const u8 {
    return self.vtable.render(self.ptr, alloc);
}

fn doTest(alloc: Allocator, el: Element, exp: []const u8) !void {
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

test "root" {
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
