//! irregex --schema — the composed face's machine-readable capability manifest.
//!
//! Three closed composed verbs (ADR-367); like relate's manifest this is one
//! comptime document, kept honest by the JSON-validity test below.

const std = @import("std");
const corpus_mod = @import("../../../corpus/tree/corpus.zig");

const manifest =
    \\{
    \\  "tool": "irregex",
    \\  "version": "0.1.0",
    \\  "summary": "the composed face: exact match (gist) narrows a typed CandidateSet, then compression (relate) reasons inside it — context (coverage packing among matching files), family (fork families among matching files), provenance (quotation attribution re-verified against current bytes). gist and relate stay the direct faces; irregex owns the workflows.",
    \\  "verbs": {
    \\    "context": {
    \\      "summary": "the minimal non-redundant reading set among files that ACTUALLY match the -e patterns: exact PatternSet filter first (match any = >=1 pattern, all = every pattern), then greedy submodular coverage packing of TEXT over a lexicon built from ONLY the candidate docs; each pick carries the patterns that admitted it and its marginal_bits — two separate scores, never fused",
    \\      "args": [{"name": "text", "type": "string", "required": true, "description": "the query text to coverage-pack"}, {"name": "ROOT...", "type": "string[]", "required": true, "description": "corpus roots (mandatory unless --all)"}],
    \\      "flags": [{"name": "-e/--regexp", "type": "string[]", "required": true, "description": "an exact filter pattern (repeatable)"}, {"name": "--match", "type": "string", "default": "any", "description": "candidate rule: any (>=1 pattern) | all (every pattern)"}, {"name": "-F/--fixed-strings", "type": "bool", "default": false, "description": "patterns are literals"}, {"name": "-i/--ignore-case", "type": "bool", "default": false, "description": "case-insensitive patterns"}, {"name": "--all", "type": "bool", "default": false, "description": "scope the whole corpus instead of ROOT..."}, {"name": "--top", "type": "int", "default": 8, "description": "maximum files picked"}, {"name": "--json", "type": "bool", "default": false, "description": "NDJSON {rank, path, marginal_bits, coverage, patterns[]} rows"}]
    \\    },
    \\    "family": {
    \\      "summary": "compare exact-hit implementations rather than their containing files: enclosing functions by default, bounded match windows or whole files explicitly; verified structure/byte/echo families identify consolidation candidates while every isolated region remains visible with its nearest neighbor and separate distances",
    \\      "args": [{"name": "pattern", "type": "string", "required": true, "description": "the exact filter pattern"}, {"name": "ROOT...", "type": "string[]", "required": true, "description": "corpus roots (mandatory unless --all)"}],
    \\      "flags": [{"name": "--unit", "type": "string", "default": "function", "description": "comparison unit: function | match | file"}, {"name": "--max-structure-distance", "type": "float", "default": 0.35, "description": "structural-family edge threshold for function/match units"}, {"name": "--max-distance", "type": "float", "default": null, "description": "byte near-duplicate edge threshold in [0,1] (file default 0.25)"}, {"name": "--echo-min", "type": "float", "default": null, "description": "structural-echo channel: smallest byte-minus-structure gap"}, {"name": "-C/--context", "type": "int", "default": 3, "description": "lines around each match for --unit match"}, {"name": "--min-size", "type": "int", "default": 2, "description": "smallest family surfaced"}, {"name": "--only", "type": "string", "default": "all", "description": "answer class: family | distinct | all"}, {"name": "--brief", "type": "bool", "default": false, "description": "one scope-relative line per ranked family; implies --only family"}, {"name": "-F/--fixed-strings", "type": "bool", "default": false, "description": "pattern is a literal"}, {"name": "-i/--ignore-case", "type": "bool", "default": false, "description": "case-insensitive pattern"}, {"name": "--all", "type": "bool", "default": false, "description": "scope the whole corpus instead of ROOT..."}, {"name": "--top", "type": "int", "default": 50, "description": "rows surfaced after answer-class filtering"}, {"name": "--json", "type": "bool", "default": false, "description": "NDJSON families include repeated_lines + opportunity score + located members; distinct rows include nearest + independent distances"}]
    \\    },
    \\    "provenance": {
    \\      "summary": "where did this text come from, and does the tree still contain it: relate's Ziv-Merhav cross-parse attributes each maximal verbatim phrase to one exemplar file on the codex shelf, then irregex re-reads that file's CURRENT bytes and re-finds the phrase exactly — a phrase is surfaced only if the live file still contains it (>=12-byte floor), never a stale line; requires `relate index --shelf` (or `gist codex build`)",
    \\      "args": [{"name": "text", "type": "string", "required": true, "description": "the pasted text to attribute"}],
    \\      "flags": [{"name": "--min-phrase", "type": "int", "default": 12, "description": "shortest matched phrase reported (bytes)"}, {"name": "-C/--context", "type": "int", "default": 2, "description": "context lines around each located phrase"}, {"name": "--json", "type": "bool", "default": false, "description": "NDJSON {text, occurrences, source, verified, line} rows"}]
    \\    }
    \\  },
    \\  "candidate_set": "exact matching first selects docs; family then lifts matching source lines into enclosing functions or bounded windows before compression, while --unit file keeps whole-doc candidates",
    \\  "scoring": "exact and compression signals stay in SEPARATE fields — no fused relevance number",
    \\  "corpus_policy": "context/family load the INDEX corpus under the roots and REQUIRE a scope (ROOT... or --all); provenance reads the corpus-wide codex shelf",
    \\  "output_stream": {"results": "stdout", "diagnostics": "stderr"},
    \\  "exit_codes": {"0": "verb ran (rows may be empty)", "2": "usage, parse, pattern, or missing-shelf error"}
    \\}
    \\
;

pub fn emit() void {
    corpus_mod.emitStdout(manifest);
}

test "irregex --schema is valid JSON naming all three composed verbs" {
    const t = std.testing;
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, manifest, .{});
    defer parsed.deinit();
    const verbs = parsed.value.object.get("verbs").?.object;
    for ([_][]const u8{ "context", "family", "provenance" }) |v| {
        try t.expect(verbs.contains(v));
    }
    try t.expectEqualStrings("irregex", parsed.value.object.get("tool").?.string);
}
