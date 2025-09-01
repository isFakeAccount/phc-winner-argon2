const std = @import("std");
const buildZon = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("libargon2", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version: std.SemanticVersion = try std.SemanticVersion.parse(buildZon.version);

    // Custom Options
    const no_threads = b.option(bool, "NO_THREADS", "Build without threading enabled.") orelse false;
    const cpu_opt = b.option(bool, "ENABLE_CPU_OPT", "Build with CPU optimizations enabled.") orelse false;

    var argon2Module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    argon2Module.addCSourceFiles(.{ .root = upstream.path("src"), .files = &[_][]const u8{
        "argon2.c",
        "core.c",
        "blake2/blake2b.c",
        "thread.c",
        "encoding.c",
    }, .flags = &[_][]const u8{
        "-std=c89",
        "-Wall",
        "-g",
    } });
    argon2Module.addIncludePath(upstream.path("include"));
    argon2Module.addIncludePath(upstream.path("src"));

    // Configuring compilation based on options
    if (no_threads) {
        argon2Module.addCMacro("ARGON2_NO_THREADS", "1");
    } else {
        argon2Module.linkSystemLibrary("pthread", .{});
    }

    if (cpu_opt) {
        argon2Module.addCSourceFile(.{ .file = upstream.path("src/opt.c") });
    } else {
        argon2Module.addCSourceFile(.{ .file = upstream.path("src/ref.c") });
    }

    // Build command line utility
    const exe = b.addExecutable(.{
        .name = "argon2",
        .root_module = argon2Module,
        .version = version,
    });
    exe.addCSourceFile(.{ .file = upstream.path("src/run.c") });
    b.installArtifact(exe);

    // Run command line utility
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the argon2 executable");
    run_step.dependOn(&run_exe.step);

    // Build static library
    const static_lib = b.addLibrary(.{
        .name = "argon2",
        .linkage = .static,
        .root_module = argon2Module,
    });
    b.installArtifact(static_lib);

    // Build dynamic library
    const dynamic_lib = b.addLibrary(.{
        .name = "argon2",
        .linkage = .dynamic,
        .root_module = argon2Module,
        .version = version,
    });
    b.installArtifact(dynamic_lib);
    dynamic_lib.installHeader(upstream.path("include/argon2.h"), "argon2.h");
}
