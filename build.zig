const std = @import("std");

const TYPST = "lib/typst";
const TYPST_DEBUG = TYPST ++ "/target/debug";
const TYPST_RELEASE = TYPST ++ "/target/release";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install = b.getInstallStep();

    // build typst module
    const build_typst = b.addSystemCommand(&[_][]const u8{
        "cargo", "build",
    });
    build_typst.setCwd(b.path(TYPST));
    if (optimize != .Debug) build_typst.addArg("--release");

    const mod = b.addModule("typdown", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (!target.result.isWasiLibC()) mod.link_libc = true;
    if (optimize != .Debug) mod.strip = true;
    // find typst module
    mod.addIncludePath(b.path(TYPST));
    mod.addLibraryPath(if (optimize == .Debug) b.path(TYPST_DEBUG) else b.path(TYPST_RELEASE));

    const lib = b.addLibrary(.{
        .name = "typdown",
        .linkage = .static,
        .root_module = mod,
        .use_llvm = true, // zig internal backend crashes during linking (for 0.15.2)
    });
    // link typst module
    lib.linkSystemLibrary("typdown_typst");

    const installed_lib = b.addInstallArtifact(lib, .{});
    installed_lib.step.dependOn(&build_typst.step);
    // when emitting headers will be fixed
    //installed_lib.emitted_h = lib.getEmittedH();

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    example.root_module.addCSourceFile(.{
        .file = b.path("examples/main.c"),
    });
    example.root_module.linkLibrary(lib);
    example.root_module.addIncludePath(b.path("include"));

    install.dependOn(&installed_lib.step);

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
        },
    });
    install.dependOn(&fmt.step);

    const test_step = b.step("test", "Run tests");
    const mod_tests = b.addTest(.{
        .root_module = mod,
        .use_llvm = true, // zig internal backend crashes during linking (for 0.15.2)
    });

    const options = b.addOptions();
    const short = b.option(bool, "short", "skip long tests") orelse false;
    options.addOption(bool, "short", short);
    mod_tests.root_module.addOptions("config", options);

    const run_mod_tests = b.addRunArtifact(mod_tests);
    generateSVG(b, &run_mod_tests.step) catch |err| run_mod_tests.step.addError("{}\n", .{err}) catch unreachable;
    run_mod_tests.step.dependOn(install);
    test_step.dependOn(&run_mod_tests.step);

    const examples_step = b.step("examples", "Run examples");
    const example_run = b.addRunArtifact(example);
    example_run.step.dependOn(install);
    examples_step.dependOn(&example_run.step);

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&lib.step);
}

fn generateSVG(b: *std.Build, step: *std.Build.Step) !void {
    var dir = try std.fs.cwd().openDir("src/data/", .{ .iterate = true });
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |it| {
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
