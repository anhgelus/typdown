const std = @import("std");
const Allocator = std.mem.Allocator;
pub const HTML = @import("html/Element.zig");
pub const paragraph = @import("paragraph.zig");
pub const Title = @import("Title.zig");
pub const list = @import("list.zig");
pub const Image = @import("Image.zig");
pub const Root = @import("Root.zig");
const blocks = @import("blocks.zig");
pub const Code = blocks.Code;
pub const Figure = blocks.Figure;
pub const Callout = blocks.Callout;
pub const Quote = blocks.Quote;
pub const Math = @import("math.zig");

pub fn Wrapper(comptime V: type, comptime h: *const fn (*V, Allocator) HTML.Error!HTML) type {
    comptime {
        if (!@hasField(V, "node")) @compileError("missing field 'node' for " ++ @typeName(V));
        const nd = @FieldType(V, "node");
        if (nd != Node) @compileError("invalid node's type: " ++ @typeName(nd) ++ ", want " ++ @typeName(Node));
        if (!std.meta.hasMethod(V, "element")) @compileError("missing declaration 'element' for " ++ @typeName(V));
    }
    return struct {
        ptr: *V,

        const Self = @This();

        fn node(context: *anyopaque) *Node {
            const self: *V = @ptrCast(@alignCast(context));
            return &self.node;
        }

        fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
            const self: *V = @ptrCast(@alignCast(context));
            return try h(self, alloc);
        }

        pub fn init(ptr: *V) Element {
            return (Self{ .ptr = ptr }).element();
        }

        pub fn element(self: Self) Element {
            return .{ .ptr = self.ptr, .vtable = .{ .node = Self.node, .html = Self.html } };
        }
    };
}

pub const Node = struct {
    ptr: *anyopaque,
    vtable: struct { element: *const fn (*anyopaque) Element },
    node: std.DoublyLinkedList.Node = .{},

    pub fn from(n: *std.DoublyLinkedList.Node) *Node {
        const v: *Node = @fieldParentPtr("node", n);
        return v;
    }

    pub fn element(self: Node) Element {
        return self.vtable.element(self.ptr);
    }
};

const Element = @This();

vtable: struct {
    html: *const fn (*anyopaque, Allocator) HTML.Error!HTML,
    node: *const fn (*anyopaque) *Node,
},
ptr: *anyopaque,

pub fn renderHTML(self: Element, alloc: Allocator) HTML.Error![]const u8 {
    const root = try HTML.Root.init(alloc);
    defer root.deinit();
    var el = try self.vtable.html(self.ptr, root.allocator());
    return el.render(alloc);
}

pub fn html(self: Element, alloc: Allocator) HTML.Error!HTML {
    return self.vtable.html(self.ptr, alloc);
}

pub fn node(self: Element) *Node {
    return self.vtable.node(self.ptr);
}

pub const Literal = struct {
    content: []const u8,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: []const u8) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = content };
        v.node.ptr = v;
        return v;
    }

    pub fn element(self: *Self) Element {
        return Wrapper(Self, Self.html).init(self);
    }

    fn fromNode(context: *anyopaque) Element {
        const self: *Self = @ptrCast(@alignCast(context));
        return self.element();
    }

    fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
        return (try HTML.Literal.init(alloc, self.content)).element();
    }
};

pub fn Simple(comptime tag: []const u8) type {
    return struct {
        content: ?Element = null,
        node: Node,

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.node = .{ .ptr = v, .vtable = .{ .element = fromNode } };
            return v;
        }

        pub fn element(self: *Self) Element {
            return Wrapper(Self, Self.html).init(self);
        }

        pub fn toTag(self: *Self, alloc: Allocator, comptime target: []const u8) !*Simple(target) {
            defer alloc.destroy(self);
            const el = try Simple(target).init(alloc);
            el.content = self.content;
            return el;
        }

        pub fn toRoot(self: *Self, alloc: Allocator) !*Root {
            defer alloc.destroy(self);
            const el = try Root.init(alloc);
            if (self.content) |it| el.append(it);
            return el;
        }

        fn fromNode(context: *anyopaque) Element {
            const self: *Self = @ptrCast(@alignCast(context));
            return self.element();
        }

        fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
            var el = try HTML.Content.init(alloc, tag);
            if (self.content) |it| el.content = try it.html(alloc);
            return el.element();
        }
    };
}
