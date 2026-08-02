//! blast build graph — the composed-search face of the irregex ecosystem.
//!
//! One binary, `blast`: the two questions that need BOTH engines over the
//! tree's CURRENT bytes (`provenance` · `blast`), plus the C-ABI dual
//! artifact (`libblast` + `include/blast.h`). All engine code lives in the
//! sibling packages — `irregex` (the exact engine) and `relate` (the
//! compression kernels + composition + the CLI vocabulary this face wears) —
//! so this graph is deliberately small. The C floors (PCRE2 under irregex,
//! libsais under relate) and gist's daemon (the answer keep) ride in
//! transitively on those modules. `libblast` dynamically links `libirgx`
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

    // ── the one place this package's semver lives ──
    // `build.zig.zon`'s `.version` is the single authority; the face reads it
    // through this option instead of restating it, so `blast --version` and the
    // `--schema` manifest answer with THIS package's number rather than the
    // engine's. Every remaining copy is a publishing manifest that cannot import
    // anything (Cargo, PyPI); those carry an `x-release-please-version` marker
    // and are moved by the release bot, with `tools/version_parity.py` failing
    // if one of them lags.
    //
    // The package name rides along so this generated file differs from the ones
    // the siblings generate. Zig content-addresses it, and two packages whose
    // only option was an identical version string produced the SAME file — which
    // it then refuses as the root of two modules.
    const zon = @import("build.zig.zon");
    const version = b.addOptions();
    version.addOption([:0]const u8, "version", zon.version);
    version.addOption([:0]const u8, "package", @tagName(zon.name));

    const root = b.path("src/surface/face/blast/main.zig");
    const face = b.createModule(.{
        .root_source_file = root,
        .target = target,
        .optimize = optimize,
        .imports = &deps,
    });
    face.addOptions("build_options", version);
    const exe = b.addExecutable(.{ .name = "blast", .root_module = face });
    b.installArtifact(exe);

    // ── the C-ABI dual artifact ──
    // Rooted at the export shims so no dependent of a blast module would
    // re-emit `blast_run`. Substrate symbols resolve through libirgx.
    const irgx_dep = b.dependency("irregex", .{ .target = target, .optimize = lib_optimize });
    const irgx_lib = irgx_dep.artifact("irgx");
    const abi = b.createModule(.{
        .root_source_file = b.path("src/surface/ffi/exports.zig"),
        .target = target,
        .optimize = lib_optimize,
        .pic = true,
        .imports = &.{.{ .name = "irregex", .module = irgx_dep.module("irregex") }},
    });
    abi.linkLibrary(irgx_lib);
    // A shipped dylib has to find its substrate beside itself. `linkLibrary`
    // records only this build tree's own output dir — a RELATIVE
    // `.zig-cache/o/<hash>` path, meaningless on a consumer's machine — so
    // `dlopen("libblast.dylib")` from anywhere else cannot resolve
    // `@rpath/libirgx.dylib` and fails at load. A loader-relative rpath makes
    // the shape we actually ship ("both libraries in one lib dir") the loadable
    // one, without naming an absolute path we do not own.
    abi.addRPathSpecial(if (target.result.os.tag == .macos) "@loader_path" else "$ORIGIN");
    const dynamic_lib = b.addLibrary(.{ .name = "blast", .linkage = .dynamic, .root_module = abi });
    dynamic_lib.installHeader(b.path("include/blast.h"), "blast.h");
    // gist.h is a sibling-checkout header; blast does not take a Zig module
    // dep on gist (the engine comes through relate), but the C ABI names
    // gist_engine / gist_cancel, so the header installs beside ours.
    dynamic_lib.installHeader(b.path("../gist/include/gist.h"), "gist.h");
    dynamic_lib.installHeader(irgx_dep.path("include/irgx.h"), "irgx.h");
    b.installArtifact(dynamic_lib);
    if (target.result.os.tag == .macos) {
        const obj = b.addObject(.{ .name = "blast", .root_module = abi });
        const repack = b.addSystemCommand(&.{ "libtool", "-static", "-o" });
        const aligned_a = repack.addOutputFileArg("libblast.a");
        repack.addArtifactArg(obj);
        b.getInstallStep().dependOn(&b.addInstallLibFile(aligned_a, "libblast.a").step);
    } else {
        // Installed as a FILE, not an artifact. `installArtifact` publishes a
        // name into the table a dependent's `dep.artifact("blast")` searches,
        // and the dylib above already owns `blast`; a second registration makes
        // that lookup ambiguous and panics the build runner in the DEPENDENT,
        // never here — invisible on a laptop, since this is the arm macOS does
        // not take. The macOS arm is already file-shaped for its own reason, so
        // this makes both arms install `libblast.a` the same way.
        const static_lib = b.addLibrary(.{ .name = "blast", .linkage = .static, .root_module = abi });
        b.getInstallStep().dependOn(&b.addInstallLibFile(static_lib.getEmittedBin(), "libblast.a").step);
    }
    b.installArtifact(irgx_lib);
    // `libblast.a` resolves its substrate symbols through libirgx rather than
    // redefining them, so a static consumer links the pair and this prefix has
    // to hold the other half. It is an install-file product of the irregex
    // package rather than a named artifact, so it comes across as a named lazy
    // path — the right target by construction, not a copy of whatever a
    // sibling checkout last built.
    b.getInstallStep().dependOn(
        &b.addInstallLibFile(irgx_dep.namedLazyPath("libirgx.a"), "libirgx.a").step,
    );

    // `zig build test` — the face's own unit tests plus the FFI dispatch.
    // Debug regardless of the CLI's ReleaseFast posture, since a release
    // build elides the safety checks a test is partly there to trip.
    const test_deps = [_]std.Build.Module.Import{
        .{ .name = "irregex", .module = irgx_dep.module("irregex") },
        .{ .name = "relate", .module = b.dependency("relate", .{ .target = target, .optimize = .Debug }).module("relate") },
    };
    const test_face = b.createModule(.{
        .root_source_file = root,
        .target = target,
        .optimize = .Debug,
        .imports = &test_deps,
    });
    test_face.addOptions("build_options", version);
    const tests = b.addTest(.{ .root_module = test_face });
    const ffi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/surface/ffi/analytic.zig"),
            .target = target,
            .optimize = .Debug,
            .imports = &.{.{ .name = "irregex", .module = irgx_dep.module("irregex") }},
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
