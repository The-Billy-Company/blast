//! irregex — the `context` verb: coverage packing inside the exact filter.
//!
//!   irregex context TEXT -e P [-e P...] [--match any|all] [-F] [-i]
//!                   [--top N] [--json] ROOT...
//!       the minimal non-redundant reading set among files that ACTUALLY match
//!       the intents. The `-e` patterns compile to a PatternSet (the match
//!       half); `candidates.select` narrows the corpus to the docs they admit
//!       (any = ≥1 pattern, all = every pattern); then greedy submodular
//!       coverage (the relate half) packs TEXT over a lexicon built from ONLY
//!       those docs — so a README that never matched can never be picked.
//!
//! Why compose instead of `gist -l | relate pack`: the hand-join throws the
//! match mask away between steps and pays whole-corpus coverage noise. Here the
//! mask rides each pick to output, and the sub-lexicon prices novelty inside
//! the matching set. Two scores stay separate: the patterns that admitted a
//! pick (exact) and its marginal_bits (compression) — never a fused number.
//!
//! Scope is mandatory (ROOT... or --all) so a composed query can't silently
//! sweep vendor/.etc. Results stdout, diagnostics stderr (ADR-367).

const std = @import("std");
const corpus_mod = @import("../../../corpus/tree/corpus.zig");
const cli_args = @import("../../exec/cold/argv/args.zig");
const assay = @import("../../../assay/assay.zig");
const candidates = @import("../../../kernel/compose/candidates.zig");
const context = @import("../../../kernel/compose/context.zig");
const patterns_mod = @import("../../../kernel/batch/patterns.zig");
const flags = @import("../../cli/flags.zig");
const emit = @import("../../cli/emit.zig");
const shared = @import("shared.zig");

const die = cli_args.die;
const oom = cli_args.oom;

const usage_msg = "usage: irregex context TEXT -e PATTERN [-e PATTERN...] [--match any|all] [-F] [-i] [--top N] [--json] {{ROOT... | --all}}\n";

pub fn runContext(gpa: std.mem.Allocator, io: std.Io, argv: []const []const u8) !void {
    var pats: std.ArrayList([]const u8) = .empty;
    defer pats.deinit(gpa);
    var roots: std.ArrayList([]const u8) = .empty;
    defer roots.deinit(gpa);
    var match: candidates.Match = .any;
    var c: shared.Common = .{ .top = 8 };

    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--regexp")) {
            try pats.append(gpa, flags.need(argv, &i, "-e needs a pattern\n"));
        } else if (std.mem.eql(u8, arg, "--match")) {
            match = std.meta.stringToEnum(candidates.Match, flags.need(argv, &i, "--match needs any|all\n")) orelse die("--match: any or all, not {s}\n", .{argv[i]});
        } else shared.commonArg(gpa, argv, &i, &c, &roots, "context");
    }

    const query = c.positional orelse die(usage_msg, .{});
    if (query.len == 0) die("irregex context: empty TEXT\n", .{});
    if (pats.items.len == 0) die("irregex context: at least one -e PATTERN is required\n", .{});
    if (roots.items.len == 0 and !c.all) die("irregex context: scope is mandatory — pass ROOT... or --all\n", .{});

    var set = shared.compileSet(gpa, pats.items, c.fixed, c.ignore_case) catch |e| shared.dieCompile(e);
    defer set.deinit(gpa);

    const run = assay.Run.open(gpa, io, c.json);
    const rr = try flags.rootsOf(gpa, roots.items);
    defer rr.deinit(gpa);
    var corpus = try corpus_mod.load(gpa, io, rr.items);
    defer corpus.deinit();
    const load_dur = run.elapsed();
    const pack_span = assay.Span.open(io);

    var cset = candidates.select(gpa, corpus.docs, &set, match) catch |e| shared.dieCompile(e);
    defer cset.deinit();

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    if (cset.count() == 0) {
        corpus_mod.emitStdout("");
        const dur = run.elapsed().ms();
        run.emit("context: {d} files · 0 candidates for {d} pattern(s) [{s}] · {d:.0} ms\n", .{ corpus.docs.len, pats.items.len, @tagName(match), dur }, .{
            .{ "verb", "s", "context" },
            .{ "files", "d", corpus.docs.len },
            .{ "candidates", "d", @as(usize, 0) },
            .{ "patterns", "d", pats.items.len },
            .{ "match", "s", @tagName(match) },
            .{ "ms", "d:.0", dur },
        });
        return;
    }

    var packed_result = try context.pack(gpa, corpus.docs, corpus.paths, &cset, query, c.top);
    defer packed_result.deinit();

    for (packed_result.picks, 1..) |p, rank| {
        var labels = shared.matchedLabels(gpa, pats.items, p.mask);
        defer labels.deinit();
        if (c.json) {
            out.print(gpa, "{{\"rank\":{d},\"path\":", .{rank}) catch oom();
            emit.jsonStr(&out, gpa, corpus.paths[p.doc]);
            out.print(gpa, ",\"marginal_bits\":{d:.1},\"coverage\":{d:.4},\"patterns\":", .{ p.marginal_bits, p.coverage }) catch oom();
            shared.jsonStrArray(&out, gpa, labels.items);
            out.appendSlice(gpa, "}\n") catch oom();
        } else {
            out.print(gpa, "+{d:.1} bits  {d:.4}  {s}  [{s}]\n", .{ p.marginal_bits, p.coverage, corpus.paths[p.doc], labels.joined }) catch oom();
        }
    }
    corpus_mod.emitStdout(out.items);

    const covered_pct = if (packed_result.picks.len > 0 and packed_result.total_bits > 0.0)
        packed_result.picks[packed_result.picks.len - 1].coverage * 100.0
    else
        0.0;
    const pack_dur = pack_span.read(io).ms();
    run.emit("context: {d} files · {d} candidate(s) [{s}] · {d} pick(s) cover {d:.1}% of {d:.1} priced bits · {d} foreign chunk(s) · load {d:.0} ms · pack {d:.0} ms\n", .{
        corpus.docs.len,
        packed_result.candidates,
        @tagName(match),
        packed_result.picks.len,
        covered_pct,
        packed_result.total_bits,
        packed_result.foreign,
        load_dur.ms(),
        pack_dur,
    }, .{
        .{ "verb", "s", "context" },
        .{ "files", "d", corpus.docs.len },
        .{ "candidates", "d", packed_result.candidates },
        .{ "match", "s", @tagName(match) },
        .{ "picks", "d", packed_result.picks.len },
        .{ "coverage_pct", "d:.1", covered_pct },
        .{ "priced_bits", "d:.1", packed_result.total_bits },
        .{ "foreign", "d", packed_result.foreign },
        .{ "load_ms", "d:.0", load_dur.ms() },
        .{ "pack_ms", "d:.0", pack_dur },
    });
}
