//! irregex CLI — the plumbing the composed verbs share.
//!
//! The `context`/`family` drivers both compile a `-e`/`PATTERN` set into a
//! PatternSet, decode a `CandidateSet` mask back to the patterns that admitted
//! a file, and render that list (human `[a, b]` / JSON `["a","b"]`). Kept here
//! so the two drivers cannot drift on how a mask reads or how a compile error
//! is reported.

const std = @import("std");
const patterns_mod = @import("../../../kernel/batch/patterns.zig");
const cli_args = @import("../../exec/cold/argv/args.zig");
const scope = @import("../../../corpus/scope/glob.zig");
const flags = @import("../../cli/flags.zig");
const emit = @import("../../cli/emit.zig");

const die = cli_args.die;
const oom = cli_args.oom;

/// The flag surface every composed verb shares — `-F`/`-i` (one compiled
/// engine, so case/fixed apply to the whole set), `--top`, `--json`, `--all`
/// (drop the mandatory-scope guard and sweep the whole corpus) — plus the
/// first bare arg as the verb's positional and every later one as a root.
/// Each verb seeds `top`, matches its OWN flags first, then routes the rest
/// through `commonArg`. This mirrors relate's `parseOpts` shape for the compose
/// face: the shared arms live once so the two drivers can't drift.
pub const Common = struct {
    fixed: bool = false,
    ignore_case: bool = false,
    json: bool = false,
    all: bool = false,
    top: usize,
    positional: ?[]const u8 = null,
};

/// Consume the shared arg at `argv[i.*]` into `c` (advancing `i` past any
/// value it takes), or fold a bare arg into `positional` then `roots`. The
/// loop's terminal handler: verb-specific flags MUST be tried before it, so an
/// unrecognized `-flag` seen after the positional is a fatal unknown-flag.
/// `verb` names the sub-command for that death.
pub fn commonArg(
    gpa: std.mem.Allocator,
    argv: []const []const u8,
    i: *usize,
    c: *Common,
    roots: *std.ArrayList([]const u8),
    comptime verb: []const u8,
) void {
    const arg = argv[i.*];
    if (std.mem.eql(u8, arg, "-F") or std.mem.eql(u8, arg, "--fixed-strings")) {
        c.fixed = true;
    } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--ignore-case")) {
        c.ignore_case = true;
    } else if (std.mem.eql(u8, arg, "--top")) {
        c.top = flags.count(argv, i, "--top");
    } else if (std.mem.eql(u8, arg, "--json")) {
        c.json = true;
    } else if (std.mem.eql(u8, arg, "--all")) {
        c.all = true;
    } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1 and c.positional != null) {
        die("irregex " ++ verb ++ ": unknown flag {s}\n", .{arg});
    } else if (c.positional == null) {
        c.positional = arg;
    } else {
        roots.append(gpa, scope.normalizeRoot(arg)) catch oom();
    }
}

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
pub fn dieCompile(e: anyerror) noreturn {
    switch (e) {
        error.Unsupported => die("irregex: a pattern is outside gist's linear-time regex syntax (use -F for a literal, or simplify)\n", .{}),
        error.TooManyPatterns => die("irregex: too many patterns (max {d})\n", .{candidatesMax}),
        else => die("irregex: {s}\n", .{@errorName(e)}),
    }
}

const candidatesMax = @import("../../../kernel/compose/candidates.zig").max_patterns;

/// The patterns a `CandidateSet` mask admitted a file by: the borrowed pattern
/// slices (`items`) plus a comma-joined human string (`joined`). Caller `deinit`s.
pub const Labels = struct {
    gpa: std.mem.Allocator,
    items: [][]const u8,
    joined: []u8,

    pub fn deinit(self: *Labels) void {
        self.gpa.free(self.items);
        self.gpa.free(self.joined);
    }
};

/// Decode `mask` (bit i = pattern i matched) into the matched patterns and a
/// `"a, b"` join. Bit order is ascending, so the labels read in `-e` order.
pub fn matchedLabels(gpa: std.mem.Allocator, pats: []const []const u8, mask: u64) Labels {
    var items: std.ArrayList([]const u8) = .empty;
    var joined: std.ArrayList(u8) = .empty;
    for (pats, 0..) |p, i| {
        if (mask & (@as(u64, 1) << @intCast(i)) == 0) continue;
        if (joined.items.len != 0) joined.appendSlice(gpa, ", ") catch oom();
        joined.appendSlice(gpa, p) catch oom();
        items.append(gpa, p) catch oom();
    }
    return .{
        .gpa = gpa,
        .items = items.toOwnedSlice(gpa) catch oom(),
        .joined = joined.toOwnedSlice(gpa) catch oom(),
    };
}

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
