const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");

pub const Code = struct {
    content: std.ArrayList(Element),
    attribute: ?[]const u8 = null,

    const Self = @This();

    pub fn init(alloc: Allocator) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = try .initCapacity(alloc, 2) };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .ptr = self, .vtable = .{ .html = Self.html } };
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try HTML.Content.init(alloc, "pre");
        if (self.attribute) |attr| try el.base.setAttribute("data-code", attr);
        var code = try HTML.Content.init(alloc, "code");
        for (self.content.items) |it| try code.append(try it.html(alloc));
        try el.append(code.element());
        return el.element();
    }
};

pub const Figure = struct {
    content: Element,
    caption: ?Element = null,

    const Self = @This();

    pub fn init(alloc: Allocator, content: Element) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = content };
        return v;
    }

    pub fn element(self: *Self) Element {
        return .{ .ptr = self, .vtable = .{ .html = Self.html } };
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try HTML.Content.init(alloc, "figure");
        try el.append(try self.content.html(alloc));
        const caption = self.caption orelse return el.element();
        var figcap = try HTML.Content.init(alloc, "figcaption");
        try figcap.append(try caption.html(alloc));
        try el.append(figcap.element());
        return el.element();
    }
};
