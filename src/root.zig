const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
pub const Document = parser.Document;
pub const Error = parser.Error;
/// Parse the content.
///
/// Use typdown_parse if you are not in Zig.
pub const parse = parser.parse;

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

var default_alloc: std.mem.Allocator =
    if (builtin.target.isWasiLibC())
        std.heap.wasm_allocator
    else if (builtin.is_test)
        std.testing.allocator
    else
        std.heap.c_allocator;

/// Parse the content.
/// Code is a pointer to an u8 populated with an error code > 0.
///
/// Returns a not null strings and set the code to 0 if everything is fine.
/// Else, it returns null and set an error code above 0.
/// Use typdown_getErrorString to retrieve the string linked with the error code.
/// Use parse if you are in Zig.
export fn typdown_parse(content: [*:0]const u8, code: *u8) ?[*:0]const u8 {
    const doc = parse(default_alloc, std.mem.span(content)) catch |err| {
        code.* = getErrorCode(err);
        return null;
    };
    defer doc.deinit();
    const res = doc.renderHTML(default_alloc) catch |err| {
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

pub fn parseReader(alloc: std.mem.Allocator, r: *std.io.Reader) (Error || std.io.Reader.Error)!*Document {
    return parser.parseReader(alloc, r);
}

test {
    std.testing.refAllDeclsRecursive(@This());
}

fn doTest(content: [*:0]const u8, exp: []const u8, comptime exp_code: u8) !void {
    const expect = std.testing.expect;

    var code: u8 = undefined;
    const raw = typdown_parse(content, &code) orelse {
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
