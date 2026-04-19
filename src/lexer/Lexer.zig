const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const unicode = std.unicode;
const Lexed = @import("Lexed.zig");

iter: unicode.Utf8Iterator,
force_lit: bool = false,

const Self = @This();

pub const Error = error{
    InvalidUtf8,
} || Allocator.Error;

pub fn init(content: []const u8) error{InvalidUtf8}!Self {
    const view = try unicode.Utf8View.init(content);
    return .{ .iter = view.iterator() };
}

// Must free bytes in iter.
pub fn initReader(alloc: Allocator, r: *std.io.Reader) !Self {
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    try r.appendRemainingUnlimited(alloc, &acc);
    return init(try acc.toOwnedSlice(alloc));
}

pub fn nextKind(self: *Self) ?Lexed.Kind {
    const next_rune = self.iter.peek(1);
    if (next_rune.len == 0) return null;
    return self.getCurrentKind(null, next_rune, &[0]u8{}).kind;
}

pub fn next(self: *Self, alloc: Allocator) Error!?Lexed {
    var acc = try std.ArrayList(u8).initCapacity(alloc, 2);
    errdefer acc.deinit(alloc);

    var current_kind: ?Lexed.Kind = null;
    while (self.iter.nextCodepointSlice()) |rune| {
        if (eql(u8, rune, "\r")) continue;
        var override_if: ?[]const u8 = null;
        // escape chars
        if (eql(u8, rune, "\\")) {
            self.force_lit = true;
            current_kind = .literal;
        } else {
            self.force_lit = false;
            const res = self.getCurrentKind(current_kind, rune, acc.items);
            current_kind = res.kind;
            override_if = res.override_if;
            try acc.appendSlice(alloc, rune);
        }
        // conds here to avoid creating complex condition in while
        const next_rune = self.iter.peek(1);
        const next_kind = self.getCurrentKind(current_kind, next_rune, acc.items).kind;
        if (requiresSpace(current_kind.?) and next_kind != current_kind.?) {
            if (eql(u8, next_rune, " ")) {
                // consume next space
                _ = self.iter.nextCodepoint();
                break;
            }
            current_kind = switch (current_kind.?) {
                .title => if (acc.items.len == 1) .tag else .literal,
                else => .literal,
            };
        }
        if (next_rune.len > 0 and
            next_kind != current_kind.? and
            (override_if == null or !eql(u8, override_if.?, next_rune)))
            break;
    }
    const kind = current_kind orelse {
        acc.deinit(alloc);
        return null;
    };
    return .init(alloc, kind, acc);
}

const kindRes = struct {
    kind: Lexed.Kind,
    override_if: ?[]const u8 = null,

    fn equals(self: @This(), v: @This()) bool {
        if (self.kind != v.kind) return false;
        if (self.override_if == null and v.override_if != null) return false;
        if (self.override_if != null and v.override_if == null) return false;
        if (self.override_if) |it| return eql(u8, it, v.override_if.?);
        return true;
    }
};

fn requiresDelimiter(before: ?Lexed.Kind, knd: Lexed.Kind) Lexed.Kind {
    return if (before == null or before.?.isDelimiter() or before.? == knd) knd else .literal;
}

fn getCurrentKind(self: *Self, before: ?Lexed.Kind, rune: []const u8, acc: []const u8) kindRes {
    if (self.force_lit) return .{ .kind = .literal };
    if (eql(u8, rune, "\n")) return .{
        .kind = if (before == .weak_delimiter) .strong_delimiter else .weak_delimiter,
        .override_if = rune,
    };
    if (eql(u8, rune, "*")) return .{ .kind = .bold };
    if (eql(u8, rune, "_")) return .{ .kind = .italic };
    if (eql(u8, rune, ">")) return .{ .kind = requiresDelimiter(before, .quote) };
    if (eql(u8, rune, ".")) return .{ .kind = requiresDelimiter(before, .list_ordored) };
    if (eql(u8, rune, "-")) return .{ .kind = requiresDelimiter(before, .list_unordored) };
    if (eql(u8, rune, "!")) return .{ .kind = requiresDelimiter(before, .image) };
    if (eql(u8, rune, "<")) return .{ .kind = .ref };
    if (is('#', 6, rune, acc)) return .{ .kind = requiresDelimiter(before, .title) };
    if (isIn(links, rune, acc, before, .link)) return .{ .kind = .link };
    if (isOneOrThree(":", rune, acc, .ref, .callout)) |it| return it;
    if (isOneOrThree("$", rune, acc, .math, .math_block)) |it| return it;
    if (isOneOrThree("`", rune, acc, .code, .code_block)) |it| return it;
    return .{ .kind = .literal };
}

fn is(v: u8, maxLen: usize, rune: []const u8, acc: []const u8) bool {
    if (!eql(u8, rune, &[_]u8{v})) return false;
    for (acc) |it| if (it != v) return true;
    return acc.len < maxLen;
}

