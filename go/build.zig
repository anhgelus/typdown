const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_step = b.getInstallStep();

    const typdown = b.dependency("typdown", .{
        .optimize = optimize,
        .target = target,
    }).module("typdown");
    const lib = b.addLibrary(.{
        .name = "typdown",
        .root_module = typdown,
    });
    //lib.bundle_compiler_rt = true;
    //lib.pie = true;
    const install_lib = b.addInstallArtifact(lib, .{});

    var flags = try std.ArrayList(u8).initCapacity(b.allocator, 2);
    try flags.appendSlice(b.allocator, "-linkmode external -extldflags -static");
    if (optimize != .Debug) try flags.appendSlice(b.allocator, " -s");
    const go_build = b.addSystemCommand(&[_][]const u8{
        "go",       "build",
        "-ldflags", flags.items,
        ".",
    });
    go_build.step.dependOn(&install_lib.step);
    install_step.dependOn(&go_build.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(b.getInstallStep());
    const race = b.option(bool, "race", "Run tests with -race") orelse false;
    const go_test = b.addSystemCommand(&[_][]const u8{
        "go",       "test",
        "-ldflags", flags.items,
        "-v",
    });
    if (race) go_test.addArg("-race");
    go_test.addArg("./...");

    test_step.dependOn(install_step);
}
