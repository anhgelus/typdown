const std = @import("std");
const builtin = @import("builtin");

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

    const go_build = buildGo(b, target, optimize, "build");
    b.getInstallStep().dependOn(&go_build.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(b.getInstallStep());
    const race = b.option(bool, "race", "Run tests with -race") orelse false;
    const go_test = buildGo(b, target, optimize, "test");
    if (race) go_test.addArg("-race");
    go_test.addArg("./...");

    test_step.dependOn(&go_test.step);
}

fn buildGo(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, command: []const u8) *std.Build.Step.Run {
    var flags = std.ArrayList(u8).initCapacity(b.allocator, 2) catch unreachable;
    flags.appendSlice(b.allocator, "-linkmode external -extldflags -static") catch unreachable;
    if (optimize != .Debug) flags.appendSlice(b.allocator, " -s") catch unreachable;
    //const targetStr = std.fmt.allocPrint(b.allocator, "{s}-{s}-{s}", .{
    //    @tagName(target.result.cpu.arch),
    //    @tagName(target.result.os.tag),
    //    @tagName(target.result.abi),
    //}) catch unreachable;
    //const cc = std.fmt.allocPrint(b.allocator, "zig cc -target {s}", .{targetStr}) catch unreachable;
    //const cpp = std.fmt.allocPrint(b.allocator, "zig c++ -target {s}", .{targetStr}) catch unreachable;
    const run = b.addSystemCommand(&[_][]const u8{
        "go",       command,
        "-ldflags", flags.items,
        ".",
    });
    run.setEnvironmentVariable("CC", "zig cc");
    run.setEnvironmentVariable("C++", "zig c++");
    run.setEnvironmentVariable("CGO_ENABLED", "1");
    run.setEnvironmentVariable("GOOS", @tagName(target.result.os.tag));
    return run;
}
