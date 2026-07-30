//! blast build graph — the composed-search face of the irregex ecosystem.
//!
//! One binary, `irregex`: the two questions that need BOTH engines over the
//! tree's CURRENT bytes (`provenance` · `blast`, ADR-367). All engine code
//! lives in the sibling packages — `irregex` (the exact engine), `relate`
//! (the compression kernels + composition), `gist` (the CLI chassis this face
//! wears) — so this graph is deliberately the smallest in the ecosystem: three
//! module imports and one executable. The C floors (PCRE2 under irregex,
//! libsais under relate) ride in transitively on those modules.

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // macOS deployment floor: below any plausible consumer link target
    // (kernelkit's convention, matching the sibling packages).
    const default_target: std.Target.Query = if (builtin.target.os.tag == .macos)
        .{ .os_version_min = .{ .semver = .{ .major = 13, .minor = 0, .patch = 0 } } }
    else
        .{};
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    const optimize = b.standardOptimizeOption(.{});

    // Same target/optimize on every sibling, so the build system dedupes the
    // path deps into one instance each — gist's own irregex/relate imports and
    // the ones below must be the SAME modules or their types won't unify.
    const opts = .{ .target = target, .optimize = optimize };
    const deps = [_]std.Build.Module.Import{
        .{ .name = "irregex", .module = b.dependency("irregex", opts).module("irregex") },
        .{ .name = "relate", .module = b.dependency("relate", opts).module("relate") },
        .{ .name = "gist", .module = b.dependency("gist", opts).module("gist") },
    };

    const exe = b.addExecutable(.{
        .name = "irregex",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/surface/face/irregex/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &deps,
        }),
    });
    b.installArtifact(exe);

    // `zig build check` — compile without installing, for the edit loop.
    b.step("check", "Compile the irregex binary without installing").dependOn(&exe.step);
}
