const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Element = @import("Element.zig");
const Node = Element.Node;
const Error = Element.Error;

content: std.DoublyLinkedList = .{},
arena: Arena,
node: Node = .{
    .ptr = undefined,
    .vtable = .{ .element = fromNode },
},

const Self = @This();

pub fn init(parent: Allocator) Error!*Self {
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

pub fn element(self: *Self) Element {
    return (Element.Wrapper(Self){ .ptr = self }).element();
}

pub fn allocator(self: *Self) Allocator {
    return self.arena.allocator();
}

pub fn append(self: *Self, raw: anytype) Error!void {
    const el: Element = blk: {
        const T = @TypeOf(raw);
        if (T == Element) break :blk raw;
        if (@hasDecl(T, "html")) break :blk try raw.html(self.allocator());
        @compileError("cannot convert " ++ @typeName(T) ++ " into " ++ @typeName(Element));
    };
    self.content.append(&el.node().node);
}

fn fromNode(context: *anyopaque) Element {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.element();
}

pub fn render(self: *Self, alloc: Allocator) Error![]const u8 {
    if (self.content.first == null) return "";
    var acc = try std.ArrayList(u8).initCapacity(alloc, 8);
    errdefer acc.deinit(alloc);

    var arena = Arena.init(alloc);
    defer arena.deinit();
    var v = self.content.first;
    while (v) |it| : (v = it.next) try acc.appendSlice(alloc, try Node.from(it).render(arena.allocator()));
    return acc.toOwnedSlice(alloc);
}
