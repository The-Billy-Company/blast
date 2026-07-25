//! irregex — the composed-search CLI (the `irregex` binary, ADR-367).
//!
//! The third product face over the one irregex kernel. Where `gist` answers
//! "where is this exact pattern?" and `relate` answers "what is this like / what
//! covers it / what forked?", `irregex` answers the questions that need BOTH at
//! once — the exact engine to narrow the corpus and the compression engine to
//! reason inside that narrowing:
//!
//!   irregex context TEXT -e P…    the reading set among files that MATCH
//!   irregex family PATTERN        forks/twins among the matching implementations
//!   irregex provenance TEXT       attribution re-verified against current bytes
//!   irregex blast SYMBOL          the live blast radius, from CURRENT bytes
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

pub fn main(init: std.process.Init) void {
    irregex.commands.manifest.drive(
        irregex.commands.compose_repertoire.face,
        irregex.version_string,
        init,
    );
}
