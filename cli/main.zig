const std = @import("std");
const builtin = @import("builtin");
const typdown = @import("typdown");
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    var args = init.minimal.args.iterate();
    // skip command name
    _ = args.next();
    const cmd = args.next() orelse {
        try help(init.io);
        return;
    };
    if (eql(u8, cmd, "html")) {
        try html(init.io, alloc, &args);
    } else {
        try help(init.io);
        std.process.exit(1);
    }
}

fn help(io: Io) !void {
    var buffer: [1024]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &buffer).interface;
    try stdout.print("typdown CLI\n\n", .{});
    try stdout.print("Commands:\n", .{});
    try stdout.print("  html path... - Generate the html from these files and print to stdout\n", .{});
    try stdout.print("  help         - Print the help\n", .{});
    try stdout.flush();
}

fn html(io: Io, parent: Allocator, args: *std.process.Args.Iterator) !void {
    const cwd = Io.Dir.cwd();
    while (args.next()) |path| {
        var arena = std.heap.ArenaAllocator.init(parent);
        defer arena.deinit();
        const alloc = arena.allocator();

        const content = try cwd.readFileAlloc(io, path, alloc, .unlimited);

        var doc = try typdown.parse(alloc, content);
        if (doc.errors) |errors| {
            var buffer: [2048]u8 = undefined;
            var stdout_writer = Io.File.stdout().writer(io, &buffer);
            const stdout = &stdout_writer.interface;
            try stdout.print("Cannot compile {s}:\n", .{path});
            for (errors) |err| {
                const extracted = std.mem.trimEnd(u8, err.extract(content), "\n");
                try stdout.print("\n{s} (line {})\n", .{ extracted, err.location.line });
                try stdout.printAsciiChar('^', .{});
                if (extracted.len > 1) {
                    for (1..extracted.len - 1) |_| try stdout.printAsciiChar('~', .{});
                    try stdout.printAsciiChar('^', .{});
                }
                try stdout.print("\n{}\n\n", .{err.err});
                try stdout.flush();
            }
            std.process.exit(2);
        }
        const res = try doc.root.renderHTML(alloc);

        const stdout = Io.File.stdout();

        _ = try stdout.writeStreamingAll(io, res);
        _ = try stdout.writeStreamingAll(io, "\n");
    }
}
