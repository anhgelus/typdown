const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");
const Node = Element.Node;

pub const Code = struct {
    content: std.ArrayList(Element),
    attribute: ?[]const u8 = null,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = try .initCapacity(alloc, 2) };
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
        var el = try HTML.Content.init(alloc, "pre");
        if (self.attribute) |attr| try el.base.setAttribute("data-code", attr);
        var code = try HTML.Content.init(alloc, "code");
        var root = try HTML.Root.init(alloc);
        for (self.content.items) |it| try root.append(it);
        code.content = root.element();
        el.content = code.element();
        return el.element();
    }
};

pub const Figure = struct {
    content: Element,
    caption: ?Element = null,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = content };
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

    fn html(self: *Self, parent: Allocator) HTML.Error!HTML {
        var el = try HTML.Content.init(parent, "figure");
        var root = try HTML.Root.init(parent);
        const alloc = root.allocator();
        try root.append(self.content);
        el.content = root.element();
        const caption = self.caption orelse return el.element();
        var figcap = try HTML.Content.init(alloc, "figcaption");
        figcap.content = try caption.html(alloc);
        try root.append(figcap.element());
        return el.element();
    }
};

pub const Callout = struct {
    content: Element,
    title: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = content };
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
        var el = try HTML.Content.init(alloc, "div");
        try el.base.appendClass("callout");
        const kind = self.kind orelse "default";
        try el.base.setAttribute("data-callout", kind);
        const root = try HTML.Root.init(alloc);
        const title = try HTML.Content.init(alloc, "h4");
        title.content = (try HTML.Literal.init(alloc, self.title orelse kind)).element();
        try root.append(title.element());
        try root.append(self.content);
        el.content = root.element();
        return el.element();
    }
};

pub const Quote = struct {
    content: Element,
    node: Node = .{
        .ptr = undefined,
        .vtable = .{ .element = fromNode },
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = content };
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
        const quote = try HTML.Content.init(alloc, "blockquote");
        quote.content = try self.content.html(alloc);
        return quote.element();
    }
};
