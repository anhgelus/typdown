const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
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
            if (eql(u8, rune, "\r")) continue;
            // escape chars
            if (eql(u8, rune, "\\")) {
                self.force_lit = true;
                current_kind = .literal;
            } else {
                self.force_lit = false;
                current_kind = self.getCurrentKind(current_kind, rune, acc.items).kind;
                try acc.appendSlice(alloc, rune);
            }
            // conds here to avoid creating complex condition in while
            const next_rune = self.iter.peek(1);
            if (next_rune.len > 0) {
                const next_kind = self.getCurrentKind(current_kind, next_rune, acc.items);
                if (next_kind.kind != current_kind.? and
                    (next_kind.dont_break_if == null or next_kind.dont_break_if != current_kind.?))
                {
                    if (!requiresSpace(current_kind.?)) break;
                    if (eql(u8, next_rune, " ")) {
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

    const kindRes = struct {
        kind: lexed.Kind,
        dont_break_if: ?lexed.Kind = null,
    };

    fn getCurrentKind(self: *Self, before: ?lexed.Kind, rune: []const u8, acc: []const u8) kindRes {
        if (self.force_lit) return .{ .kind = .literal };
        if (eql(u8, rune, ">")) return .{ .kind = .quote };
        if (eql(u8, rune, "\n")) return .{ .kind = .delimiter };
        if (eql(u8, rune, "!")) return .{ .kind = .image };
        if (is('#', 6, rune, acc)) return .{ .kind = .title };
        if (is('`', 3, rune, acc)) return .{ .kind = .code };
        if (is('$', 3, rune, acc)) return .{ .kind = .math };
        if (isIn(links, before, .link, rune, acc)) return .{ .kind = .link };
        if (isIn(refs, before, .ref, rune, acc)) return .{ .kind = .ref };
        return .{ .kind = .literal };
    }
};

fn is(v: u8, maxLen: usize, rune: []const u8, acc: []const u8) bool {
    if (acc.len >= maxLen) return false;
    for (0..acc.len) |i| if (acc[i] != v) return false;
    return eql(u8, rune, &[_]u8{v});
}

const links = &[_][]const u8{ "[", "](", ")" };
const refs = &[_][]const u8{ "<", ":" };

fn isIn(ops: []const []const u8, before: ?lexed.Kind, now: lexed.Kind, rune: []const u8, p: []const u8) bool {
    var acc = p;
    if (before) |b| {
        if (now != b) acc = &[_]u8{};
    }
    for (ops) |op| {
        const ln = acc.len + rune.len;
        if (op.len >= ln and
            (acc.len == 0 or eql(u8, acc, op[0..acc.len])) and
            eql(u8, rune, op[acc.len..ln]))
            return true;
    }
    return false;
}

fn requiresSpace(k: lexed.Kind) bool {
    return switch (k) {
        .title => true,
        .list_ordored => true,
        .list_unordored => true,
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
    try doTest(alloc, &l, .literal, "hello world ");
    try doTest(alloc, &l, .ref, ":");
    try doTest(alloc, &l, .link, ")");

    try expect(try l.next(alloc) == null);
}
