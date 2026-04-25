const std = @import("std");
const Allocator = std.mem.Allocator;
const DOMElement = @import("dom/Element.zig");

const Parent = @This();

vtable: struct {
    deinit: *const fn (*anyopaque, Allocator) void,
    dom: *const fn (*anyopaque, Allocator) DOMElement.Error!DOMElement,
},
ptr: *anyopaque,

pub fn renderHTML(self: Parent, alloc: Allocator) DOMElement.Error![]const u8 {
    var el = try self.vtable.dom(self.ptr, alloc);
    defer el.deinit();
    return el.render(alloc);
}

pub fn deinit(self: Parent, alloc: Allocator) void {
    self.vtable.deinit(self.ptr, alloc);
}

fn dom(self: Parent, alloc: Allocator) DOMElement.Error!DOMElement {
    return self.vtable.dom(self.ptr, alloc);
}

pub const Paragraph = Modifier("p");
pub const Bold = Modifier("b");
pub const Italic = Modifier("em");
pub const Code = Modifier("code");

pub const Empty = struct {
    content: std.ArrayList(Parent),

    const Self = @This();

    pub fn init(alloc: Allocator) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .content = try .initCapacity(alloc, 2) };
        return v;
    }

    pub fn element(self: *Self) Parent {
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .dom = Self.dom } };
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

    fn dom(context: *anyopaque, alloc: Allocator) DOMElement.Error!DOMElement {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = DOMElement.initEmpty(alloc);
        errdefer el.deinit();
        for (self.content.items) |it| try el.appendContent(try it.dom(alloc));
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

    pub fn element(self: *Self) Parent {
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .dom = Self.dom } };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        destroy(self, alloc);
    }

    fn destroy(context: *anyopaque, alloc: Allocator) void {
        const self: *Self = @ptrCast(@alignCast(context));
        alloc.destroy(self);
    }

    fn dom(context: *anyopaque, alloc: Allocator) DOMElement.Error!DOMElement {
        const self: *Self = @ptrCast(@alignCast(context));
        return DOMElement.initLitEscaped(alloc, self.content);
    }
};

pub fn Modifier(comptime tag: []const u8) type {
    return struct {
        content: std.ArrayList(Parent),

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const v = try alloc.create(Self);
            v.* = .{ .content = try .initCapacity(alloc, 2) };
            return v;
        }

        pub fn element(self: *Self) Parent {
            return .{ .ptr = self, .vtable = .{ .deinit = destroy, .dom = Self.dom } };
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

        fn dom(context: *anyopaque, alloc: Allocator) DOMElement.Error!DOMElement {
            const self: *Self = @ptrCast(@alignCast(context));
            var el = try DOMElement.init(alloc, .content, tag);
            errdefer el.deinit();
            for (self.content.items) |it| try el.appendContent(try it.dom(alloc));
            return el;
        }
    };
}

pub const Link = struct {
    link: []const u8,
    content: Parent,
    target: ?[]const u8 = null,

    const Self = @This();

    pub fn init(alloc: Allocator, content: Parent, link: []const u8) !*Self {
        const v = try alloc.create(Self);
        v.* = .{
            .content = content,
            .link = link,
        };
        return v;
    }

    pub fn element(self: *Self) Parent {
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .dom = Self.dom } };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        destroy(self, alloc);
    }

    fn destroy(context: *anyopaque, alloc: Allocator) void {
        var self: *Self = @ptrCast(@alignCast(context));
        self.content.deinit(alloc);
        alloc.destroy(self);
    }

    fn dom(context: *anyopaque, alloc: Allocator) DOMElement.Error!DOMElement {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try DOMElement.init(alloc, .content, "a");
        errdefer el.deinit();
        try el.appendContent(try self.content.dom(alloc));
        try el.setAttribute("href", self.link);
        if (self.target) |target| try el.setAttribute("target", target);
        return el;
    }
};

pub const Title = struct {
    level: u3,
    content: Parent,

    const Self = @This();

    pub fn init(alloc: Allocator, level: u3, content: Parent) !*Self {
        const v = try alloc.create(Self);
        v.* = .{ .level = level, .content = content };
        return v;
    }

    pub fn element(self: *Self) Parent {
        return .{ .ptr = self, .vtable = .{ .deinit = destroy, .dom = Self.dom } };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        self.element().deinit(alloc);
    }

    fn destroy(context: *anyopaque, alloc: Allocator) void {
        var self: *Self = @ptrCast(@alignCast(context));
        self.content.deinit(alloc);
        alloc.destroy(self);
    }

    fn dom(context: *anyopaque, alloc: Allocator) DOMElement.Error!DOMElement {
        const self: *Self = @ptrCast(@alignCast(context));
        var el = try DOMElement.init(alloc, .content, switch (self.level) {
            1 => "h1",
            2 => "h2",
            3 => "h3",
            4 => "h4",
            5 => "h5",
            6 => "h6",
            else => unreachable,
        });
        errdefer el.deinit();
        try el.appendContent(try self.content.dom(alloc));
        return el;
    }
};

fn doTest(alloc: Allocator, el: Parent, exp: []const u8) !void {
    const got = try el.renderHTML(alloc);
    defer alloc.free(got);
    std.testing.expect(std.mem.eql(u8, got, exp)) catch |err| {
        std.debug.print("{s}\n", .{got});
        return err;
    };
}

test "paragraph" {
    const alloc = std.testing.allocator;

    const lit = (try Literal.init(alloc, "hello world")).element();
    try doTest(alloc, lit, "hello world");

    var p = try Paragraph.init(alloc);
    try p.content.append(alloc, lit);
    defer p.deinit(alloc);
    try doTest(alloc, p.element(), "<p>hello world</p>");

    const link = (try Link.init(alloc, (try Literal.init(alloc, "foo")).element(), "example.org")).element();
    try doTest(alloc, link, "<a href=\"example.org\">foo</a>");

    try p.content.append(alloc, link);
    try doTest(alloc, p.element(), "<p>hello world<a href=\"example.org\">foo</a></p>");
}