const links = &[_][]const u8{ "[", "](", ")" };

fn isIn(ops: []const []const u8, rune: []const u8, p: []const u8, before: ?Lexed.Kind, now: Lexed.Kind) bool {
    var acc = p;
    if (before) |b| {
        if (now != b) acc = &[_]u8{};
    }
    for (ops) |op| {
        const ln = acc.len + rune.len;
        if (op.len >= ln and eql(u8, acc, op[0..acc.len]) and eql(u8, rune, op[acc.len..ln]))
            return true;
    }
    return false;
}

fn isOneOrThree(op: []const u8, rune: []const u8, p: []const u8, one: Lexed.Kind, three: Lexed.Kind) ?kindRes {
    if (!eql(u8, rune, op)) return null;
    var acc = p;
    if (acc.len < op.len or !eql(u8, acc[0..op.len], op)) acc = &[_]u8{};

    var iter = (unicode.Utf8View.init(acc) catch unreachable).iterator();
    var ln: usize = 1; // number of runes
    while (iter.nextCodepointSlice()) |it| : (ln += 1) {
        if (!eql(u8, it, op)) return null;
    }

    return switch (ln) {
        1 => .{
            .kind = one,
            .override_if = op,
        },
        2 => .{
            .kind = .literal,
            .override_if = op,
        },
        3 => .{ .kind = three },
        else => unreachable,
    };
}

fn requiresSpace(k: Lexed.Kind) bool {
    return switch (k) {
        .title, .list_ordored, .list_unordored => true,
        else => false,
    };
}

fn doTest(alloc: Allocator, l: *Self, k: Lexed.Kind, v: []const u8) !void {
    var first = (try l.next(alloc)).?;
    defer first.deinit();
    std.testing.expect(first.equals(k, v)) catch |err| {
        std.debug.print("{}({s})\n", .{ first.kind, first.content.items });
        return err;
    };
}

test "one or three" {
    const expect = std.testing.expect;

    // valid
    try expect(isOneOrThree(":", ":", "", .ref, .callout).?.equals(.{ .kind = .ref, .override_if = ":" }));
    try expect(isOneOrThree(":", ":", ":", .ref, .callout).?.equals(.{ .kind = .literal, .override_if = ":" }));
    try expect(isOneOrThree(":", ":", "::", .ref, .callout).?.equals(.{ .kind = .callout }));
    try expect(isOneOrThree(":", ":", "a", .ref, .callout).?.equals(.{ .kind = .ref, .override_if = ":" }));

    // invalid
    try expect(isOneOrThree(":", "a", "", .ref, .callout) == null);
    try expect(isOneOrThree(":", "a", "b", .ref, .callout) == null);
    try expect(isOneOrThree(":", "a", ":", .ref, .callout) == null);
}

test "is" {
    const expect = std.testing.expect;

    // valid
    try expect(is('#', 6, "#", ""));
    try expect(is('#', 6, "#", "#"));
    try expect(is('#', 6, "#", "##"));
    try expect(is('#', 6, "#", "###"));
    try expect(is('#', 6, "#", "####"));
    try expect(is('#', 6, "#", "#####"));

    // invalid
    try expect(!is('#', 6, "#", "######"));
    try expect(!is('#', 6, "u", "##"));
}

test "lexer common" {
    const expect = std.testing.expect;

    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    var l = try init("## hello world :)");

    try doTest(alloc, &l, .title, "##");
    try doTest(alloc, &l, .literal, "hello world ");
    try doTest(alloc, &l, .ref, ":");
    try doTest(alloc, &l, .link, ")");

    try expect(try l.next(alloc) == null);
}

test "lexer multiline" {
    const expect = std.testing.expect;

    var arena = std.heap.DebugAllocator(.{}).init;
    defer if (arena.deinit() == .leak) std.debug.print("leaking!\n", .{});
    const alloc = arena.allocator();

    var l = try init(
        \\# Title
        \\
        \\paragraph
        \\# a title
        \\a # in sentence
        \\
        \\#tag
        \\#tag2
    );

    try doTest(alloc, &l, .title, "#");
    try doTest(alloc, &l, .literal, "Title");
    try doTest(alloc, &l, .strong_delimiter, "\n\n");
    try doTest(alloc, &l, .literal, "paragraph");
    try doTest(alloc, &l, .weak_delimiter, "\n");
    try doTest(alloc, &l, .title, "#");
    try doTest(alloc, &l, .literal, "a title");
    try doTest(alloc, &l, .weak_delimiter, "\n");
    try doTest(alloc, &l, .literal, "a # in sentence");
    try doTest(alloc, &l, .strong_delimiter, "\n\n");
    try doTest(alloc, &l, .tag, "#");
    try doTest(alloc, &l, .literal, "tag");
    try doTest(alloc, &l, .weak_delimiter, "\n");
    try doTest(alloc, &l, .tag, "#");
    try doTest(alloc, &l, .literal, "tag2");

    try expect(try l.next(alloc) == null);
}
