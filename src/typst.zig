const std = @import("std");
const typst = @cImport(@cInclude("typdown_typst.h"));

pub fn generateSVG(alloc: std.mem.Allocator, content: []const u8) ![]const u8 {
    const source = try alloc.dupeZ(u8, content);
    defer alloc.free(source);
    const raw_res = typst.typst_generateSVG(source);
    const res = try alloc.dupe(u8, std.mem.span(raw_res));
    defer typst.typst_freeString(raw_res);
    return res;
}
