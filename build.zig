const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const coretext_enabled = b.option(bool, "enable-coretext", "Build coretext") orelse false;
    const freetype_enabled = b.option(bool, "enable-freetype", "Build freetype") orelse false;

    const lib = b.addLibrary(.{
        .name = "harfbuzz",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    const root = lib.root_module;

    if (target.result.os.tag == .linux) {
        root.linkSystemLibrary("m", .{});
    }

    const freetype_dep = b.dependency("freetype", .{ .target = target, .optimize = optimize });
    root.linkLibrary(freetype_dep.artifact("freetype"));

    root.addIncludePath(b.path("upstream/src"));

    var flags = std.ArrayListUnmanaged([]const u8).empty;
    defer flags.deinit(b.allocator);

    try flags.append(b.allocator, "-DHAVE_STDBOOL_H");

    if (target.result.os.tag != .windows) {
        try flags.appendSlice(b.allocator, &.{
            "-DHAVE_UNISTD_H",
            "-DHAVE_SYS_MMAN_H",
            "-DHAVE_PTHREAD=1",
            // Hide our symbols so a downstream binary that also pulls in
            // a shared system libharfbuzz (via GTK/Pango) does not mix the
            // two ABIs at runtime.
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        });
    }

    if (freetype_enabled) {
        try flags.appendSlice(b.allocator, &.{
            "-DHAVE_FREETYPE=1",
            "-DHAVE_FT_GET_VAR_BLEND_COORDINATES=1",
            "-DHAVE_FT_SET_VAR_BLEND_COORDINATES=1",
            "-DHAVE_FT_DONE_MM_VAR=1",
            "-DHAVE_FT_GET_TRANSFORM=1",
        });
    }

    if (coretext_enabled) {
        try flags.append(b.allocator, "-DHAVE_CORETEXT=1");
        root.linkFramework("ApplicationServices", .{});
    }

    root.addCSourceFiles(.{
        .root = b.path(""),
        .files = srcs,
        .flags = flags.items,
    });

    lib.installHeadersDirectory(b.path("upstream/src"), "", .{
        .exclude_extensions = &.{
            ".build", ".c", ".cc", ".hh", ".in", ".py", ".rs", ".rl", ".ttf", ".txt",
        },
    });

    b.installArtifact(lib);
}

const srcs = &.{
    "upstream/src/harfbuzz.cc",
};
