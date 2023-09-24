const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-conway",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const sdl2_include_path = std.Build.LazyPath{ .path = ".\\deps\\sdl2\\include" };
    const sdl2_library_path = std.Build.LazyPath{ .path = ".\\deps\\sdl2\\lib\\x64" };
    exe.addIncludePath(sdl2_include_path);
    exe.addLibraryPath(sdl2_library_path);
    b.installBinFile(".\\deps\\sdl2\\" ++ "lib\\x64\\SDL2.dll", "SDL2.dll");
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const grid_unit_tests = b.addTest(.{ .root_source_file = .{ .path = "src/grid.zig" }, .target = target, .optimize = optimize });

    // Add grid units tests to zig-out/bin
    b.installArtifact(grid_unit_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_grid_unit_tests = b.addRunArtifact(grid_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_grid_unit_tests.step);
}
