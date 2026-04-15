const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const lexed = @import("lexed.zig");

pub const Lexer = struct {
    iter: unicode.Utf8Iterator,
    force_lit: bool = false,

    const Self = @This();

    pub const Error = error{
        InvalidUtf8,
    } || Allocator.Error;

    pub fn init(content: []const u8) Error!Lexer {
        const view = try unicode.Utf8View.init(content);
        return .{ .iter = view.iterator() };
    }

    pub fn next(self: *Self, alloc: Allocator) Error!?lexed.Lexed {
        var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
        errdefer acc.deinit(alloc);

        var current_kind: ?lexed.Kind = null;
        while (self.iter.nextCodepointSlice()) |rune| {
            if (std.mem.eql(u8, rune, "\r")) continue;
            // escape chars
            if (std.mem.eql(u8, rune, "\\")) {
                self.force_lit = true;
                current_kind = .literal;
            } else {
                current_kind = self.getCurrentKind(current_kind, rune, acc.items);
                self.force_lit = false;
                try acc.appendSlice(alloc, rune);
            }
            // conds here to avoid creating complex condition in while
            const next_rune = self.iter.peek(1);
            if (next_rune.len > 0) {
                if (self.getCurrentKind(current_kind, next_rune, acc.items) != current_kind.?) {
                    if (!requiresSpace(current_kind.?)) break;
                    if (std.mem.eql(u8, next_rune, " ")) {
                        // consume next space
                        _ = self.iter.nextCodepoint();
                        break;
                    }
                    current_kind = .literal;
                }
            }
        }
        const kind = current_kind orelse {
            acc.deinit(alloc);
            return null;
        };
        return lexed.Lexed.init(alloc, kind, acc);
    }

    fn getCurrentKind(self: *Self, before: ?lexed.Kind, rune: []const u8, acc: []const u8) lexed.Kind {
        if (self.force_lit) return .literal;
        if (std.mem.eql(u8, rune, ">")) return .quote;
        if (std.mem.eql(u8, rune, "\n")) return .delimiter;
        if (std.mem.eql(u8, rune, "!")) return .image;
        if (is('#', 6, rune, acc)) return .title;
        if (is('`', 3, rune, acc)) return .code;
        if (is('$', 3, rune, acc)) return .math;
        if (isIn(links, before, .link, rune, acc)) return .link;
        return .literal;
    }
};

fn is(v: u8, maxLen: usize, rune: []const u8, acc: []const u8) bool {
    if (acc.len >= maxLen) return false;
    for (0..acc.len) |i| if (acc[i] != v) return false;
    return std.mem.eql(u8, rune, &[_]u8{v});
}

const links = &[_][]const u8{ "[", "](", ")" };

fn isIn(ops: []const []const u8, before: ?lexed.Kind, now: lexed.Kind, rune: []const u8, p: []const u8) bool {
    var acc = p;
    if (before) |b| {
        if (now != b) acc = &[_]u8{};
    }
    for (ops) |op| {
        const ln = acc.len + rune.len;
        if (op.len >= ln and std.mem.eql(u8, acc, op[0..acc.len]) and std.mem.eql(u8, rune, op[acc.len..ln]))
            return true;
    }
    return false;
}

fn requiresSpace(k: lexed.Kind) bool {
    return switch (k) {
        .title => true,
        else => false,
    };
}

fn doTest(alloc: Allocator, l: *Lexer, k: lexed.Kind, v: []const u8) !void {
    var first = (try l.next(alloc)).?;
    defer first.deinit();
    std.testing.expect(first.equals(k, v)) catch |err| {
        std.debug.print("{}({s})\n", .{ first.kind, first.content.items });
        return err;
    };
}

test "lexer common" {
    const expect = std.testing.expect;

    var arena = std.heap.DebugAllocator(.{}).init;
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    var l = try Lexer.init("# hello world :)");

    try doTest(alloc, &l, .title, "#");
    try doTest(alloc, &l, .literal, "hello world :");
    try doTest(alloc, &l, .link, ")");

    try expect(try l.next(alloc) == null);
}
