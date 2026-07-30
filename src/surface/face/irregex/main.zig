//! irregex — the composed-search CLI (the `irregex` binary, ADR-367).
//!
//! The third product face over the one irregex kernel. Where `gist` answers
//! "where is this exact pattern?" and `relate` answers "what is near this one /
//! what repeats among all of them?", `irregex` answers the two questions that
//! need BOTH engines over the tree's CURRENT bytes:
//!
//!   irregex provenance TEXT       attribution re-verified against current bytes
//!   irregex blast SYMBOL          the live blast radius, from CURRENT bytes
//!
//! Composition-as-NARROWING is no longer a verb here. Narrowing the population
//! by an exact filter turned out to be a modifier on a question, not a question:
//! `relate pack --matching P` and `relate echoes --matching P` are what `irregex
//! context` and `irregex family` were, and being a flag they now combine with
//! every other axis those verbs carry (unit, channel, answer shape) instead of
//! freezing one point in that space per verb name.
//!
//! **Nothing about the surface is written here.** The verbs are declared once
//! in `repertoire.zig` and rendered by `surface/cli/manifest.zig` into the
//! help, the `--schema` manifest, the dispatch, the unknown-verb line, and the
//! process itself. This file is the binary's identity: which repertoire it
//! wears.
//!
//! Verb drivers live beside this file; the composition kernels live under
//! `src/kernel/compose/`, reached through the `irregex` module. `gist` and
//! `relate` are unchanged — this face forwards none of their verbs.

const std = @import("std");
const irregex = @import("irregex");
const chassis = @import("gist");

pub fn main(init: std.process.Init) void {
    chassis.cli.manifest.drive(
        @import("repertoire.zig").face,
        irregex.version_string,
        init,
    );
}
