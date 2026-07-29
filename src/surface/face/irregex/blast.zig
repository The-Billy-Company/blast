//! irregex — the `blast` verb: a live symbol blast radius for editing agents.
//!
//!   irregex blast SYMBOL [--budget N] [--json] [ROOT...]
//!       "if I change SYMBOL, what else moves?" — computed from the corpus as it
//!       is RIGHT NOW (no precomputed graph, so a file mid-edit counts the moment
//!       it is saved). The `blast` kernel composes exact word-bounded search, the
//!       parser-free def/use classifier, function-region extraction, and
//!       compression kinship into one bounded report:
//!
//!         seed                 — the symbol's definition site(s) + a kind guess
//!         direct.dependents    — functions that reference it (def/use marked)
//!         direct.dependencies  — identifiers the seed's body leans on, resolved
//!         tangential.twins     — compression kin of the seed's file (co-edit risk)
//!         tangential.ripple    — second-hop callers of the dependents (hops=2)
//!         comments             — comments that MENTION it (stale-doc / TODO surface)
//!
//! Two evidence channels stay separate — exact (line/def/use) vs statistical
//! (twin distance) — never a single fused score (the compose-face covenant).
//! Scope defaults to the whole CWD corpus (the blast radius is corpus-wide by
//! nature); optional ROOT... narrows it. Results on stdout, diagnostics stderr.

const std = @import("std");
const corpus_mod = @import("../../../corpus/tree/corpus.zig");
const assay = @import("../../../assay/assay.zig");
const blast = @import("../../../kernel/compose/blast.zig");
const flags = @import("../../cli/flags.zig");
const emit = @import("../../cli/emit.zig");

const die = @import("../../cli/outcome.zig").die;
const oom = @import("../../cli/outcome.zig").oom;

const usage_msg = "usage: irregex blast SYMBOL [--budget N] [--json] [ROOT...]\n";

/// Approximate tokens a rendered row costs against `--budget` (≈4 bytes/token
/// plus a small per-row framing constant). A soft accountant, not a tokenizer:
/// its only job is to trim the lowest-priority tail before an agent's context
/// floods, and record how much it dropped in `stats.omitted`.
fn rowCost(bytes: usize) usize {
    return bytes / 4 + 4;
}

pub fn runBlast(gpa: std.mem.Allocator, io: std.Io, argv: []const []const u8) !void {
    var roots: std.ArrayList([]const u8) = .empty;
    defer roots.deinit(gpa);
    var symbol: ?[]const u8 = null;
    var json = false;
    var budget: ?usize = null;

    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "--json")) {
            json = true;
        } else if (std.mem.eql(u8, arg, "--budget")) {
            budget = flags.count(argv, &i, "--budget");
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1 and symbol != null) {
            die("irregex blast: unknown flag {s}\n", .{arg});
        } else if (symbol == null) {
            symbol = arg;
        } else {
            try roots.append(gpa, arg);
        }
    }

    const sym = symbol orelse die(usage_msg, .{});
    if (sym.len == 0) die("irregex blast: empty SYMBOL\n", .{});

    var run = assay.Run.open(gpa, io, json);
    const rr = try flags.rootsOf(gpa, roots.items);
    defer rr.deinit(gpa);
    var corpus = try corpus_mod.load(gpa, io, rr.items, .contiguous);
    defer corpus.deinit();
    const load_dur = run.lap();

    var report = try blast.compute(gpa, corpus.docs, corpus.paths, sym, .{});
    defer report.deinit();

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    var plan = Plan.init(budget);
    if (json) renderJson(&out, gpa, &report, corpus.paths, &plan) else renderHuman(&out, gpa, &report, corpus.paths, &plan);
    corpus_mod.emitStdout(out.items);

    const compute_dur = run.elapsed().ms();
    run.emit("blast: {s} [{s}] · {d} files ({d} with symbol) · {d} dep / {d} deps / {d} twins / {d} ripple / {d} comments · {d} omitted · load {d:.0} ms · compute {d:.0} ms\n", .{
        sym,                           @tagName(report.kind),
        report.stats.files_scanned,    report.stats.files_with_symbol,
        report.stats.dependents_total, report.stats.dependencies_total,
        report.stats.twins_total,      report.stats.ripple_total,
        report.stats.comments_total,   report.stats.omitted + plan.omitted,
        load_dur.ms(),                 compute_dur,
    }, .{
        .{ "verb", "s", "blast" },
        .{ "symbol", "s", sym },
        .{ "kind", "s", @tagName(report.kind) },
        .{ "files", "d", report.stats.files_scanned },
        .{ "files_with_symbol", "d", report.stats.files_with_symbol },
        .{ "dependents", "d", report.stats.dependents_total },
        .{ "dependencies", "d", report.stats.dependencies_total },
        .{ "twins", "d", report.stats.twins_total },
        .{ "ripple", "d", report.stats.ripple_total },
        .{ "comments", "d", report.stats.comments_total },
        .{ "omitted", "d", report.stats.omitted + plan.omitted },
        .{ "load_ms", "d:.0", load_dur.ms() },
        .{ "compute_ms", "d:.0", compute_dur },
    });
}

