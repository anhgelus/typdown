const std = @import("std");
const builtin = @import("builtin");
const typdown = @import("typdown");
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const alloc = comptime if (builtin.target.isWasiLibC())
        std.heap.wasm_allocator
    else if (builtin.is_test)
        std.testing.allocator
    else
        std.heap.smp_allocator;
    var args = std.process.args();
    // skip command name
    _ = args.next();
    const cmd = args.next() orelse {
        try help();
        return;
    };
    if (eql(u8, cmd, "html")) {
        try html(alloc, &args);
    } else {
        try help();
        std.process.exit(1);
    }
}

fn help() !void {
    var buffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer).interface;
    try stdout.print("typdown CLI\n\n", .{});
    try stdout.print("Commands:\n", .{});
    try stdout.print("  html path... - Generate the html from these files and print to stdout\n", .{});
    try stdout.print("  help         - Print the help\n", .{});
    try stdout.flush();
}

fn html(parent: Allocator, args: *std.process.ArgIterator) !void {
    const cwd = std.fs.cwd();
    while (args.next()) |path| {
        var arena = std.heap.ArenaAllocator.init(parent);
        defer arena.deinit();
        const alloc = arena.allocator();

        const content = try cwd.readFileAlloc(alloc, path, 1024 * 1024 * 1024);

        var doc = try typdown.parse(alloc, content);
        if (doc.errors) |errors| {
            var buffer: [1024]u8 = undefined;
            var stdout = std.fs.File.stdout().writer(&buffer).interface;
            try stdout.print("Errors:\n\n", .{});
            for (errors) |err| {
                try stdout.print("{} (line {}): {s}\n\n", .{err.err, err.location.line, err.extract(content)});
                try stdout.flush();
            }
            std.process.exit(2);
        }
        const res = try doc.root.renderHTML(alloc);

        _ = try std.fs.File.stdout().write(res);
    }
}
