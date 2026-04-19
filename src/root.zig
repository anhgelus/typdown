const std = @import("std");
pub const parser = @import("parser.zig");
pub const Error = parser.Error;

fn getErrorCode(err: Error) u8 {
    return switch (err) {
        Error.OutOfMemory => 1,
        Error.InvalidUtf8 => 2,
        Error.FeatureNotSupported => 3,
        Error.ModifierNotClosed => 4,
        Error.InvalidTitleContent => 5,
    };
}

/// Returns the static string linked with the error code.
export fn getErrorString(code: u8) [*:0]const u8 {
    return switch (code) {
        1 => "out of memory",
        2 => "invalid UTF-8",
        3 => "feature not supported",
        4 => "modifier not closed",
        5 => "invalid title content",
        else => unreachable,
    };
}

/// Parse the content.
/// Code is a pointer to an u8 populated with an error code > 0.
///
/// Returns a not null strings and set the code to 0 if everything is fine.
/// Else, it returns null and set an error code above 0.
/// Use getErrorString to retrieve the string linked with the error code.
export fn parse(content: [*:0]const u8, code: *u8) ?[*:0]const u8 {
    const alloc = std.heap.c_allocator;
    const res = parser.parse(alloc, std.mem.span(content)) catch |err| {
        code.* = getErrorCode(err);
        return null;
    };
    defer alloc.free(res);
    code.* = 0;
    return alloc.dupeZ(u8, res) catch |err| {
        code.* = getErrorCode(err);
        return null;
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}

fn doTest(content: [*:0]const u8, exp: []const u8, exp_code: u8) !void {
    const expect = std.testing.expect;

    var code: u8 = undefined;
    const raw = parse(content, &code) orelse {
        expect(code == exp_code) catch |err| {
            std.debug.print("{}\n", .{code});
            return err;
        };
        return;
    };
    const res = std.mem.span(raw);
    defer std.heap.c_allocator.free(res);

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
