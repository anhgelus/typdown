const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("eval/Element.zig");
const parser = @import("parser.zig");

pub fn do(comptime parse: fn (Allocator, *Lexer) parser.Error!Element, parent: Allocator, t: []const u8, v: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    var alloc = arena.allocator();

    var l = try Lexer.init(t);
    var p = try parse(alloc, &l);
    const g = try p.renderHTML(alloc);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("{s}\n", .{g});
        return err;
    };
}

pub fn doError(comptime parse: fn (Allocator, *Lexer) parser.Error!Element, parent: Allocator, t: []const u8, err: parser.Error) !void {
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();

    var l = try Lexer.init(t);
    _ = parse(arena.allocator(), &l) catch |e| return std.testing.expect(err == e);
    return std.testing.expect(false);
}
