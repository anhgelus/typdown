const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_step = b.getInstallStep();

    const typdown = b.dependency("typdown", .{
        .optimize = optimize,
        .target = target,
    });
    const lib = @import("typdown").buildLib(
        typdown.builder,
        target,
        optimize,
        true,
        false,
    );
    lib.bundle_compiler_rt = true;
    lib.pie = true;

    const lib_install = b.addInstallArtifact(lib, .{});
    lib_install.step.dependOn(&lib.step);

    const go_build = buildGo(b, target, optimize, "build");
    go_build.step.dependOn(&lib_install.step);
    install_step.dependOn(&go_build.step);

    const test_step = b.step("test", "Run tests");
    const race = b.option(bool, "race", "Run tests with -race") orelse false;
    const go_test = buildGo(b, target, optimize, "test");
    if (race) go_test.addArg("-race");
    go_test.addArg("./...");
    go_test.step.dependOn(&lib_install.step);
    test_step.dependOn(&go_test.step);
}

fn buildGo(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, comptime command: []const u8) *std.Build.Step.Run {
    var flags = std.ArrayList(u8).initCapacity(b.allocator, 2) catch unreachable;
    flags.appendSlice(b.allocator, "-linkmode external -e") catch unreachable;
    if (optimize != .Debug) flags.appendSlice(b.allocator, "-w -s") catch unreachable;
    const cc_ldflags = std.fmt.allocPrint(
        b.allocator,
        "{s}/libtypdown.a",
        .{b.lib_dir},
    ) catch unreachable;
    const run = b.addSystemCommand(&[_][]const u8{
        "go",       command,
        "-ldflags", flags.items,
        ".",
    });
    run.setName("building go");
    run.setEnvironmentVariable("CGO_ENABLED", "1");
    run.setEnvironmentVariable("CGO_LDFLAGS", cc_ldflags);
    run.setEnvironmentVariable("GOOS", @tagName(target.result.os.tag));
    return run;
}
