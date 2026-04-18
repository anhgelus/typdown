const std = @import("std");
const eql = std.mem.eql;

pub fn escape(alloc: std.mem.Allocator, v: []const u8) ![]const u8 {
    var acc = try std.ArrayList(u8).initCapacity(alloc, v.len);
    errdefer acc.deinit(alloc);
    const view = try std.unicode.Utf8View.init(v);
    var iter = view.iterator();
    while (iter.nextCodepointSlice()) |rune| {
        if (eql(u8, rune, "&")) {
            try acc.appendSlice(alloc, "&amp;");
        } else if (eql(u8, rune, "'")) {
            try acc.appendSlice(alloc, "&#39;");
        } else if (eql(u8, rune, "<")) {
            try acc.appendSlice(alloc, "&lt;");
        } else if (eql(u8, rune, ">")) {
            try acc.appendSlice(alloc, "&gt;");
        } else if (eql(u8, rune, "\"")) {
            try acc.appendSlice(alloc, "&#34;");
        } else {
            try acc.appendSlice(alloc, rune);
        }
    }
    return acc.toOwnedSlice(alloc);
}

fn doTest(alloc: std.mem.Allocator, el: []const u8, exp: []const u8) !void {
    const got = try escape(alloc, el);
    defer alloc.free(got);
    std.testing.expect(eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "escaping html" {
    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    try doTest(alloc, "hello world", "hello world");
    try doTest(alloc, "hello&world", "hello&amp;world");
    try doTest(alloc, "hello'world", "hello&#39;world");
    try doTest(alloc, "hello<world", "hello&lt;world");
    try doTest(alloc, "hello>world", "hello&gt;world");
    try doTest(alloc, "hello\"world", "hello&#34;world");
}
