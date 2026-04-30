const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = Element.HTML;
const Element = @import("Element.zig");
const Node = Element.Node;

fn List(comptime tag: []const u8) type {
    return struct {
        content: std.ArrayList(Element),
        node: Node = .{
            .ptr = undefined,
            .vtable = .{ .element = fromNode },
        },

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.* = .{
                .content = try .initCapacity(alloc, 2),
            };
            v.node.ptr = v;
            return v;
        }

        pub fn element(self: *Self) Element {
            return Element.Wrapper(Self, html).init(self);
        }

        fn fromNode(context: *anyopaque) Element {
            const self: *Self = @ptrCast(@alignCast(context));
            return self.element();
        }

        fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
            var el = try HTML.Content.init(alloc, tag);
            var root = try HTML.Root.init(alloc);
            el.content = root.element();
            for (self.content.items) |it| {
                var li = try HTML.Content.init(root.allocator(), "li");
                li.content = try it.html(root.allocator());
                try root.append(li.element());
            }
            return el.element();
        }
    };
}

pub const Ordored = List("ol");
pub const Unordored = List("ul");
