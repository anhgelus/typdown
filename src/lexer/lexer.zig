const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const lexed = @import("lexed.zig");

const operators = [_][]const u8{ "*", "_", "`", "<", ">", ":", "!", "[", "]", "(", ")", "$", "-", "." };
const delimiters = [_][]const u8{"\n"};

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
                current_kind = self.getCurrentKind(rune); 
                self.force_lit = false;
                try acc.appendSlice(alloc, rune);
            }
            // conds here to avoid creating complex condition in while
            const next_rune = self.iter.peek(1);
            if (next_rune.len > 0) {
                if (self.getCurrentKind(next_rune) != current_kind.?) break;
            }
        }
        const kind = current_kind orelse {
            acc.deinit(alloc);
            return null;
        };
        return lexed.Lexed.init(alloc, kind, acc);
    }

    fn getCurrentKind(self: *Self, rune: []const u8) ?lexed.Kind {
        if (self.force_lit) return .literal;
        if (isIn(&operators, rune)) {
            return .operator;
        } else if (isIn(&delimiters, rune)) {
            return .delimiter;
        }
        return .literal;
    }
};

fn isIn(arr: []const []const u8, v: []const u8) bool {
    for (arr) |it| if (std.mem.eql(u8, it, v)) return true;
    return false;
}

test "literal" {
    const expect = std.testing.expect;

    var arena = std.heap.DebugAllocator(.{}){};
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    var l = try Lexer.init("hello world :)");

    var first = (try l.next(alloc)).?;
    defer first.deinit();
    try expect(first.equals(.literal, "hello world "));

    var second = (try l.next(alloc)).?;
    defer second.deinit();
    try expect(second.equals(.operator, ":)"));

    try expect(try l.next(alloc) == null);
}
