const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const short = b.option(bool, "short", "skip long tests") orelse false;
    const no_embed_fonts = b.option(bool, "no-embed-fonts", "dont embed fonts for typst (enabled for ReleaseSmall)") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "short", short);

    const typst_dep = b.dependency("typst", .{});

    // build typst module
    const build_typst = b.addSystemCommand(&[_][]const u8{
        "cargo", "build",
    });
    build_typst.setCwd(typst_dep.path(""));
    if (!no_embed_fonts or optimize == .ReleaseSmall) build_typst.addArgs(&.{ "--features", "embed-fonts" });
    var folder: []const u8 = "debug";
    switch (optimize) {
        .ReleaseSmall => {
            build_typst.addArgs(&.{ "--profile", "small" });
            folder = "small";
        },
        .ReleaseFast, .ReleaseSafe => {
            build_typst.addArg("--release");
            folder = "release";
        },
        else => {},
    }

    const typst = b.addTranslateC(.{
        .root_source_file = typst_dep.path("include/typdown_typst.h"),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("typdown", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = !target.result.isWasiLibC(),
        .strip = optimize != .Debug,
    });
    mod.addOptions("config", options);
    // add typst module
    mod.addObjectFile(typst_dep.path("target").path(b, folder).path(b, "libtypdown_typst.so"));
    mod.addImport("typst", typst.createModule());

    const lib = b.addLibrary(.{
        .name = "typdown",
        .linkage = .dynamic,
        .root_module = mod,
        .use_llvm = true, // zig internal backend crashes during linking (for 0.16.0)
    });
    lib.step.dependOn(&build_typst.step);

    b.installArtifact(lib);

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
        },
    });
    lib.step.dependOn(&fmt.step);

    const exe = b.addExecutable(.{
        .name = "typdown",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cli/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true, // zig internal backend crashes during linking (for 0.16.0)
    });
    exe.root_module.addImport("typdown", mod);
    exe.step.dependOn(&lib.step);

    b.installArtifact(exe);

    const test_step = b.step("test", "Run tests");
    const exe_tests = b.addTest(.{
        .root_module = mod,
        .use_llvm = true, // zig internal backend crashes during linking (for 0.16.0)
    });

    generateSVG(b, &exe_tests.step) catch |err| exe_tests.step.addError("{}\n", .{err}) catch unreachable;
    const run_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Run examples");
    const example_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addCSourceFile(.{
        .file = b.path("examples/main.c"),
    });
    example_mod.linkLibrary(lib);
    example_mod.addIncludePath(b.path("include"));

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = example_mod,
    });
    example.step.dependOn(&lib.step);

    const example_run = b.addRunArtifact(example);
    examples_step.dependOn(&example_run.step);

    const check = b.step("check", "Check if it compiles");
    check.dependOn(&lib.step);
    check.dependOn(&exe.step);

    const exe_run = b.step("run", "Run the CLI");
    const run_cmd = b.addRunArtifact(exe);
    exe_run.dependOn(&run_cmd.step);
    if (b.args) |args| run_cmd.addArgs(args);
}

fn generateSVG(b: *std.Build, step: *std.Build.Step) !void {
    var thread = std.Io.Threaded.init(b.allocator, .{});
    defer thread.deinit();
    const io = thread.io();
    var dir = try b.build_root.handle.openDir(io, "src/data", .{ .iterate = true });
    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |it| {
        if (it.kind == .file and std.mem.endsWith(u8, it.name, ".typ") and !std.mem.startsWith(u8, it.name, "_")) {
            const cmd = b.addSystemCommand(&[_][]const u8{
                "typst", "c",
                "-f",    "svg",
                it.name,
            });
            cmd.setCwd(b.path("src/data/"));
            step.dependOn(&cmd.step);
        }
    }
}
