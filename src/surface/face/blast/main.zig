//! blast — the composed-search CLI (the `blast` binary).
//!
//! The third product face over the one irregex kernel. Where `gist` answers
//! "where is this exact pattern?" and `relate` answers "what is near this one /
//! what repeats among all of them?", `blast` answers the two questions that
//! need BOTH engines over the tree's CURRENT bytes:
//!
//!   blast provenance TEXT       attribution re-verified against current bytes
//!   blast blast SYMBOL          the live blast radius, from CURRENT bytes
//!
//! Composition-as-NARROWING is no longer a verb here. Narrowing the population
//! by an exact filter turned out to be a modifier on a question, not a question:
//! `relate pack --matching P` and `relate echoes --matching P` are what the
//! retired `context` and `family` verbs were, and being a flag they now combine
//! with every other axis those verbs carry (unit, channel, answer shape)
//! instead of freezing one point in that space per verb name.
//!
//! **Nothing about the surface is written here.** The verbs are declared once
//! in `repertoire.zig` and rendered by `surface/cli/manifest.zig` into the
//! help, the `--schema` manifest, the dispatch, the unknown-verb line, and the
//! process itself. This file is the binary's identity: which repertoire it
//! wears.
//!
//! Verb drivers live beside this file; the composition kernels live under
//! relate's `kernel/compose/`, reached through the `relate` module. `gist` and
//! `relate` are unchanged — this face forwards none of their verbs.

const std = @import("std");
const irregex = @import("irregex");
const relate = @import("relate");

/// Sign diagnostics as the program the user actually typed. Only the name
/// moves: the knobs and artifact directory stay the ecosystem's, since this
/// binary reads the index, atlas, and shelf the siblings write.
pub const irgx_brand: irregex.Brand = .{ .name = "blast" };

/// This package's semver, read from `build.zig.zon`'s `.version` — the single
/// place it is written. `build.zig` lifts it in as a build option, so
/// `blast --version` and the `--schema` manifest answer with this binary's own
/// number. They used to answer with the engine's, which is a different axis and
/// a different schedule: the manifest read 1.0.0 while this package was 0.1.0.
/// `irregex.version_string` is still how you ask what is underneath.
pub const version_string: [:0]const u8 = @import("build_options").version;

pub fn main(init: std.process.Init) void {
    relate.cli.manifest.drive(
        @import("repertoire.zig").face,
        version_string,
        init,
    );
}

test {
    // `main` is unreferenced in a test build, so the only `@import` of the face
    // lives in a body that never gets analyzed — and the tests below it were
    // collected nowhere at all. Naming the modules here is the sibling roots'
    // pattern, and it keeps a future test in any of them reachable by default.
    _ = @import("blast.zig");
    _ = @import("provenance.zig");
    _ = @import("repertoire.zig");
    _ = @import("jsonsafe.zig");
}