/// The budget accountant: greedily admits rows in priority order (dependents →
/// dependencies → comments → twins → ripple) until the token cap is hit, then
/// counts every skipped row into `omitted`. The seed, stats, and notes are never
/// trimmed — they are the report's spine. `null` budget admits everything the
/// kernel already capped.
const Plan = struct {
    cap: ?usize,
    used: usize = 0,
    omitted: usize = 0,

    fn init(budget: ?usize) Plan {
        return .{ .cap = budget };
    }

    /// Admit a row costing `cost` tokens, or decline (and tally it omitted) when
    /// the cap would be exceeded. A declined row never advances `used`, so a
    /// later cheaper row in the same section can still fit.
    fn admit(self: *Plan, cost: usize) bool {
        if (self.cap) |c| {
            if (self.used + cost > c) {
                self.omitted += 1;
                return false;
            }
        }
        self.used += cost;
        return true;
    }
};

fn renderHuman(out: *std.ArrayList(u8), gpa: std.mem.Allocator, r: *const blast.Report, paths: []const []const u8, plan: *Plan) void {
    out.print(gpa, "blast {s}  [{s}]\n", .{ r.symbol, @tagName(r.kind) }) catch oom();

    out.appendSlice(gpa, "seed:\n") catch oom();
    if (r.def.len == 0) out.appendSlice(gpa, "  (no definition site found)\n") catch oom();
    for (r.def) |s| out.print(gpa, "  {s}\n", .{emit.locator(gpa, paths[s.doc], s.line)}) catch oom();

    if (r.dependents.len > 0) {
        out.print(gpa, "direct dependents ({d} of {d}):\n", .{ r.dependents.len, r.stats.dependents_total }) catch oom();
        for (r.dependents) |d| {
            if (!plan.admit(rowCost(paths[d.doc].len + d.enclosing.len))) continue;
            const tag = if (d.defines) "def" else "use";
            if (d.enclosing.len > 0)
                out.print(gpa, "  {s}  in {s}  [{s}]\n", .{ emit.locator(gpa, paths[d.doc], d.line), d.enclosing, tag }) catch oom()
            else
                out.print(gpa, "  {s}  [{s}]\n", .{ emit.locator(gpa, paths[d.doc], d.line), tag }) catch oom();
        }
    }

    if (r.dependencies.len > 0) {
        out.print(gpa, "direct dependencies ({d}):\n", .{r.dependencies.len}) catch oom();
        for (r.dependencies) |d| {
            if (!plan.admit(rowCost(paths[d.doc].len + d.symbol.len))) continue;
            out.print(gpa, "  {s}  {s}\n", .{ d.symbol, emit.locator(gpa, paths[d.doc], d.line) }) catch oom();
        }
    }

    if (r.comments.len > 0) {
        out.print(gpa, "comments ({d} of {d}):\n", .{ r.comments.len, r.stats.comments_total }) catch oom();
        for (r.comments) |c| {
            if (!plan.admit(rowCost(paths[c.doc].len + c.text.len))) continue;
            out.print(gpa, "  {s}  {s}\n", .{ emit.locator(gpa, paths[c.doc], c.line), c.text }) catch oom();
        }
    }

    if (r.twins.len > 0) {
        out.print(gpa, "tangential twins ({d}):\n", .{r.twins.len}) catch oom();
        for (r.twins) |tw| {
            if (!plan.admit(rowCost(paths[tw.doc].len))) continue;
            out.print(gpa, "  {s}  dist={d:.2}\n", .{ emit.anchor(gpa, paths[tw.doc]), tw.distance }) catch oom();
        }
    }

    if (r.ripple.len > 0) {
        out.print(gpa, "tangential ripple ({d} of {d}):\n", .{ r.ripple.len, r.stats.ripple_total }) catch oom();
        for (r.ripple) |rp| {
            if (!plan.admit(rowCost(paths[rp.doc].len + rp.via.len))) continue;
            out.print(gpa, "  {s}  via {s} (hops=2)\n", .{ emit.anchor(gpa, paths[rp.doc]), rp.via }) catch oom();
        }
    }

    const total_omitted = r.stats.omitted + plan.omitted;
    if (total_omitted > 0) out.print(gpa, "omitted: {d}\n", .{total_omitted}) catch oom();
    for (r.notes) |n| out.print(gpa, "note: {s}\n", .{n}) catch oom();
}

