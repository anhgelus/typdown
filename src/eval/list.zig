const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");

fn List(comptime tag: []const u8) type {
    return struct {
        content: std.ArrayList(Element),

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.* = .{
                .content = try .initCapacity(alloc, 2),
            };
            return v;
        }

        pub fn element(self: *Self) Element {
            return .{ .ptr = self, .vtable = .{ .html = html } };
        }

       fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
            const self: *Self = @ptrCast(@alignCast(context));
            var el = try HTML.Content.init(alloc, tag);
            for (self.content.items) |it| {
                var li = try HTML.Content.init(alloc, "li");
                try li.append(try it.html(alloc));
                try el.append(li.element());
            }
            return el.element();
        }
    };
}

pub const Ordored = List("ol");
pub const Unordored = List("ul");
