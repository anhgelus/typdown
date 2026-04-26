const std = @import("std");
const Allocator = std.mem.Allocator;
pub const HTML = @import("html/Element.zig");
pub const paragraph = @import("paragraph.zig");
pub const Title = @import("Title.zig");
pub const list = @import("list.zig");
pub const Image = @import("Image.zig");
const blocks = @import("blocks.zig");
pub const Code = blocks.Code;
pub const Figure = blocks.Figure;

const Element = @This();

vtable: struct {
    deinit: *const fn (*anyopaque, Allocator) void,
    html: *const fn (*anyopaque, Allocator) HTML.Error!HTML,
},
ptr: *anyopaque,

pub fn renderHTML(self: Element, alloc: Allocator) HTML.Error![]const u8 {
    var el = try self.vtable.html(self.ptr, alloc);
    defer el.deinit();
    return el.render(alloc);
}

pub fn deinit(self: Element, alloc: Allocator) void {
    self.vtable.deinit(self.ptr, alloc);
}

pub fn html(self: Element, alloc: Allocator) HTML.Error!HTML {
    return self.vtable.html(self.ptr, alloc);
}

pub const Empty = struct {
    content: std.ArrayList(Element),

    const Self = @This();

    pub fn init(alloc: Allocator) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = try .initCapacity(alloc, 2) };
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
        for (self.content.items) |it| it.deinit(alloc);
        self.content.deinit(alloc);
        alloc.destroy(self);
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = HTML.initEmpty(alloc);
        errdefer el.deinit();
        for (self.content.items) |it| try el.appendContent(try it.html(alloc));
        return el;
    }
};

pub const Literal = struct {
    content: []const u8,

    const Self = @This();

    pub fn init(alloc: Allocator, content: []const u8) !*Self {
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
        alloc.destroy(self);
    }

    fn html(context: *anyopaque, alloc: Allocator) HTML.Error!HTML {
        const self: *Self = @ptrCast(@alignCast(context));
        return HTML.initLitEscaped(alloc, self.content);
    }
};

pub fn Simple(comptime tag: []const u8) type {
    return struct {
        content: std.ArrayList(Element),

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.* = .{ .content = try .initCapacity(alloc, 2) };
            return v;
        }

        pub fn element(self: *Self) Element {
            return .{ .ptr = self, .vtable = .{ .deinit = destroy, .html = Self.html } };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            destroy(self, alloc);
        }

        pub fn toTag(self: *Self, alloc: Allocator, comptime target: []const u8) !*Simple(target) {
            const el = try Simple(target).init(alloc);
            self.conv(alloc, &el.content);
            return el;
        }

        pub fn toEmpty(self: *Self, alloc: Allocator) !*Empty {
            const el = try Empty.init(alloc);
            self.conv(alloc, &el.content);
            return el;
        }

        fn conv(self: *Self, alloc: Allocator, arr: *std.ArrayList(Element)) void {
            arr.deinit(alloc);
            arr.* = self.content;
            alloc.destroy(self);
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
            for (self.content.items) |it| try el.appendContent(try it.html(alloc));
            return el;
        }
    };
}
