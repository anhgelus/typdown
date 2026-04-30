const std = @import("std");
const typst = @cImport(@cInclude("typdown_typst.h"));
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");
const Node = Element.Node;

const common_template = @embedFile("template.typ");
const content_template = @embedFile("template_content.typ");
const block_template = @embedFile("template_block.typ");
const apply_template = "#show: display.with(param)\n\n";

pub const Error = error{InvalidTypstTemplate} || Allocator.Error;

fn typstInterop(alloc: Allocator, comptime f: fn ([*c]const u8) callconv(.c) [*c]const u8, content: []const u8) ![]const u8 {
    const source = try alloc.dupeZ(u8, content);
    defer alloc.free(source);
    const raw_res = f(source);
    const res = try alloc.dupe(u8, std.mem.span(raw_res));
    defer typst.typst_freeString(raw_res);
    return res;
}

fn generateSVG(alloc: Allocator, content: []const u8) ![]const u8 {
    return try typstInterop(alloc, typst.typst_generateSVG, content);
}

fn escape(alloc: Allocator, content: []const u8) ![]const u8 {
    return try typstInterop(alloc, typst.typst_escapeMath, content);
}

fn generateFile(alloc: Allocator, template: []const u8, content: []const u8) Error![]const u8 {
    var acc = try std.ArrayList(u8).initCapacity(
        alloc,
        common_template.len + template.len + apply_template.len + content.len,
    );
    try acc.appendSlice(alloc, common_template);
    try acc.appendSlice(alloc, template);
    try acc.appendSlice(alloc, apply_template);
    try acc.appendSlice(alloc, content);
    return try acc.toOwnedSlice(alloc);
}

fn Math(comptime template: []const u8, comptime modFn: *const fn (Allocator, []const u8) Allocator.Error![]const u8) type {
    return struct {
        content: ?[]const u8 = null,
        node: Node,

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.node = .{ .ptr = v, .vtable = .{ .element = fromNode } };
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
            const content = self.content orelse return (try HTML.Literal.init(alloc, "")).element();
            var arena = std.heap.ArenaAllocator.init(alloc);
            defer arena.deinit();
            const escaped = try escape(arena.allocator(), content);
            const file = generateFile(arena.allocator(), template, try modFn(arena.allocator(), escaped)) catch |err| switch (err) {
                Error.InvalidTypstTemplate => @panic("invalid template"),
                Error.OutOfMemory => return Error.OutOfMemory,
            };
            const svg = try generateSVG(arena.allocator(), file);
            return (try HTML.Literal.initNoEscape(alloc, svg)).element();
        }
    };
}

pub const Content = Math(content_template, mathContent);
pub const Block = Math(block_template, mathBlock);

fn mathContent(alloc: Allocator, content: []const u8) Allocator.Error![]const u8 {
    const escaped = try escape(alloc, content);
    var acc = try std.ArrayList(u8).initCapacity(alloc, escaped.len + 2);
    try acc.append(alloc, '$');
    try acc.appendSlice(alloc, escaped);
    try acc.append(alloc, '$');
    return try acc.toOwnedSlice(alloc);
}

fn mathBlock(alloc: Allocator, content: []const u8) Allocator.Error![]const u8 {
    const escaped = try escape(alloc, content);
    var acc = try std.ArrayList(u8).initCapacity(alloc, escaped.len + 4);
    try acc.appendSlice(alloc, "$ ");
    try acc.appendSlice(alloc, escaped);
    try acc.appendSlice(alloc, " $");
    return try acc.toOwnedSlice(alloc);
}

fn doTest(alloc: Allocator, v: []const u8, r: []const u8) !void {
    const escaped = try escape(alloc, v);
    defer alloc.free(escaped);
    std.testing.expect(std.mem.eql(u8, escaped, r)) catch |err| {
        std.debug.print("{s}\n", .{escaped});
        return err;
    };
}

test "escape math" {
    const alloc = std.testing.allocator;

    try doTest(alloc, "hello", "hello");
    try doTest(alloc, "hello $ world", "hello \\$ world");
    try doTest(alloc,
        \\hello
        \\world
    , "hello\\ world");
}
