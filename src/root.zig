const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const Element = @import("eval/Element.zig");
pub const Document = parser.Document;
pub const Error = parser.Error;
/// Parse the content.
///
/// Use typdown_parse if you are not in Zig.
pub const parse = parser.parse;
pub const parseReader = parser.parseReader;

inline fn getErrorCode(err: Error) u8 {
    return switch (err) {
        Error.OutOfMemory => 1,
        Error.InvalidUtf8 => 2,
        Error.FeatureNotSupported => 3,
        Error.ModifierNotClosed => 4,
        Error.InvalidTitleContent => 5,
        Error.IllegalPlacement => 6,
        Error.InvalidLink => 7,
        Error.InvalidImage => 8,
        Error.InvalidCodeBlock => 9,
        Error.InvalidCallout => 10,
        Error.InvalidMathBlock => 11,
    };
}

/// Returns the static string linked with the error code.
export fn typdown_getErrorString(code: u8) [*:0]const u8 {
    return switch (code) {
        1 => "out of memory",
        2 => "invalid UTF-8",
        3 => "feature not supported",
        4 => "modifier not closed",
        5 => "invalid title content",
        6 => "illegal placement",
        7 => "invalid link",
        8 => "invalid image",
        9 => "invalid code block",
        10 => "invalid callout",
        11 => "invalid math block",
        else => unreachable,
    };
}

/// typdown_Document is a Document for the C ABI.
const typdown_Document = extern struct {
    root: ?*anyopaque = null,
    errors: ?[*]typdown_Error = null,
    errors_len: usize = 0,

    const typdown_Error = extern struct {
        code: u8,
        location: extern struct { beg: usize, end: usize },
    };
};

fn from(alloc: Allocator, doc: Document) typdown_Document {
    var res = typdown_Document{ .root = doc.root };
    if (doc.errors) |errors| {
        defer alloc.free(errors);
        res.errors = (alloc.alloc(typdown_Document.typdown_Error, errors.len) catch |err| @panic(@errorName(err))).ptr;
        for (errors) |err| {
            res.errors.?[0] = .{
                .code = getErrorCode(err.err),
                .location = .{ .beg = err.location.beg, .end = err.location.end },
            };
        }
        res.errors_len = errors.len;
    }
    return res;
}

fn fromError(alloc: Allocator, err: Error) typdown_Document {
    var v = alloc.alloc(typdown_Document.typdown_Error, 1) catch |e| @panic(@errorName(e));
    v[0] = .{ .code = getErrorCode(err), .location = .{ .beg = 0, .end = 0 } };
    return .{ .errors = v.ptr, .errors_len = 1 };
}

var default_alloc: std.mem.Allocator =
    if (builtin.target.isWasiLibC())
        std.heap.wasm_allocator
    else if (builtin.is_test)
        std.testing.allocator
    else
        std.heap.c_allocator;

/// Parse the content.
///
/// You must free the document with typdown_free.
export fn typdown_parse(content: [*:0]const u8) typdown_Document {
    const alloc = default_alloc;
    return from(alloc, parse(alloc, std.mem.span(content)) catch |err| {
        return fromError(alloc, err);
    });
}

/// Free the document.
export fn typdown_free(self: typdown_Document) void {
    const alloc = default_alloc;
    if (self.root) |r| {
        const root: *Element.Root = @ptrCast(@alignCast(r));
        root.deinit();
    }
    if (self.errors) |errors| alloc.free(errors[0..self.errors_len]);
}

/// Render an HTML from the document.
export fn typdown_renderHTML(document: typdown_Document, code: *u8) ?[*:0]const u8 {
    const root: *Element.Root = @ptrCast(@alignCast(document.root));
    const res = root.renderHTML(default_alloc) catch |err| {
        code.* = getErrorCode(err);
        return null;
    };
    defer default_alloc.free(res);
    code.* = 0;
    return default_alloc.dupeZ(u8, res) catch |err| {
        code.* = getErrorCode(err);
        return null;
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}

fn doTest(content: [*:0]const u8, exp: []const u8, comptime exp_code: u8) !void {
    const expect = std.testing.expect;

    const doc = typdown_parse(content);
    defer typdown_free(doc);
    if (doc.errors) |errors| {
        for (0..doc.errors_len) |i| if (errors[i].code == exp_code) return;
        return try expect(false);
    }
    var code: u8 = undefined;
    const raw = typdown_renderHTML(doc, &code) orelse {
        expect(code == exp_code) catch |err| {
            std.debug.print("{}\n", .{code});
            return err;
        };
        return;
    };
    const res = std.mem.span(raw);
    defer std.testing.allocator.free(res);

    expect(code == 0) catch |err| {
        std.debug.print("{}\n", .{code});
        return err;
    };
    expect(std.mem.eql(u8, exp, res)) catch |err| {
        std.debug.print("{s}\n", .{res});
        return err;
    };
}

test "exported parse" {
    // valid
    try doTest("hello world", "<p>hello world</p>", 0);
    try doTest("he*ll*o world", "<p>he<b>ll</b>o world</p>", 0);
    try doTest("# title", "<h1>title</h1>", 0);

    // invalid
    try doTest("he*llo world", "", getErrorCode(Error.ModifierNotClosed));
    try doTest("# title :::", "", getErrorCode(Error.InvalidTitleContent));
}
