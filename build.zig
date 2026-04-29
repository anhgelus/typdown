const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // build typst module
    const build_typst = b.addSystemCommand(&[_][]const u8{
        "cargo", "build",
    });
    build_typst.setCwd(b.path("typst/"));
    if (optimize != .Debug) build_typst.addArg("--release");
    b.getInstallStep().dependOn(&build_typst.step);

    const mod = b.addModule("typdown", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (!target.result.isWasiLibC()) mod.link_libc = true;
    // link typst module during build
    mod.addIncludePath(b.path("typst"));
    mod.addLibraryPath(
        if (optimize == .Debug) b.path("typst/target/debug/")
        else b.path("typst/target/release/")
    );
    if (optimize != .Debug) mod.strip = true;

    const lib = b.addLibrary(.{
        .name = "typdown",
        .linkage = .static,
        .root_module = mod,
    });
    // link typst module to build 
    lib.linkSystemLibrary("typdown_typst");

    const installed_lib = b.addInstallArtifact(lib, .{});
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

    b.getInstallStep().dependOn(&installed_lib.step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
        .use_llvm = true, // zig internal backend crashes during linking (for 0.15.2)
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&run_mod_tests.step);

    const examples_step = b.step("examples", "Run examples");
    examples_step.dependOn(b.getInstallStep());
    const example_run = b.addRunArtifact(example);
    examples_step.dependOn(&example_run.step);

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&lib.step);
}
