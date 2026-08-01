//! blast build graph — the composed-search face of the irregex ecosystem.
//!
//! One binary, `blast`: the two questions that need BOTH engines over the
//! tree's CURRENT bytes (`provenance` · `blast`), plus the C-ABI dual
//! artifact (`libblast` + `include/blast.h`). All engine code lives in the
//! sibling packages — `irregex` (the exact engine) and `relate` (the
//! compression kernels + composition + the CLI vocabulary this face wears) —
//! so this graph is deliberately small. The C floors (PCRE2 under irregex,
//! libsais under relate) and gist's daemon (the answer keep) ride in
//! transitively on those modules. `libblast` dynamically links `libirregex`
//! for the substrate symbols it does not redefine.

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // macOS deployment floor: below any plausible consumer link target
    // (matching the sibling packages).
    const default_target: std.Target.Query = if (builtin.target.os.tag == .macos)
        .{ .os_version_min = .{ .semver = .{ .major = 13, .minor = 0, .patch = 0 } } }
    else
        .{};
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    const lib_optimize = b.standardOptimizeOption(.{});

    // ReleaseFast regardless of the build-wide `-Doptimize` — same product
    // posture as gist's faces: a bare `zig build` must never install a slow
    // debug `blast`. `-Dcli-optimize=Debug` still yields a debug binary.
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "cli-optimize",
        "optimize mode for the installed blast CLI (default ReleaseFast — the product surface's whole point is speed)",
    ) orelse .ReleaseFast;

    // Same target/optimize on every sibling, so the build system dedupes the
    // path deps into one instance each — relate's own irregex/gist imports and
    // the ones below must be the SAME modules or their types won't unify.
    const opts = .{ .target = target, .optimize = optimize };
    const deps = [_]std.Build.Module.Import{
        .{ .name = "irregex", .module = b.dependency("irregex", opts).module("irregex") },
        .{ .name = "relate", .module = b.dependency("relate", opts).module("relate") },
    };

    const root = b.path("src/surface/face/blast/main.zig");
    const exe = b.addExecutable(.{
        .name = "blast",
        .root_module = b.createModule(.{
            .root_source_file = root,
            .target = target,
            .optimize = optimize,
            .imports = &deps,
        }),
    });
    b.installArtifact(exe);

    // ── the C-ABI dual artifact ──
    // Rooted at the export shims so no dependent of a blast module would
    // re-emit `blast_run`. Substrate symbols resolve through libirregex.
    const irregex_dep = b.dependency("irregex", .{ .target = target, .optimize = lib_optimize });
    const irregex_lib = irregex_dep.artifact("irregex");
    const abi = b.createModule(.{
        .root_source_file = b.path("src/surface/ffi/exports.zig"),
        .target = target,
        .optimize = lib_optimize,
        .pic = true,
        .imports = &.{.{ .name = "irregex", .module = irregex_dep.module("irregex") }},
    });
    abi.linkLibrary(irregex_lib);
    // A shipped dylib has to find its substrate beside itself. `linkLibrary`
    // records only this build tree's own output dir — a RELATIVE
    // `.zig-cache/o/<hash>` path, meaningless on a consumer's machine — so
    // `dlopen("libblast.dylib")` from anywhere else cannot resolve
    // `@rpath/libirregex.dylib` and fails at load. A loader-relative rpath makes
    // the shape we actually ship ("both libraries in one lib dir") the loadable
    // one, without naming an absolute path we do not own.
    abi.addRPathSpecial(if (target.result.os.tag == .macos) "@loader_path" else "$ORIGIN");
    const dynamic_lib = b.addLibrary(.{ .name = "blast", .linkage = .dynamic, .root_module = abi });
    dynamic_lib.installHeader(b.path("include/blast.h"), "blast.h");
    // gist.h is a sibling-checkout header; blast does not take a Zig module
    // dep on gist (the engine comes through relate), but the C ABI names
    // gist_engine / gist_cancel, so the header installs beside ours.
    dynamic_lib.installHeader(b.path("../gist/include/gist.h"), "gist.h");
    dynamic_lib.installHeader(irregex_dep.path("include/irregex.h"), "irregex.h");
    b.installArtifact(dynamic_lib);
    if (target.result.os.tag == .macos) {
        const obj = b.addObject(.{ .name = "blast", .root_module = abi });
        const repack = b.addSystemCommand(&.{ "libtool", "-static", "-o" });
        const aligned_a = repack.addOutputFileArg("libblast.a");
        repack.addArtifactArg(obj);
        b.getInstallStep().dependOn(&b.addInstallLibFile(aligned_a, "libblast.a").step);
    } else {
        const static_lib = b.addLibrary(.{ .name = "blast", .linkage = .static, .root_module = abi });
        b.installArtifact(static_lib);
    }
    b.installArtifact(irregex_lib);

    // `zig build test` — the face's own unit tests plus the FFI dispatch.
    // Debug regardless of the CLI's ReleaseFast posture, since a release
    // build elides the safety checks a test is partly there to trip.
    const test_deps = [_]std.Build.Module.Import{
        .{ .name = "irregex", .module = irregex_dep.module("irregex") },
        .{ .name = "relate", .module = b.dependency("relate", .{ .target = target, .optimize = .Debug }).module("relate") },
    };
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = root,
            .target = target,
            .optimize = .Debug,
            .imports = &test_deps,
        }),
    });
    const ffi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/surface/ffi/analytic.zig"),
            .target = target,
            .optimize = .Debug,
            .imports = &.{.{ .name = "irregex", .module = irregex_dep.module("irregex") }},
        }),
    });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&b.addRunArtifact(ffi_tests).step);

    // `zig build check` — compile without installing, for the edit loop.
    b.step("check", "Compile the blast binary without installing").dependOn(&exe.step);

    // Same kcov lane the three sibling packages carry. Only the composed face's
    // own sources are instrumented: the engines it composes are measured where
    // they are written, and folding them in here would double-count them.
    const run_cov = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/" });
    run_cov.addArg(b.pathFromRoot(".local/coverage"));
    run_cov.addArtifactArg(tests);
    b.step("coverage", "Run unit tests under kcov → .local/coverage/ (Cobertura XML)")
        .dependOn(&run_cov.step);
}
