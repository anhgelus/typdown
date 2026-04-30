const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const HTML = @import("html/Element.zig");
const Element = @import("Element.zig");
const Node = Element.Node;

const Self = @This();

content: std.DoublyLinkedList = .{},
arena: Arena,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

pub fn init(parent: Allocator) !*Self {
    var s = Self{ .arena = .init(parent) };
    var alloc = s.arena.allocator();
    const v = try alloc.create(Self);
    v.* = s;
    v.node.ptr = v;
    return v;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn allocator(self: *Self) Allocator {
    return self.arena.allocator();
}

pub fn append(self: *Self, raw: anytype) void {
    const el: Element = blk: {
        const T = @TypeOf(raw);
        if (T == Element) break :blk raw;
        if (std.meta.hasMethod(T, "element")) break :blk raw.element();
        @compileError("cannot convert " ++ @typeName(T) ++ " into " ++ @typeName(Element));
    };
    self.content.append(&el.node().node);
}

pub fn element(self: *Self) Element {
    return Element.Wrapper(Self, html).init(self);
}

pub fn renderHTML(self: *Self, alloc: Allocator) HTML.Error![]const u8 {
    return try self.element().renderHTML(alloc);
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

fn html(self: *Self, alloc: Allocator) HTML.Error!HTML {
    const el = try HTML.Root.init(alloc);
    var v = self.content.first;
    while (v) |it| : (v = it.next) try el.append(Node.from(it).element());
    return el.element();
}
