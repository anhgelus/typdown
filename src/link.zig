const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const Token = @import("lexer/Token.zig");
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const Link = Element.paragraph.Link;
const content = @import("content.zig");
const paragraph = @import("paragraph.zig");
const testing = @import("testing.zig");
const doTest = testing.do;
const doTestError = testing.doError;

pub const Error = error{InvalidLink} || content.Error || Allocator.Error;

pub fn parse(alloc: Allocator, l: *Lexer) Error!Element {
    const v = l.next().?;
    if (v.kind != .link) return Error.InvalidLink;
    if (!eql(u8, v.content, "[")) return (try Element.Literal.init(alloc, v.content)).element();
    var el = try Element.Root.init(alloc);
    while (l.peek()) |next| switch (next.kind) {
        .weak_delimiter, .strong_delimiter => return Error.InvalidLink,
        .link => {
            l.consume();
            if (!eql(u8, next.content, "](")) return Error.InvalidLink;
            break;
        },
        else => {
            const in = try content.parse(el.allocator(), l);
            el.append(in);
        },
    };
    const href = l.next() orelse return Error.InvalidLink;
    if (href.kind != .literal) return Error.InvalidLink;
    const finisher = l.next() orelse return Error.InvalidLink;
    if (!finisher.equals(.link, ")")) return Error.InvalidLink;
    const in: Element = if (el.content.first != null)
        el.element()
    else blk: {
        el.deinit();
        break :blk (try Element.Literal.init(alloc, href.content)).element();
    };
    return (try Link.init(alloc, in, href.content)).element();
}

pub const ImageError = error{InvalidImage} || paragraph.Error || Allocator.Error;

pub fn parseImage(alloc: Allocator, l: *Lexer) ImageError!Element {
    _ = l.next().?;
    const beg = l.next() orelse return ImageError.InvalidImage;
    if (!eql(u8, beg.content, "[")) return ImageError.InvalidImage;
    var it = l.next() orelse return ImageError.InvalidImage;
    var alt: ?[]const u8 = null;
    switch (it.kind) {
        .link => if (!eql(u8, it.content, "](")) return ImageError.InvalidImage,
        .literal => {
            alt = it.content;
            const next = l.next() orelse return ImageError.InvalidImage;
            if (!next.equals(.link, "](")) return ImageError.InvalidImage;
        },
        else => return ImageError.InvalidImage,
    }
    it = l.next() orelse return ImageError.InvalidImage;
    if (it.kind != .literal) return ImageError.InvalidImage;
    const src = it.content;
    it = l.next() orelse return ImageError.InvalidImage;
    if (!it.equals(.link, ")")) return ImageError.InvalidImage;
    const img = try Element.Image.init(alloc, src);
    img.alt = alt;
    const el = try Element.Figure.init(alloc, img.element());
    it = l.peek() orelse return el.element();
    switch (it.kind) {
        .strong_delimiter => return el.element(),
        .weak_delimiter => l.consume(),
        else => return ImageError.InvalidImage,
    }
    const p = try paragraph.parse(alloc, l);
    const p_el: *Element.paragraph.Block = @ptrCast(@alignCast(p.ptr));
    el.caption = (try p_el.toRoot(alloc)).element();
    return el.element();
}

test "parse links" {
    const alloc = std.testing.allocator;

    try doTest(parse, alloc, "[](bar)", "<a href=\"bar\">bar</a>");
    try doTest(parse, alloc, "[foo](bar)", "<a href=\"bar\">foo</a>");
    try doTest(parse, alloc, "[f*o*o](bar)", "<a href=\"bar\">f<b>o</b>o</a>");
    try doTest(parse, alloc, ")", ")");

    try doTestError(parse, alloc, "[foo :::](bar)", Error.IllegalPlacement);
    try doTestError(parse, alloc, "[foo", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo](", Error.InvalidLink);
    try doTestError(parse, alloc, "[foo]()", Error.InvalidLink);
}

test "parse image" {
    const alloc = std.testing.allocator;

    try doTest(parseImage, alloc, "![](src)", "<figure><img src=\"src\"></figure>");
    try doTest(parseImage, alloc, "![alt](src)", "<figure><img src=\"src\" alt=\"alt\"></figure>");

    try doTest(parseImage, alloc,
        \\![bar](foo)
        \\caption
        \\on multiple lines!
        \\
        \\not in
    , "<figure><img src=\"foo\" alt=\"bar\"><figcaption>caption on multiple lines!</figcaption></figure>");
}
