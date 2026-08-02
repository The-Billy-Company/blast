//! blast — the `blast` verb: a live symbol blast radius for editing agents.
//!
//!   blast blast SYMBOL [--budget N] [--json] [ROOT...]
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
const corpus_mod = @import("irregex").corpus;
const assay = @import("irregex").assay;
const blast = @import("relate").compose.blast;
const flags = @import("relate").cli.flags;
const emit = @import("irregex").inner.cli.emit;
const jsonsafe = @import("jsonsafe.zig");

const die = @import("irregex").inner.cli.outcome.die;
const oom = @import("irregex").inner.cli.outcome.oom;

const usage_msg = "usage: blast blast SYMBOL [--budget N] [--json] [ROOT...]\n";

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
            die("blast blast: unknown flag {s}\n", .{arg});
        } else if (symbol == null) {
            symbol = arg;
        } else {
            try roots.append(gpa, arg);
        }
    }

    const sym = symbol orelse die(usage_msg, .{});
    if (sym.len == 0) die("blast blast: empty SYMBOL\n", .{});

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
    jsonsafe.str(out, gpa, r.symbol);
    out.print(gpa, ",\"kind\":\"{s}\",\"def\":[", .{@tagName(r.kind)}) catch oom();
    for (r.def, 0..) |s, k| {
        if (k != 0) out.append(gpa, ',') catch oom();
        out.appendSlice(gpa, "{\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[s.doc]);
        out.print(gpa, ",\"line\":{d}}}", .{s.line}) catch oom();
    }

    out.appendSlice(gpa, "]},\"direct\":{\"dependents\":[") catch oom();
    var first = true;
    for (r.dependents) |d| {
        if (!plan.admit(rowCost(paths[d.doc].len + d.enclosing.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[d.doc]);
        out.print(gpa, ",\"line\":{d},\"in\":", .{d.line}) catch oom();
        jsonsafe.str(out, gpa, d.enclosing);
        out.print(gpa, ",\"use\":\"{s}\"}}", .{if (d.defines) "def" else "use"}) catch oom();
    }
    out.appendSlice(gpa, "],\"dependencies\":[") catch oom();
    first = true;
    for (r.dependencies) |d| {
        if (!plan.admit(rowCost(paths[d.doc].len + d.symbol.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"symbol\":") catch oom();
        jsonsafe.str(out, gpa, d.symbol);
        out.appendSlice(gpa, ",\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[d.doc]);
        out.print(gpa, ",\"line\":{d}}}", .{d.line}) catch oom();
    }

    out.appendSlice(gpa, "]},\"tangential\":{\"twins\":[") catch oom();
    first = true;
    for (r.twins) |tw| {
        if (!plan.admit(rowCost(paths[tw.doc].len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[tw.doc]);
        out.print(gpa, ",\"distance\":{d:.4}}}", .{tw.distance}) catch oom();
    }
    out.appendSlice(gpa, "],\"ripple\":[") catch oom();
    first = true;
    for (r.ripple) |rp| {
        if (!plan.admit(rowCost(paths[rp.doc].len + rp.via.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[rp.doc]);
        out.appendSlice(gpa, ",\"via\":") catch oom();
        jsonsafe.str(out, gpa, rp.via);
        out.appendSlice(gpa, ",\"hops\":2}") catch oom();
    }

    out.appendSlice(gpa, "]},\"comments\":[") catch oom();
    first = true;
    for (r.comments) |c| {
        if (!plan.admit(rowCost(paths[c.doc].len + c.text.len))) continue;
        if (!first) out.append(gpa, ',') catch oom();
        first = false;
        out.appendSlice(gpa, "{\"path\":") catch oom();
        jsonsafe.str(out, gpa, paths[c.doc]);
        out.print(gpa, ",\"line\":{d},\"text\":", .{c.line}) catch oom();
        jsonsafe.str(out, gpa, c.text);
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
        jsonsafe.str(out, gpa, n);
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

// ── adversarial additions ──────────────────────────────────────────────────
//
// The suite above proves the happy shape. These prove the accountant's edges
// (budget 0 / exact-fit / huge, and that omitted counts every trimmed row) and
// that the hand-rolled JSON survives a REAL parser fed adversarial bytes — a
// far stronger claim than `balanced`, which only counts braces. `compute` is
// driven end-to-end with corpus edges (zero-occurrence, every-file, empty)
// rather than a constructed `Report`, so the render is held to what the kernel
// actually emits.

const docs_target = [_][]const u8{
    "pub fn Target(x: u32) u32 {\n    return helper(x);\n}\nfn helper(v: u32) u32 {\n    return v + 1;\n}",
    "fn caller() u32 {\n    return Target(3);\n}",
};
const paths_ab = [_][]const u8{ "a.zig", "b.zig" };

/// Parse `bytes` as one JSON object or fail the test — the parser is the
/// oracle: it rejects a raw control byte, an unescaped quote, a lone backslash,
/// or invalid UTF-8, none of which `balanced` can see.
fn parseObject(bytes: []const u8) !std.json.Parsed(std.json.Value) {
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
    errdefer parsed.deinit();
    try t.expect(parsed.value == .object);
    return parsed;
}

test "renderJson: a path full of JSON metacharacters round-trips losslessly through a real parser" {
    // Every byte JSON must escape, plus a raw control that must NOT be escaped
    // (DEL 0x7f ≥ 0x20), plus multi-byte UTF-8 that must pass through verbatim —
    // in a PATH, the field an editing agent's tool consumes. `balanced` passes
    // this even when broken; `std.json` is the discipline that does not.
    const nasty = "a\"b\\c\nd\te\x01\x1ff\x7f\u{00e9}\u{1F980}.zig";
    const paths = [_][]const u8{ nasty, "b.zig" };
    var report = try blast.compute(t.allocator, &docs_target, &paths, "Target", .{});
    defer report.deinit();

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &report, &paths, &plan);

    try t.expect(balanced(out.items));
    var parsed = try parseObject(out.items);
    defer parsed.deinit();
    // Target is defined in doc 0, so its seed def path is the nasty one, and the
    // decoded string must equal the original bytes exactly — escaping lossless.
    const def = parsed.value.object.get("seed").?.object.get("def").?.array;
    try t.expect(def.items.len >= 1);
    try t.expectEqualStrings(nasty, def.items[0].object.get("path").?.string);
}

test "renderJson: budget 0 trims every optional row into omitted; null trims none" {
    var full = try blast.compute(t.allocator, &docs_target, &paths_ab, "Target", .{});
    defer full.deinit();

    // null budget: the caller (b.zig) is a dependent and nothing is trimmed.
    var out_full: std.ArrayList(u8) = .empty;
    defer out_full.deinit(t.allocator);
    var plan_full = Plan.init(null);
    renderJson(&out_full, t.allocator, &full, &paths_ab, &plan_full);
    var pf = try parseObject(out_full.items);
    defer pf.deinit();
    const deps_full = pf.value.object.get("direct").?.object.get("dependents").?.array.items.len;
    try t.expect(deps_full >= 1);
    try t.expectEqual(@as(usize, 0), plan_full.omitted);

    // budget 0: every positive-cost row declines, so dependents empties and the
    // rendered `omitted` accounts for at least the dependents the full run kept.
    var out_zero: std.ArrayList(u8) = .empty;
    defer out_zero.deinit(t.allocator);
    var plan_zero = Plan.init(0);
    renderJson(&out_zero, t.allocator, &full, &paths_ab, &plan_zero);
    var pz = try parseObject(out_zero.items);
    defer pz.deinit();
    try t.expectEqual(@as(usize, 0), pz.value.object.get("direct").?.object.get("dependents").?.array.items.len);
    const omitted = pz.value.object.get("stats").?.object.get("omitted").?.integer;
    try t.expect(omitted >= @as(i64, @intCast(deps_full)));
    // The seed is spine, never trimmed — a budget of 0 still names the symbol.
    try t.expectEqualStrings("Target", pz.value.object.get("seed").?.object.get("symbol").?.string);
}

test "Plan: budget boundary matrix — 0, exact-fit, and huge" {
    var zero = Plan.init(0);
    try t.expect(!zero.admit(1)); // any positive cost declines at 0
    try t.expect(zero.admit(0)); // a free row still fits
    try t.expectEqual(@as(usize, 1), zero.omitted);

    var exact = Plan.init(8);
    try t.expect(exact.admit(5));
    try t.expect(exact.admit(3)); // 5+3 == 8, the boundary admits
    try t.expect(!exact.admit(1)); // one past the cap declines
    try t.expectEqual(@as(usize, 1), exact.omitted);

    var huge = Plan.init(std.math.maxInt(usize));
    try t.expect(huge.admit(std.math.maxInt(usize) - 1));
    try t.expectEqual(@as(usize, 0), huge.omitted);
}

test "rowCost is monotonic non-decreasing in byte size" {
    var prev: usize = 0;
    var n: usize = 0;
    while (n <= 4096) : (n += 1) {
        const c = rowCost(n);
        try t.expect(c >= prev);
        prev = c;
    }
    try t.expect(rowCost(0) >= 4); // the per-row framing floor is never zero
}

test "compute+renderJson: a zero-occurrence symbol is an empty but valid report" {
    const docs = [_][]const u8{ "fn unrelated() void {}", "const x = 1;" };
    const paths = [_][]const u8{ "x.zig", "y.zig" };
    var report = try blast.compute(t.allocator, &docs, &paths, "NoSuchSymbol", .{});
    defer report.deinit();
    try t.expectEqual(@as(usize, 0), report.stats.files_with_symbol);
    try t.expectEqual(@as(usize, 0), report.def.len);
    try t.expectEqual(@as(usize, 0), report.dependents.len);

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &report, &paths, &plan);
    var parsed = try parseObject(out.items);
    defer parsed.deinit();
    try t.expectEqual(@as(usize, 0), parsed.value.object.get("seed").?.object.get("def").?.array.items.len);
}

test "compute+renderJson: a symbol in every file stays within the kernel's caps" {
    // 60 files all referencing `Widget`, past the default 40-dependent cap, so
    // the kernel must bound the report rather than flood — and the JSON stays
    // well-formed at the cap boundary.
    var docs: std.ArrayList([]const u8) = .empty;
    defer docs.deinit(t.allocator);
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(t.allocator);
    var names: std.ArrayList([]u8) = .empty;
    defer {
        for (names.items) |n| t.allocator.free(n);
        names.deinit(t.allocator);
    }
    try docs.append(t.allocator, "pub fn Widget() void {}");
    try paths.append(t.allocator, "widget.zig");
    for (0..60) |k| {
        try docs.append(t.allocator, "fn use() void { Widget(); }");
        const p = try std.fmt.allocPrint(t.allocator, "caller_{d}.zig", .{k});
        try names.append(t.allocator, p);
        try paths.append(t.allocator, p);
    }
    var report = try blast.compute(t.allocator, docs.items, paths.items, "Widget", .{});
    defer report.deinit();
    try t.expect(report.dependents.len <= 40); // the Options.max_dependents cap holds
    try t.expect(report.stats.files_with_symbol >= 60);

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &report, paths.items, &plan);
    var parsed = try parseObject(out.items);
    defer parsed.deinit();
    try t.expect(parsed.value.object.get("direct").?.object.get("dependents").?.array.items.len <= 40);
}

test "renderJson: an invalid-UTF-8 path still yields valid, parseable JSON" {
    // Regression for the real gap this suite surfaced: a Linux filename is
    // arbitrary bytes, and handed raw to the UTF-8-assuming escaper it produced
    // a document a conformant parser rejected outright (std.json SyntaxError).
    // The caller-side gate (`jsonsafe`) now guarantees `--json` is always valid.
    const paths = [_][]const u8{ "a\xffb.zig", "b.zig" };
    var report = try blast.compute(t.allocator, &docs_target, &paths, "Target", .{});
    defer report.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &report, &paths, &plan);

    try t.expect(std.unicode.utf8ValidateSlice(out.items));
    var parsed = try parseObject(out.items); // would SyntaxError before the fix
    defer parsed.deinit();
    const def = parsed.value.object.get("seed").?.object.get("def").?.array;
    try t.expect(def.items.len >= 1);
    // The bad byte became U+FFFD; the surrounding bytes are preserved.
    const p0 = def.items[0].object.get("path").?.string;
    try t.expect(std.mem.startsWith(u8, p0, "a"));
    try t.expect(std.mem.endsWith(u8, p0, "b.zig"));
    try t.expect(std.mem.indexOf(u8, p0, "\u{FFFD}") != null);
}

test "compute: an empty corpus and a single doc do not crash" {
    const empty_docs = [_][]const u8{};
    const empty_paths = [_][]const u8{};
    var r0 = try blast.compute(t.allocator, &empty_docs, &empty_paths, "Anything", .{});
    r0.deinit();

    const one_doc = [_][]const u8{"pub fn Solo() void {}"};
    const one_path = [_][]const u8{"solo.zig"};
    var r1 = try blast.compute(t.allocator, &one_doc, &one_path, "Solo", .{});
    defer r1.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    var plan = Plan.init(null);
    renderJson(&out, t.allocator, &r1, &one_path, &plan);
    var parsed = try parseObject(out.items);
    defer parsed.deinit();
    try t.expectEqualStrings("Solo", parsed.value.object.get("seed").?.object.get("symbol").?.string);
}
