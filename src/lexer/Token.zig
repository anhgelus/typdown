const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Kind = enum {
    literal,
    weak_delimiter,
    strong_delimiter,
    title,
    quote,
    code,
    code_block,
    math,
    math_block,
    image,
    link,
    bold,
    italic,
    ref,
    callout,
    list_ordored,
    list_unordored,
    tag,

    pub inline fn isDelimiter(self: @This()) bool {
        return switch (self) {
            .weak_delimiter, .strong_delimiter => true,
            else => false,
        };
    }

    pub inline fn isPar(self: @This()) bool {
        return switch (self) {
            .literal, .link, .code, .math, .bold, .italic, .ref => true,
            else => false,
        };
    }

    pub inline fn requiresSpace(self: @This()) bool {
        return switch (self) {
            .title, .list_ordored, .list_unordored => true,
            else => false,
        };
    }
};

kind: Kind,
content: []const u8,

pub fn equals(self: @This(), kind: Kind, v: []const u8) bool {
    if (self.kind != kind) return false;
    return std.mem.eql(u8, self.content, v);
}
