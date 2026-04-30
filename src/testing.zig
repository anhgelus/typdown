const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const parser = @import("parser.zig");

const ParserFn = fn (Allocator, *Lexer) parser.Error!Element;

pub fn do(comptime parse: ParserFn, parent: Allocator, t: []const u8, v: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    var alloc = arena.allocator();

    var l = try Lexer.init(t);
    var p = try parse(alloc, &l);
    const g = try p.renderHTML(alloc);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("got: {s}\nwanted: {s}\n", .{ g, v });
        return err;
    };
}

pub fn doError(comptime parse: ParserFn, parent: Allocator, t: []const u8, err: parser.Error) !void {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();

    var l = try Lexer.init(t);
    _ = parse(arena.allocator(), &l) catch |e| {
        return std.testing.expect(err == e) catch |v| {
            std.debug.print("{}\n", .{v});
            return e;
        };
    };
    return error.ExpectingError;
}

pub fn doMath(comptime parse: ParserFn, parent: Allocator, t: []const u8, v: []const u8) !void {
    if (@import("config").short) return;
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    var alloc = arena.allocator();

    var l = try Lexer.init(t);
    var p = try parse(alloc, &l);
    const g = try p.renderHTML(alloc);
    defer alloc.free(g);
    try std.testing.expect(blk: {
        var g_iter = std.mem.splitSequence(u8, g, " ");
        var v_iter = std.mem.splitSequence(u8, v, " ");
        while (g_iter.next()) |g_it| {
            const v_it = v_iter.next() orelse break :blk false;
            if ((std.mem.startsWith(u8, g_it, "xlink:href=") and std.mem.startsWith(u8, g_it, "xlink:href")) or
                (std.mem.startsWith(u8, g_it, "id=") and std.mem.startsWith(u8, v_it, "id="))) continue;
            if (!std.mem.eql(u8, g_it, v_it)) {
                std.debug.print("not the same: {s} vs {s}\n", .{ g_it, v_it });
                break :blk false;
            }
        }
        break :blk v_iter.next() == null;
    });
}
