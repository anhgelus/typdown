const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("typdown", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "typdown",
        .linkage = .dynamic,
        .root_module = mod,
    });
    b.installArtifact(lib);

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .link_libc = true,
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addCSourceFile(.{
        .file = b.path("examples/main.c"),
    });
    example.root_module.linkLibrary(lib);
    // manually writing headers because lib.getEmittedH() doesn't work.
    example.root_module.addIncludePath(b.path("include"));

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    const examples_step = b.step("examples", "Run examples");
    const example_run = b.addRunArtifact(example);
    examples_step.dependOn(&example_run.step);
}
