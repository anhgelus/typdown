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
        return Element.Wrapper(Self, html, text).init(self);
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

    fn text(self: *Self, alloc: Allocator) Allocator.Error![]u8 {
        var content = try std.ArrayList(u8).initCapacity(alloc, self.content.items.len);
        for (self.content.items) |it| {
            const c = try it.renderText(alloc);
            defer alloc.free(c);
            try content.appendSlice(alloc, c);
        }
        return try content.toOwnedSlice(alloc);
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
        return Element.Wrapper(Self, html, text).init(self);
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

    fn text(self: *Self, alloc: Allocator) Allocator.Error![]u8 {
        var base = try self.content.renderText(alloc);
        const n = base.len;
        if (self.caption) |it| {
            const caption = try it.renderText(alloc);
            defer alloc.free(caption);
            base = try alloc.realloc(base, n + 3 + caption.len);
            base[n] = '\n';
            for (caption, n + 1..) |v, i| base[i] = v;
        }
        return base;
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
        return Element.Wrapper(Self, html, text).init(self);
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

    fn text(self: *Self, alloc: Allocator) Allocator.Error![]u8 {
        var content = std.ArrayList(u8).empty;
        if (self.title) |it| try content.appendSlice(alloc, it);
        try content.append(alloc, '\n');
        const c = try self.content.renderText(alloc);
        defer alloc.free(c);
        try content.appendSlice(alloc, c);
        return try content.toOwnedSlice(alloc);
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
        return Element.Wrapper(Self, html, text).init(self);
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

    fn text(self: *Self, alloc: Allocator) Allocator.Error![]u8 {
        return try self.content.renderText(alloc);
    }
};
