const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const testing = @import("testing.zig");
const paragraph = @import("paragraph.zig");
const doTest = testing.do;
const doMathTest = testing.doMath;
const doTestError = testing.doError;

fn Figure(comptime E: type, comptime kind: Token.Kind, comptime V: type) type {
    comptime {
        if (!@hasDecl(V, "err")) @compileError("missing declaration 'err' for " ++ @typeName(V));
        if (!std.meta.hasMethod(V, "parseParams"))
            @compileError("missing method 'parseParams' for " ++ @typeName(V));
        if (!std.meta.hasMethod(V, "parseBody"))
            @compileError("missing method 'parseBody' for " ++ @typeName(V));
    }
    const err = V.err;
    return struct {
        pub const Error = @TypeOf(err) || paragraph.Error || Allocator.Error;

        pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
            _ = l.next();
            _ = l.peek() orelse return err;
            const got: Element = try V.parseParams(alloc, l);
            l.isValid();
            try V.parseBody(alloc, l, got.as(E));
            l.isValid();
            const end = l.next() orelse return err;
            if (end.kind != kind) return err;
            const el = try Element.Figure.init(alloc, got);
            const next = l.peek() orelse return el.element();
            switch (next.kind) {
                .strong_delimiter => return el.element(),
                .weak_delimiter => l.consume(),
                else => return err,
            }
            l.isValid();
            const p = (try paragraph.parse(alloc, l)).as(Element.paragraph.Block);
            if (p.content == null) return el.element();
            el.caption = (try p.toRoot(alloc)).element();
            return el.element();
        }
    };
}

pub const Code = Figure(Element.Code, .code_block, struct {
    pub const err = error.InvalidCodeBlock;

    pub fn parseParams(alloc: Allocator, l: *Lexer) !Element {
        var beg = l.next().?;
        var data: ?[]const u8 = null;
        switch (beg.kind) {
            .literal => {
                data = beg.content;
                beg = l.next() orelse return err;
                if (!beg.kind.isDelimiter()) return err;
            },
            else => if (!beg.kind.isDelimiter()) return err,
        }
        const code = try Element.Code.init(alloc);
        code.attribute = data;
        return code.element();
    }

    pub fn parseBody(alloc: Allocator, l: *Lexer, code: *Element.Code) !void {
        while (l.next()) |it| {
            if (it.kind == .code_block) return err;
            if (it.kind.isDelimiter()) {
                const next = l.peek() orelse return err;
                if (next.kind == .code_block) break;
            }
            try code.content.append(alloc, (try Element.Literal.init(alloc, it.content)).element());
            // restore modifications done by the lexer
            if (it.kind.requiresSpace())
                try code.content.append(alloc, (try Element.Literal.init(alloc, " ")).element());
        }
    }
});

pub const Image = Figure(Element.Image, .link, struct {
    pub const err = error.InvalidImage;
    const eql = std.mem.eql;

    pub fn parseParams(alloc: Allocator, l: *Lexer) !Element {
        const beg = l.next() orelse return err;
        if (!eql(u8, beg.content, "[")) return err;
        var it = l.next() orelse return err;
        var alt: ?[]const u8 = null;
        switch (it.kind) {
            .link => if (!eql(u8, it.content, "](")) return err,
            .literal => {
                alt = it.content;
                l.isValid();
                const next = l.next() orelse return err;
                if (!next.equals(.link, "](")) return err;
            },
            else => return err,
        }
        l.isValid();
        it = l.next() orelse return err;
        if (it.kind != .literal) return err;
        const src = it.content;
        it = l.peek() orelse return err;
        if (!it.equals(.link, ")")) return err;
        const img = try Element.Image.init(alloc, src);
        img.alt = alt;
        return img.element();
    }

    pub fn parseBody(_: Allocator, _: *Lexer, _: *Element.Image) !void {
        return;
    }
});

pub const Math = Figure(Element.Math.Block, .math_block, struct {
    pub const err = error.InvalidMathBlock;

    pub fn parseParams(alloc: Allocator, l: *Lexer) !Element {
        const beg = l.next() orelse return err;
        if (!beg.kind.isDelimiter()) return err;
        return (try Element.Math.Block.init(alloc)).element();
    }

    pub fn parseBody(alloc: Allocator, l: *Lexer, math: *Element.Math.Block) !void {
        var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
        while (l.next()) |it| {
            if (it.kind == .math_block) return err;
            try acc.appendSlice(alloc, it.content);
            // restore modifications done by the lexer
            if (it.kind.requiresSpace())
                try acc.append(alloc, ' ');
            if (it.kind.isDelimiter()) {
                const next = l.peek() orelse return err;
                if (next.kind == .math_block) break;
            }
        }
        math.content = try acc.toOwnedSlice(alloc);
    }
});

test "code" {
    const alloc = std.testing.allocator;
    const parse = Code.parse;
    const Error = Code.Error;

    try doTest(parse, alloc,
        \\```
        \\hey
        \\```
    , "<figure><pre><code>hey</code></pre></figure>");
    try doTest(parse, alloc,
        \\```td another
        \\hey
        \\```
        \\Caption ;3
    , "<figure><pre data-code=\"td another\"><code>hey</code></pre><figcaption>Caption ;3</figcaption></figure>");
    // cannot test content with \n

    try doTestError(parse, alloc, "```", Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey
    , Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey```
    , Error.InvalidCodeBlock);
    try doTestError(parse, alloc,
        \\```
        \\hey
        \\``` nope
    , Error.InvalidCodeBlock);
}

test "image" {
    const alloc = std.testing.allocator;
    const parse = Image.parse;

    try doTest(parse, alloc, "![](src)", "<figure><img src=\"src\"></figure>");
    try doTest(parse, alloc, "![alt](src)", "<figure><img src=\"src\" alt=\"alt\"></figure>");

    try doTest(parse, alloc,
        \\![bar](foo)
        \\caption
        \\on multiple lines!
        \\
        \\not in
    , "<figure><img src=\"foo\" alt=\"bar\"><figcaption>caption on multiple lines!</figcaption></figure>");
}

test "math" {
    const alloc = std.testing.allocator;
    const parse = Math.parse;

    try doMathTest(parse, alloc,
        \\$$$
        \\x
        \\$$$
    , "<figure>" ++ @embedFile("data/block_1.svg") ++ "</figure>");
    try doMathTest(parse, alloc,
        \\$$$
        \\x^2
        \\$$$
    , "<figure>" ++ @embedFile("data/block_2.svg") ++ "</figure>");
    try doMathTest(parse, alloc,
        \\$$$
        \\forall x in RR, quad f(x) = x^2
        \\$$$
        \\UwU, I am a caption :D
    , "<figure>" ++ @embedFile("data/block_3.svg") ++ "<figcaption>UwU, I am a caption :D</figcaption></figure>");
}
