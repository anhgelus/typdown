const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const paragraph = @import("paragraph.zig");
const title = @import("title.zig");
const link = @import("link.zig");
const list = @import("list.zig");
const code = @import("code.zig");
const callout = @import("callout.zig");
const quote = @import("quote.zig");
const math = @import("math.zig");

pub const Error = error{FeatureNotSupported} ||
    Lexer.Error ||
    paragraph.Error ||
    title.Error ||
    link.Error ||
    list.Error ||
    link.ImageError ||
    code.Error ||
    callout.Error ||
    quote.Error ||
    math.Error ||
    Allocator.Error;

pub const Document = Element.Root;

pub fn parseReader(parent: Allocator, r: *std.io.Reader) !*Document {
    var l = try Lexer.initReader(parent, r);
    defer parent.free(l.iter.bytes);
    return gen(parent, &l);
}

pub fn parse(parent: Allocator, content: []const u8) Error!*Document {
    var l = try Lexer.init(content);
    return gen(parent, &l);
}

fn gen(parent: Allocator, l: *Lexer) Error!*Document {
    var root = try Document.init(parent);
    errdefer root.deinit();
    const alloc = root.allocator();
    base: while (l.peek()) |it| {
        root.append(switch (it.kind) {
            // other blocks
            .title => try title.parse(alloc, l),
            .list_ordored => try list.parseOrdored(alloc, l),
            .list_unordored => try list.parseUnordored(alloc, l),
            .image => try link.parseImage(alloc, l),
            .code_block => try code.parse(alloc, l),
            .quote => try quote.parse(alloc, l),
            .math_block => try math.parse(alloc, l),
            .weak_delimiter, .strong_delimiter => {
                l.consume();
                continue :base;
            },
            else =>
            // block paragraph
            if (it.kind.isInParagraph())
                try paragraph.parse(alloc, l)
            else
                return Error.FeatureNotSupported,
        });
    }
    return root;
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

    try doTest(alloc, "hello world", "<p>hello world</p>");
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
