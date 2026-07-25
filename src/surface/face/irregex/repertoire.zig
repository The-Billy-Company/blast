//! irregex — what the composed face can do, declared once.
//!
//! The single source for `irregex --help`, `irregex --schema`, verb dispatch,
//! and the unknown-verb line, in the same shape as relate's repertoire. The
//! two used to be separate hand-written JSON documents; `relate echoes` scored
//! them at 0.038 structure distance while 0.66 apart in bytes — the same
//! document written twice — which is what motivated the shared table.
//!
//! Rendering lives in `surface/cli/manifest.zig`; this file is only content.

const std = @import("std");
const manifest = @import("../../cli/manifest.zig");

const context = @import("context.zig");
const family = @import("family.zig");
const provenance = @import("provenance.zig");
const blast = @import("blast.zig");

/// Composed verbs never sweep implicitly: the scope is an argument, not a
/// default. Declared once so `context` and `family` cannot drift on it.
const scoped_roots = manifest.Arg{
    .name = "ROOT...",
    .kind = "string[]",
    .required = true,
    .doc = "corpus roots (mandatory unless --all)",
};

const all_flag = manifest.Flag{
    .name = "--all",
    .kind = "bool",
    .default = .{ .boolean = false },
    .doc = "scope the whole corpus instead of ROOT...",
};

const literal = manifest.Flag{ .name = "-F/--fixed-strings", .kind = "bool", .default = .{ .boolean = false }, .doc = "patterns are literals" };
const icase = manifest.Flag{ .name = "-i/--ignore-case", .kind = "bool", .default = .{ .boolean = false }, .doc = "case-insensitive patterns" };

