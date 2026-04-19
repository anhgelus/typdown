const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const Element = @import("dom/Element.zig");
const parser = @import("parser.zig");

pub fn do(comptime parse: fn(Allocator, *Lexer) parser.Error!Element, alloc: Allocator, t: []const u8, v: []const u8) !void {
    var l = try Lexer.init(t);
    var p = try parse(alloc, &l);
    defer p.deinit();
    const g = try p.render(alloc);
    defer alloc.free(g);
    std.testing.expect(std.mem.eql(u8, g, v)) catch |err| {
        std.debug.print("{s}\n", .{g});
        return err;
    };
}

pub fn doError(comptime parse: fn(Allocator, *Lexer) parser.Error!Element, alloc: Allocator, t: []const u8, err: parser.Error) !void {
    var l = try Lexer.init(t);
    _ = parse(alloc, &l) catch |e| return std.testing.expect(err == e);
    return std.testing.expect(false);
}
