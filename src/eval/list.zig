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
            return .{ .ptr = self, .vtable = .{ .deinit = destroy, .html = html } };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            destroy(self, alloc);
        }

        fn destroy(context: *anyopaque, alloc: Allocator) void {
            var self: *Self = @ptrCast(@alignCast(context));
            for (self.content.items) |it| it.deinit(alloc);
            self.content.deinit(alloc);
            alloc.destroy(self);
        }

        fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
            const self: *Self = @ptrCast(@alignCast(context));
            var el = try HTML.init(alloc, .content, tag);
            errdefer el.deinit();
            for (self.content.items) |it| {
                var li = try HTML.init(alloc, .content, "li");
                try li.appendContent(try it.html(alloc));
                try el.appendContent(li);
            }
            return el;
        }
    };
}

pub const Ordored = List("ol");
pub const Unordored = List("ul");
