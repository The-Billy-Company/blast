//! irregex — the composed-search CLI (the `irregex` binary, ADR-367).
//!
//! The third product face over the one irregex kernel. Where `gist` answers
//! "where is this exact pattern?" and `relate` answers "what is this like / what
//! covers it / what forked?", `irregex` answers the questions that need BOTH at
//! once — the exact engine to narrow the corpus and the compression engine to
//! reason inside that narrowing:
//!
//!   irregex context TEXT -e P [-e P...] [--match any|all] [-F] [-i]
//!                   [--top N] [--json] {ROOT... | --all}
//!       the minimal non-redundant reading set among files that ACTUALLY match
//!       the intents — exact PatternSet filter, then coverage packing inside it
//!   irregex family PATTERN [--unit function|match|file]
//!                  [--max-structure-distance T | --max-distance T | --echo-min E]
//!                  [-C N] [--only family|distinct|all] [--brief]
//!                  [-F] [-i] [--top N] [--json] {ROOT... | --all}
//!       compare exact-hit implementations; family rows show consolidation
//!       candidates and distinct rows retain genuinely different regions
//!   irregex provenance TEXT [--min-phrase N] [-C N] [--json]
//!       where a pasted snippet is really from — quotation attribution, then
//!       current-byte verification + context for every phrase
//!
//! Plus `--help`, `--version`, `--schema` (a JSON capability manifest). Thin
//! dispatch only: verb drivers live beside this file; the composition kernels
//! live under `src/kernel/compose/`, reached through the `irregex` module.
//! `gist` and `relate` are unchanged — this face forwards none of their verbs.

const std = @import("std");
const irregex = @import("irregex");

const context = irregex.commands.compose_context;
const family = irregex.commands.compose_family;
const provenance = irregex.commands.compose_provenance;
const blast = irregex.commands.compose_blast;
const schema = irregex.commands.compose_schema;

fn usage() void {
    irregex.corpus.emitStdout(
        \\irregex — composed search: exact match narrows, compression reasons inside
        \\
        \\ergonomics — one engine can't answer these; both together can:
        \\  reading set among matching files      context
        \\  similar vs distinct implementations  family
        \\  where a pasted snippet is really from  provenance
        \\  what moves if I change this symbol    blast
        \\
        \\verbs:
        \\  irregex context TEXT -e P [-e P...] [--match any|all] [-F] [-i]
        \\                  [--top N] [--json] {ROOT... | --all}
        \\      exact PatternSet filter first, then greedy coverage packing of TEXT
        \\      over ONLY the matching files; each pick carries the patterns that
        \\      admitted it and its marginal bits (two scores, never fused)
        \\  irregex family PATTERN [--unit function|match|file]
        \\                 [--max-structure-distance T | --max-distance T | --echo-min E]
        \\                 [-C N] [--only family|distinct|all] [--brief]
        \\                 [-F] [-i] [--top N] [--json] {ROOT... | --all}
        \\      exact hits become functions by default, then verified structural
        \\      families expose consolidation candidates; isolated regions remain
        \\      visible with their nearest neighbor and separate distances
        \\  irregex provenance TEXT [--min-phrase N] [-C N] [--json]
        \\      quotation attribution against the codex shelf, then current-byte
        \\      verification + context; a phrase surfaces only if the live file
        \\      still contains it (never a stale line)
        \\  irregex blast SYMBOL [--budget N] [--json] {ROOT... | (whole corpus)}
        \\      the live blast radius of a symbol — its definition, the functions
        \\      that depend on it and that it depends on, its file's compression
        \\      twins, second-hop ripple, and the comments that mention it — all
        \\      from CURRENT bytes, so a mid-edit file counts the moment it saves
        \\
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
    );
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    // Cold CLI diagnostic policy: stderr sink, lens mask + render format read
    // once from `GIST_TRACE`/`GIST_TRACE_FORMAT`.
    irregex.assay.install(.{});

    var it = std.process.Args.Iterator.init(init.minimal.args);
    _ = it.skip(); // argv[0]
    const mode = it.next() orelse {
        usage();
        return;
    };

    if (std.mem.eql(u8, mode, "--help") or std.mem.eql(u8, mode, "-h")) {
        usage();
        return;
    }
    if (std.mem.eql(u8, mode, "--version") or std.mem.eql(u8, mode, "-V")) {
        std.debug.print("irregex {s}\n", .{irregex.version_string});
        return;
    }
    if (std.mem.eql(u8, mode, "--schema")) {
        schema.emit();
        return;
    }

    irregex.corpus.initOutputBudget(false);

    const dispatch = .{
        .{ "context", context.runContext },
        .{ "family", family.runFamily },
        .{ "provenance", provenance.runProvenance },
        .{ "blast", blast.runBlast },
    };
    inline for (dispatch) |d| {
        if (std.mem.eql(u8, mode, d[0])) {
            var rest: std.ArrayList([]const u8) = .empty;
            defer rest.deinit(gpa);
            while (it.next()) |arg| try rest.append(gpa, arg);
            try d[1](gpa, io, rest.items);
            return;
        }
    }

    std.debug.print("irregex: unknown verb '{s}' (context | family | provenance | blast; --help)\n", .{mode});
    std.process.exit(2);
}
