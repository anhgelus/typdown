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

const Self = @This();

/// Document represents a parsed typdown document.
pub const Document = struct {
    /// Root of the document: used to render the document is other languages.
    root: *Element.Root,
    /// Errors got while parsing the document.
    errors: ?[]Document.Error = null,

    /// DocError contains information about the error.
    pub const Error = struct {
        /// Error returned.
        err: Self.Error,
        /// Location of the error in the source.
        location: struct { beg: usize, end: usize, line: usize },

        /// Extract the invalid content from the source.
        pub fn extract(self: @This(), source: []const u8) []const u8 {
            return source[self.location.beg..self.location.end];
        }
    };

    pub fn deinit(self: @This(), alloc: Allocator) void {
        self.root.deinit();
        if (self.errors) |errors| alloc.free(errors);
    }
};

pub fn parse(parent: Allocator, content: []const u8) !Document {
    var l = try Lexer.init(content);
    return gen(parent, &l);
}

fn gen(parent: Allocator, l: *Lexer) Allocator.Error!Document {
    var root = try Element.Root.init(parent);
    errdefer root.deinit();
    const alloc = root.allocator();
    var doc_errors = std.ArrayList(Document.Error).empty;
    errdefer doc_errors.deinit(parent);
    base: while (l.peek()) |it| {
        const beg = l.iter.i;
        const v = switch (it.kind) {
            // other blocks
            .title => title.parse(alloc, l),
            .list_ordored => list.parseOrdored(alloc, l),
            .list_unordored => list.parseUnordored(alloc, l),
            .image => link.parseImage(alloc, l),
            .code_block => code.parse(alloc, l),
            .quote => quote.parse(alloc, l),
            .math_block => math.parse(alloc, l),
            .weak_delimiter, .strong_delimiter => {
                l.consume();
                continue :base;
            },
            else =>
            // block paragraph
            if (it.kind.isInParagraph())
                paragraph.parse(alloc, l)
            else
                Error.FeatureNotSupported,
        } catch |err| {
            if (err == Error.OutOfMemory) return Error.OutOfMemory;
            var end = l.iter.i;
            if (beg == end) end += 1;
            try doc_errors.append(parent, .{
                .err = err,
                .location = .{ .beg = beg, .end = end, .line = l.current_line },
            });
            _ = l.next();
            // consume until next delimiter
            while (l.next()) |next| if (next.kind.isDelimiter()) continue :base;
            break :base;
        };
        root.append(v);
    }
    return .{ .root = root, .errors = if (doc_errors.items.len == 0) null else try doc_errors.toOwnedSlice(parent) };
}

fn doTest(alloc: Allocator, t: []const u8, v: []const u8) !void {
    const g = try parse(alloc, t);
    defer g.deinit(alloc);
    if (g.errors) |errors| {
        for (errors) |it| std.debug.print("{}: {s}\n", .{ it.err, it.extract(t) });
        try std.testing.expect(false);
    }
    const res = try g.root.renderHTML(alloc);
    defer alloc.free(res);
    std.testing.expect(std.mem.eql(u8, res, v)) catch |err| {
        std.debug.print("{s}\n", .{res});
        return err;
    };
}

test "parse multilines" {
    const alloc = std.testing.allocator;

    try doTest(alloc, "hello world", "<p>hello world</p>");
    try doTest(alloc, "# foo", "<h1>foo</h1>");
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
    defer g.deinit(alloc);
    const a = try g.root.renderHTML(alloc);
    const b = try g.root.renderHTML(alloc);
    try std.testing.expect(std.mem.eql(u8, a, b));
}