pub const face = manifest.Face{
    .tool = "irregex",
    .tagline = "irregex — composed search: exact match narrows, compression reasons inside",
    .summary = "the composed face: exact match (gist) narrows a typed CandidateSet, then compression (relate) reasons inside it — context (coverage packing among matching files), family (fork families among matching files), provenance (quotation attribution re-verified against current bytes), blast (the live blast radius of a symbol from current bytes). gist and relate stay the direct faces; irregex owns the workflows.",
    .verbs = &.{
        .{
            .name = "context",
            .asks = "reading set among matching files",
            .form = "TEXT -e P [-e P...] [--match any|all] [-F] [-i]\n[--top N] [--json] {ROOT... | --all}",
            .blurb = "exact PatternSet filter first, then greedy coverage packing of TEXT\nover ONLY the matching files; each pick carries the patterns that\nadmitted it and its marginal bits (two scores, never fused)",
            .summary = "the minimal non-redundant reading set among files that ACTUALLY match the -e patterns: exact PatternSet filter first (match any = >=1 pattern, all = every pattern), then greedy submodular coverage packing of TEXT over a lexicon built from ONLY the candidate docs; each pick carries the patterns that admitted it and its marginal_bits — two separate scores, never fused",
            .args = &.{ .{ .name = "text", .required = true, .doc = "the query text to coverage-pack" }, scoped_roots },
            .flags = &.{
                .{ .name = "-e/--regexp", .kind = "string[]", .required = true, .doc = "an exact filter pattern (repeatable)" },
                .{ .name = "--match", .kind = "string", .default = .{ .text = "any" }, .doc = "candidate rule: any (>=1 pattern) | all (every pattern)" },
                literal,
                icase,
                all_flag,
                .{ .name = "--top", .kind = "int", .default = .{ .int = 8 }, .doc = "maximum files picked" },
                .{ .name = "--json", .kind = "bool", .default = .{ .boolean = false }, .doc = "NDJSON {rank, path, marginal_bits, coverage, patterns[]} rows" },
            },
            .run = context.runContext,
        },
        .{
            .name = "family",
            .asks = "similar vs distinct implementations",
            .form = "PATTERN [--unit function|match|file]\n[--max-structure-distance T | --max-distance T | --echo-min E]\n[-C N] [--only family|distinct|all] [--brief]\n[-F] [-i] [--top N] [--json] {ROOT... | --all}",
            .blurb = "exact hits become functions by default, then verified structural\nfamilies expose consolidation candidates; isolated regions remain\nvisible with their nearest neighbor and separate distances",
            .summary = "compare exact-hit implementations rather than their containing files: enclosing functions by default, bounded match windows or whole files explicitly; verified structure/byte/echo families identify consolidation candidates while every isolated region remains visible with its nearest neighbor and separate distances",
            .args = &.{ .{ .name = "pattern", .required = true, .doc = "the exact filter pattern" }, scoped_roots },
            .flags = &.{
                .{ .name = "--unit", .kind = "string", .default = .{ .text = "function" }, .doc = "comparison unit: function | match | file" },
                .{ .name = "--max-structure-distance", .kind = "float", .default = .{ .float = 0.35 }, .doc = "structural-family edge threshold for function/match units" },
                .{ .name = "--max-distance", .kind = "float", .doc = "byte near-duplicate edge threshold in [0,1] (file default 0.25)" },
                .{ .name = "--echo-min", .kind = "float", .doc = "structural-echo channel: smallest byte-minus-structure gap" },
                .{ .name = "-C/--context", .kind = "int", .default = .{ .int = 3 }, .doc = "lines around each match for --unit match" },
                .{ .name = "--min-size", .kind = "int", .default = .{ .int = 2 }, .doc = "smallest family surfaced" },
                .{ .name = "--only", .kind = "string", .default = .{ .text = "all" }, .doc = "answer class: family | distinct | all" },
                .{ .name = "--brief", .kind = "bool", .default = .{ .boolean = false }, .doc = "one scope-relative line per ranked family; implies --only family" },
                literal,
                icase,
                all_flag,
                .{ .name = "--top", .kind = "int", .default = .{ .int = 50 }, .doc = "rows surfaced after answer-class filtering" },
                .{ .name = "--json", .kind = "bool", .default = .{ .boolean = false }, .doc = "NDJSON families include repeated_lines + opportunity score + located members; distinct rows include nearest + independent distances" },
            },
            .run = family.runFamily,
        },
        .{
            .name = "provenance",
            .asks = "where a pasted snippet is really from",
            .form = "TEXT [--min-phrase N] [-C N] [--json]",
            .blurb = "quotation attribution against the codex shelf, then current-byte\nverification + context; a phrase surfaces only if the live file\nstill contains it (never a stale line)",
            .summary = "where did this text come from, and does the tree still contain it: relate's Ziv-Merhav cross-parse attributes each maximal verbatim phrase to one exemplar file on the codex shelf, then irregex re-reads that file's CURRENT bytes and re-finds the phrase exactly — a phrase is surfaced only if the live file still contains it (>=12-byte floor), never a stale line; requires `relate index --shelf` (or `gist codex build`)",
            .args = &.{.{ .name = "text", .required = true, .doc = "the pasted text to attribute" }},
            .flags = &.{
                .{ .name = "--min-phrase", .kind = "int", .default = .{ .int = 12 }, .doc = "shortest matched phrase reported (bytes)" },
                .{ .name = "-C/--context", .kind = "int", .default = .{ .int = 2 }, .doc = "context lines around each located phrase" },
                .{ .name = "--json", .kind = "bool", .default = .{ .boolean = false }, .doc = "NDJSON {text, occurrences, source, verified, line} rows" },
            },
            .run = provenance.runProvenance,
        },
        .{
            .name = "blast",
            .asks = "what moves if I change this symbol",
            .form = "SYMBOL [--budget N] [--json] {ROOT... | (whole corpus)}",
            .blurb = "the live blast radius of a symbol — its definition, the functions\nthat depend on it and that it depends on, its file's compression\ntwins, second-hop ripple, and the comments that mention it — all\nfrom CURRENT bytes, so a mid-edit file counts the moment it saves",
            .summary = "the live blast radius of a symbol computed from CURRENT bytes (no precomputed graph, so a mid-edit file counts the moment it saves): the seed's definition site(s) + kind guess, direct dependents (functions referencing it, def/use classified) and dependencies (identifiers the seed's body resolves to), tangential twins (compression kin of the seed's file — co-edit risk) and ripple (second-hop callers, hops=2), and comments that MENTION it (stale-doc / TODO surface). Exact and statistical evidence stay in separate fields — never a fused score",
            .args = &.{
                .{ .name = "symbol", .required = true, .doc = "the identifier (or concept token) to blast" },
                .{ .name = "ROOT...", .kind = "string[]", .doc = "corpus roots to narrow to; default is the whole CWD corpus" },
            },
            .flags = &.{
                .{ .name = "--budget", .kind = "int", .doc = "soft token cap; trims the lowest-priority tail (ripple/twins/comments first) and records stats.omitted" },
                .{ .name = "--json", .kind = "bool", .default = .{ .boolean = false }, .doc = "one JSON report {seed, direct{dependents,dependencies}, tangential{twins,ripple}, comments, stats, notes}" },
            },
            .run = blast.runBlast,
        },
    },
    .notes = &.{
        .{ .key = "candidate_set", .text = "exact matching first selects docs; family then lifts matching source lines into enclosing functions or bounded windows before compression, while --unit file keeps whole-doc candidates; blast selects the seed's neighborhood by word-bounded search + function-region extraction" },
        .{ .key = "scoring", .text = "exact and compression signals stay in SEPARATE fields — no fused relevance number" },
        .{ .key = "corpus_policy", .text = "context/family load the INDEX corpus under the roots and REQUIRE a scope (ROOT... or --all); provenance reads the corpus-wide codex shelf; blast scopes to the whole CWD corpus by default, narrowable with ROOT..." },
    },
    .exits = &.{
        .{ .code = 0, .means = "verb ran (rows may be empty)" },
        .{ .code = 2, .means = "usage, parse, pattern, or missing-shelf error" },
    },
    .epilogue =
    \\niche choices:
    \\  --match any               a file matches if ANY -e pattern hits (default)
    \\  --match all               a file matches only if EVERY -e pattern hits
    \\  family --unit function    compare enclosing implementations (default)
    \\  family --unit match -C N  compare bounded call-site windows
    \\  family --unit file        preserve whole-file kinship
    \\  family --max-structure-distance T  same shape under different names
    \\  family --max-distance T   byte near-duplicate forks (copy-paste drift)
    \\  family --echo-min E       renamed twins: same shape, different vocabulary
    \\  family --brief            ranked one-line consolidation candidates only
    \\  family --only MODE        emit family, distinct, or all rows (default all)
    \\  context/family scope      ROOT... or --all is REQUIRED (no silent .etc sweep)
    \\  provenance --min-phrase N raise the phrase floor to drop trivial quotes
    \\  blast --budget N          soft token cap; trims the lowest-priority tail
    \\  blast (scope)             ROOT... narrows; default is the whole CWD corpus
    \\  --json                    NDJSON on stdout; diagnostics stay on stderr
    \\
    \\see also:
    \\  gist <pattern>            the direct exact-search face
    \\  relate <verb> <text>      the direct compression-search face
    \\
    \\introspection:
    \\  irregex --help / -h        this guide
    \\  irregex --schema           versioned JSON verb contract for agents
    \\  irregex --version / -V
    \\
    ,
};

// ── tests ────────────────────────────────────────────────────────────────

const t = std.testing;

test "irregex --schema is valid JSON naming all composed verbs" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var buf: std.ArrayList(u8) = .empty;
    manifest.schema(&buf, a, face, "0.2.0");

    const parsed = try std.json.parseFromSlice(std.json.Value, a, buf.items, .{});
    try t.expectEqualStrings("irregex", parsed.value.object.get("tool").?.string);
    const verbs = parsed.value.object.get("verbs").?.object;
    for ([_][]const u8{ "context", "family", "provenance", "blast" }) |v| try t.expect(verbs.contains(v));
    try t.expectEqual(@as(usize, 4), verbs.count());
}

test "the composed verbs that require a scope say so in both registers" {
    // ADR-367: a composed query never silently sweeps. The manifest must not
    // be able to describe context/family as corpus-wide.
    for ([_][]const u8{ "context", "family" }) |name| {
        const v = face.find(name).?;
        const roots = v.args[v.args.len - 1];
        try t.expectEqualStrings("ROOT...", roots.name);
        try t.expect(roots.required);
    }
    // blast is corpus-wide by default, and its ROOT arg is correspondingly optional.
    const b = face.find("blast").?;
    try t.expect(!b.args[1].required);
}
