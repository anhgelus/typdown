const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const paragraph = @import("paragraph.zig");
const title = @import("title.zig");
const link = @import("link.zig");
const list = @import("list.zig");

pub const Error = error{
    FeatureNotSupported,
} || Lexer.Error || paragraph.Error || title.Error || link.Error || Allocator.Error;

pub const Document = struct {
    arena: std.heap.ArenaAllocator,
    root: []Element,

    pub fn renderHTML(self: @This(), alloc: Allocator) Element.HTML.Error![]const u8 {
        var content = try std.ArrayList(u8).initCapacity(alloc, self.root.len * 6);
        errdefer content.deinit(alloc);
        for (self.root) |it| {
            const v = try it.renderHTML(alloc);
            defer alloc.free(v);
            try content.appendSlice(alloc, v);
        }
        return content.toOwnedSlice(alloc);
    }

    pub fn deinit(self: @This()) void {
        self.arena.deinit();
    }
};

pub fn parseReader(parent: Allocator, r: *std.io.Reader) !Document {
    var l = try Lexer.initReader(parent, r);
    defer parent.free(l.iter.bytes);
    return gen(parent, &l);
}

pub fn parse(parent: Allocator, content: []const u8) Error!Document {
    var l = try Lexer.init(content);
    return gen(parent, &l);
}

fn gen(parent: Allocator, l: *Lexer) Error!Document {
    var arena = std.heap.ArenaAllocator.init(parent);
    const alloc = arena.allocator();
    errdefer arena.deinit();

    var elements = try std.ArrayList(Element).initCapacity(alloc, 2);
    base: while (l.peek()) |it| {
        try elements.append(alloc, switch (it.kind) {
            // block paragraph
            .literal, .bold, .italic, .code, .link => try paragraph.parse(alloc, l),
            // other blocks
            .title => try title.parse(alloc, l),
            .list_ordored => try list.parseOrdored(alloc, l),
            .list_unordored => try list.parseUnordored(alloc, l),
            .weak_delimiter, .strong_delimiter => {
                l.consume();
                continue :base;
            },
            else => return Error.FeatureNotSupported,
        });
    }
    return .{ .root = try elements.toOwnedSlice(alloc), .arena = arena };
}

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    const g = try parse(alloc, t);
    defer g.deinit();
    const res = try g.renderHTML(alloc);
    defer alloc.free(res);
    std.testing.expect(std.mem.eql(u8, res, v)) catch |err| {
        std.debug.print("{s}\n", .{res});
        return err;
    };
}

test "parse multilines" {
    const alloc = std.testing.allocator;

    try doTest(alloc,
        \\hello
        \\world
        \\
        \\foo bar
        \\in new paragraph
    , "<p>hello world</p><p>foo bar in new paragraph</p>");

    try doTest(alloc,
        \\# title
        \\hello world ;3
        \\## subtitle
        \\hehe
    , "<h1>title</h1><p>hello world ;3</p><h2>subtitle</h2><p>hehe</p>");
}

test "multiple render doc" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const g = try parse(alloc, "hello *world*!");
    const a = try g.renderHTML(alloc);
    const b = try g.renderHTML(alloc);
    try std.testing.expect(std.mem.eql(u8, a, b));
}
