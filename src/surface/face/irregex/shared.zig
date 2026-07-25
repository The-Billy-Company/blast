//! irregex CLI — the plumbing the composed verbs share.
//!
//! The `context`/`family` drivers both compile a `-e`/`PATTERN` set into a
//! PatternSet, decode a `CandidateSet` mask back to the patterns that admitted
//! a file, and render that list (human `[a, b]` / JSON `["a","b"]`). Kept here
//! so the two drivers cannot drift on how a mask reads or how a compile error
//! is reported.

const std = @import("std");
const fault = @import("../../../fault.zig");
const patterns_mod = @import("../../../kernel/batch/patterns.zig");
const cli_args = @import("../../exec/cold/argv/args.zig");
const emit = @import("../../cli/emit.zig");

const die = cli_args.die;
const oom = cli_args.oom;

/// Compile `pats` into a PatternSet under one shared `-F`/`-i` setting (the CLI
/// compiles ONE engine, so the whole set shares case/fixed — the same
/// constraint `relate patterns` enforces). Specs alias `pats`; caller keeps it
/// alive for the set's lifetime.
pub fn compileSet(gpa: std.mem.Allocator, pats: []const []const u8, fixed: bool, ignore_case: bool) !patterns_mod.PatternSet {
    const specs = try gpa.alloc(patterns_mod.Spec, pats.len);
    defer gpa.free(specs);
    for (pats, specs) |p, *s| s.* = .{ .pattern = p, .fixed = fixed, .ignore_case = ignore_case };
    return patterns_mod.PatternSet.compile(gpa, specs);
}

/// Report a PatternSet compile / candidate-select failure as a usage-class exit
/// (2), the same fail-closed shape the rest of the CLI speaks.
///
/// Typed to the two fault domains a compile or a select can actually produce
/// (ADR-373 law 2) rather than `anyerror`, so the switch is exhaustive: a new
/// member of either domain is a compile error here instead of a mystery string
/// in a user's terminal. The composed face offers no `-P`, so a pattern the
/// linear engine declines arrives already refused — a fault, not a declinature.
pub const CompileFault = fault.Pattern || fault.Resource;

pub fn dieCompile(e: CompileFault) noreturn {
    switch (e) {
        error.Unsupported => die("irregex: a pattern is outside gist's linear-time regex syntax (use -F for a literal, or simplify)\n", .{}),
        error.TooManyPatterns => die("irregex: too many patterns (max {d})\n", .{candidatesMax}),
        // The rest have no bespoke guidance to give, so naming the fault is the
        // honest report — listed, never `else`-caught.
        error.PowersetCapHit, error.NeedleTooShort, error.OutOfMemory, error.TimedOut => die("irregex: {s}\n", .{@errorName(e)}),
    }
}

const candidatesMax = @import("../../../kernel/compose/candidates.zig").max_patterns;

/// A JSON array of escaped strings — `["a","b"]` — for the composed verbs'
/// `--json` pattern lists. Reuses `emit.jsonStr`'s escaper per element.
pub fn jsonStrArray(buf: *std.ArrayList(u8), gpa: std.mem.Allocator, items: []const []const u8) void {
    buf.append(gpa, '[') catch oom();
    for (items, 0..) |s, i| {
        if (i != 0) buf.append(gpa, ',') catch oom();
        emit.jsonStr(buf, gpa, s);
    }
    buf.append(gpa, ']') catch oom();
}
