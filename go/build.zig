const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const typdown = b.dependency("typdown", .{
        .optimize = optimize,
        .target = target,
    }).module("typdown");
    const lib = b.addLibrary(.{
        .name = "typdown",
        .root_module = typdown,
        .linkage = .static,
    });
    const install = b.addInstallArtifact(lib, .{});
    // when emitting headers will be fixed
    // currently, we have to use a symlink/copy to get it
    //installed.emitted_h = lib.getEmittedH();
    b.getInstallStep().dependOn(&install.step);

    var flags = try std.ArrayList(u8).initCapacity(b.allocator, 2);
    try flags.appendSlice(b.allocator, "-linkmode external -extldflags -static");
    if (optimize != .Debug) try flags.appendSlice(b.allocator, " -s");
    const go_build = b.addSystemCommand(&[_][]const u8{
        "go", "build",
        "-ldflags", try flags.toOwnedSlice(b.allocator),
        ".",
    });
    b.getInstallStep().dependOn(&go_build.step);
}
