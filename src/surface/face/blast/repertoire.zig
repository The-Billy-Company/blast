//! blast — what the composed face can do, declared once.
//!
//! The single source for `blast --help`, `blast --schema`, verb dispatch,
//! and the unknown-verb line, in the same shape as relate's repertoire. The
//! two used to be separate hand-written JSON documents; `relate echoes` scored
//! them at 0.038 structure distance while 0.66 apart in bytes — the same
//! document written twice — which is what motivated the shared table.
//!
//! Rendering lives in `surface/cli/manifest.zig`; this file is only content.

const std = @import("std");
const manifest = @import("relate").cli.manifest;

const provenance = @import("provenance.zig");
const blast = @import("blast.zig");

pub const face = manifest.Face{
    .tool = "blast",
    .tagline = "blast — composed search: exact match narrows, compression reasons inside",
    .summary = "the composed face, for the two questions that need CURRENT bytes rather than a narrowing: provenance (quotation attribution re-verified against the live file) and blast (the live blast radius of a symbol, computed from current bytes with no precomputed graph). composition-as-narrowing became a modifier — `relate pack --matching` and `relate echoes --matching` are what `irregex context` and `blast family` were, now combinable with every other axis those verbs have. gist and relate stay the direct faces.",
    .verbs = &.{
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
            .keeps = true,
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
            .keeps = true,
        },
    },
    .retired = &.{
        .{
            .name = "context",
            .tool = "relate",
            .now = "pack <text> --matching PAT",
            .because = "narrowing is a modifier, not a verb — as a flag it composes with everything else pack knows, and one exact filter now means the same thing on every relate query verb",
        },
        .{
            .name = "family",
            .tool = "relate",
            .now = "echoes --matching PAT --unit function --shape families",
            .because = "the composed fork-family question is the repetition verb with an exact filter — same unit/channel/shape axes, one implementation",
        },
    },
    .notes = &.{
        .{ .key = "candidate_set", .text = "blast selects the seed's neighborhood by word-bounded search + function-region extraction; the narrowing composition (exact select, then compression inside the matching set) now lives on the relate verbs as --matching" },
        .{ .key = "scoring", .text = "exact and compression signals stay in SEPARATE fields — no fused relevance number" },
        .{ .key = "corpus_policy", .text = "provenance reads the corpus-wide codex shelf; blast scopes to the whole CWD corpus by default, narrowable with ROOT..." },
    },
    .exits = &.{
        .{ .code = 0, .means = "verb ran (rows may be empty)" },
        .{ .code = 2, .means = "usage, parse, pattern, or missing-shelf error" },
    },
    .epilogue =
    \\niche choices:
    \\  provenance --min-phrase N raise the phrase floor to drop trivial quotes
    \\  provenance -C N           context lines around each located phrase
    \\  blast --budget N          soft token cap; trims the lowest-priority tail
    \\  blast (scope)             ROOT... narrows; default is the whole CWD corpus
    \\  --json                    NDJSON on stdout; diagnostics stay on stderr
    \\
    \\composition is a flag now, not a verb:
    \\  relate pack --matching PAT <text>        the reading set among matching files
    \\  relate echoes --matching PAT --unit function --shape families
    \\                                           fork families among matching regions
    \\  relate similar --matching PAT <probe>    nearest kin inside the matching set
    \\  --match any|all           a file matches on >=1 pattern, or on every pattern
    \\
    \\see also:
    \\  gist <pattern>            the direct exact-search face
    \\  relate <verb> <text>      the direct compression-search face
    \\
    \\introspection:
    \\  blast --help / -h        this guide
    \\  blast --schema           versioned JSON verb contract for agents
    \\  blast --version / -V
    \\
    ,
};

// ── tests ────────────────────────────────────────────────────────────────

const t = std.testing;

test "blast --schema is valid JSON naming the composed verbs that remain" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var buf: std.ArrayList(u8) = .empty;
    manifest.schema(&buf, a, face, "0.2.0");

    const parsed = try std.json.parseFromSlice(std.json.Value, a, buf.items, .{});
    try t.expectEqualStrings("blast", parsed.value.object.get("tool").?.string);
    const verbs = parsed.value.object.get("verbs").?.object;
    for ([_][]const u8{ "provenance", "blast" }) |v| try t.expect(verbs.contains(v));
    try t.expectEqual(@as(usize, 2), verbs.count());
}

test "the narrowing verbs point at their relate replacement, in the other face" {
    // These two folded ACROSS binaries, so the coaching line names the tool it
    // moved to — `face.find` would be the wrong check here, and a bare verb name
    // would send the caller to `blast pack`, which does not exist.
    for ([_][]const u8{ "context", "family" }) |name| {
        try t.expect(face.find(name) == null);
        const r = face.folded(name).?;
        try t.expectEqualStrings("relate", r.tool.?);
        try t.expectEqualStrings("relate", r.invocation(face.tool)[0]);
        try t.expect(std.mem.indexOf(u8, r.now, "--matching") != null);
    }
}

test "blast stays corpus-wide by default, and says so in its args" {
    // The scope invariant that survived the fold: a composed query that DOES
    // sweep must declare its ROOT arg optional, and nothing else may.
    const b = face.find("blast").?;
    try t.expectEqualStrings("ROOT...", b.args[1].name);
    try t.expect(!b.args[1].required);
}
