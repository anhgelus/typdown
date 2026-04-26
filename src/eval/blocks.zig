const std = @import("std");
const Allocator = std.mem.Allocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");

pub const Code = Element.Simple("pre");

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
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .html = Self.html } };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        destroy(self, alloc);
    }

    fn destroy(context: *anyopaque, alloc: Allocator) void {
        const self: *Self = @ptrCast(@alignCast(context));
        self.content.deinit(alloc);
        if (self.caption) |cap| cap.deinit(alloc);
        alloc.destroy(self);
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try HTML.init(alloc, .content, "figure");
        errdefer el.deinit();
        try el.appendContent(try self.content.html(alloc));
        const caption = self.caption orelse return el;
        var figcap = try HTML.init(alloc, .content, "figcaption");
        errdefer figcap.deinit();
        try figcap.appendContent(try caption.html(alloc));
        try el.appendContent(figcap);
        return el;
    }
};