fn renderJson(out: *std.ArrayList(u8), gpa: std.mem.Allocator, r: *const blast.Report, paths: []const []const u8, plan: *Plan) void {
    out.appendSlice(gpa, "{\"seed\":{\"symbol\":") catch oom();
    emit.jsonStr(out, gpa, r.symbol);
    out.print(gpa, ",\"kind\":\"{s}\",\"def\":[", .{@tagName(r.kind)}) catch oom();
    for (r.def, 0..) |s, k| {
        if (k != 0) out.append(gpa, ',') catch oom();
        out.appendSlice(gpa, "{\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[s.doc]);
        out.print(gpa, ",\"line\":{d}}}", .{s.line}) catch oom();
    }

    out.appendSlice(gpa, "]},\"direct\":{\"dependents\":[") catch oom();
    var first = true;
    for (r.dependents) |d| {
        if (!plan.admit(rowCost(paths[d.doc].len + d.enclosing.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[d.doc]);
        out.print(gpa, ",\"line\":{d},\"in\":", .{d.line}) catch oom();
        emit.jsonStr(out, gpa, d.enclosing);
        out.print(gpa, ",\"use\":\"{s}\"}}", .{if (d.defines) "def" else "use"}) catch oom();
    }
    out.appendSlice(gpa, "],\"dependencies\":[") catch oom();
    first = true;
    for (r.dependencies) |d| {
        if (!plan.admit(rowCost(paths[d.doc].len + d.symbol.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"symbol\":") catch oom();
        emit.jsonStr(out, gpa, d.symbol);
        out.appendSlice(gpa, ",\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[d.doc]);
        out.print(gpa, ",\"line\":{d}}}", .{d.line}) catch oom();
    }

    out.appendSlice(gpa, "]},\"tangential\":{\"twins\":[") catch oom();
    first = true;
    for (r.twins) |tw| {
        if (!plan.admit(rowCost(paths[tw.doc].len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[tw.doc]);
        out.print(gpa, ",\"distance\":{d:.4}}}", .{tw.distance}) catch oom();
    }
    out.appendSlice(gpa, "],\"ripple\":[") catch oom();
    first = true;
    for (r.ripple) |rp| {
        if (!plan.admit(rowCost(paths[rp.doc].len + rp.via.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[rp.doc]);
        out.appendSlice(gpa, ",\"via\":") catch oom();
        emit.jsonStr(out, gpa, rp.via);
        out.appendSlice(gpa, ",\"hops\":2}") catch oom();
    }

    out.appendSlice(gpa, "]},\"comments\":[") catch oom();
    first = true;
    for (r.comments) |c| {
        if (!plan.admit(rowCost(paths[c.doc].len + c.text.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        emit.jsonStr(out, gpa, paths[c.doc]);
        out.print(gpa, ",\"line\":{d},\"text\":", .{c.line}) catch oom();
        emit.jsonStr(out, gpa, c.text);
        out.append(gpa, '}') catch oom();
    }

    out.print(gpa, "],\"stats\":{{\"files\":{d},\"with_symbol\":{d},\"dependents\":{d},\"dependencies\":{d},\"twins\":{d},\"ripple\":{d},\"comments\":{d},\"omitted\":{d},\"short_name\":{}}},\"notes\":", .{
        r.stats.files_scanned,    r.stats.files_with_symbol,
        r.stats.dependents_total, r.stats.dependencies_total,
        r.stats.twins_total,      r.stats.ripple_total,
        r.stats.comments_total,   r.stats.omitted + plan.omitted,
        r.stats.short_name,
    }) catch oom();
    out.append(gpa, '[') catch oom();
    for (r.notes, 0..) |n, k| {
        if (k != 0) out.append(gpa, ',') catch oom();
        emit.jsonStr(out, gpa, n);
    }
    out.appendSlice(gpa, "]}\n") catch oom();
}

const t = std.testing;

// String-aware brace/bracket balance — the exact adverse check that catches a
// dropped closing `}` (e.g. an unclosed nested section object), the shape bug a
// hand-rolled JSON emitter is most prone to. Quotes and `\`-escapes are honored
// so a brace INSIDE a string value never miscounts.
fn balanced(s: []const u8) bool {
    var obj: i32 = 0;
    var arr: i32 = 0;
    var in_str = false;
    var esc = false;
    for (s) |c| {
        if (in_str) {
            if (esc) esc = false else if (c == '\\') esc = true else if (c == '"') in_str = false;
            continue;
        }
        switch (c) {
            '"' => in_str = true,
            '{' => obj += 1,
            '}' => obj -= 1,
            '[' => arr += 1,
            ']' => arr -= 1,
            else => {},
        }
        if (obj < 0 or arr < 0) return false;
    }
    return obj == 0 and arr == 0 and !in_str;
}

test "renderJson emits a balanced, single-object report" {
    const docs = [_][]const u8{
        "pub fn Target(x: u32) u32 {\n    return helper(x);\n}\nfn helper(v: u32) u32 {\n    return v + 1;\n}",
        "fn caller() u32 {\n    return Target(3);\n}",
    };
    const paths = [_][]const u8{ "a.zig", "b.zig" };
    var report = try blast.compute(t.allocator, &docs, &paths, "Target", .{});
    defer report.deinit();

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &report, &paths, &plan);

    try t.expect(balanced(out.items));
    try t.expectEqual(@as(u8, '{'), out.items[0]);
    // The report names every top-level section — a dropped section key is a
    // silent contract regression the agent consumer would trip on.
    for ([_][]const u8{ "\"seed\"", "\"direct\"", "\"tangential\"", "\"comments\"", "\"stats\"", "\"notes\"" }) |key| {
        try t.expect(std.mem.indexOf(u8, out.items, key) != null);
    }
}

test "Plan admits within budget, declines and tallies past it" {
    var p = Plan.init(10);
    try t.expect(p.admit(6)); // used 6
    try t.expect(!p.admit(6)); // 6+6 > 10 → declined, omitted=1
    try t.expect(p.admit(4)); // 6+4 = 10 → fits
    try t.expectEqual(@as(usize, 1), p.omitted);
    var unlimited = Plan.init(null);
    try t.expect(unlimited.admit(1_000_000)); // null cap never declines
    try t.expectEqual(@as(usize, 0), unlimited.omitted);
}
