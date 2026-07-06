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
    while (args.next()) |path| {
        var res: []const u8 = undefined;
        var doc = try parseDoc(init.io, alloc, Io.Dir.cwd(), path);
        if (eql(u8, cmd, "html")) {
            res = try doc.root.renderHTML(alloc);
        } else if (eql(u8, cmd, "text")) {
            res = try doc.root.renderText(alloc);
        } else {
            try help(init.io);
            std.process.exit(1);
        }
        const stdout = Io.File.stdout();

        _ = try stdout.writeStreamingAll(init.io, res);
        _ = try stdout.writeStreamingAll(init.io, "\n");
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

fn parseDoc(io: Io, alloc: Allocator, cwd: Io.Dir, path: []const u8) !typdown.Document {
    const content = try cwd.readFileAlloc(io, path, alloc, .unlimited);

    const doc = try typdown.parse(alloc, content);
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
    return doc;
}
