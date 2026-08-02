//! blast — the `provenance` verb: quotation attribution, gist-verified.
//!
//!   blast provenance TEXT [--min-phrase N] [-C N] [--json]
//!       where did this text come from, and does the tree still contain it?
//!       `relate quote`'s Ziv–Merhav cross-parse rewrites TEXT as maximal
//!       verbatim phrases from the codex shelf and attributes each to one
//!       exemplar file — but the shelf is a build-time snapshot. This verb then
//!       re-reads that file's CURRENT bytes and re-finds the phrase exactly (the
//!       MATCH half, `compose/provenance.zig`), so it reports a live line +
//!       context, never a stale row.
//!
//! The invariant: a phrase is surfaced ONLY if its exemplar file currently
//! contains it (default ≥12-byte floor drops trivial phrases). A phrase the
//! current bytes cannot confirm is reported as drift, never located — provenance
//! never points at a line the live tree no longer holds.
//!
//! Reads the corpus-wide shelf (`relate index --shelf` / `gist codex build`);
//! no scope needed. Results stdout, diagnostics stderr.

const std = @import("std");
const corpus_mod = @import("irregex").corpus;
const shelf_mod = @import("irregex").codex.shelf;
const outcome = @import("irregex").inner.cli.outcome;
const assay = @import("irregex").assay;
const cento = @import("relate").codex.cento;
const provenance = @import("relate").compose.provenance;
const flags = @import("relate").cli.flags;
const emit_mod = @import("irregex").inner.cli.emit;
const jsonsafe = @import("jsonsafe.zig");

const die = @import("irregex").inner.cli.outcome.die;
const oom = @import("irregex").inner.cli.outcome.oom;
const Dir = std.Io.Dir;

/// Default phrase floor: a matched phrase shorter than this is trivially shared
/// (`the `, `();`) and names no real provenance — drop it from the report.
const default_min_phrase = 12;

const usage_msg = "usage: blast provenance TEXT [--min-phrase N] [-C N] [--json]\n";

pub fn runProvenance(gpa: std.mem.Allocator, io: std.Io, argv: []const []const u8) !void {
    var text: ?[]const u8 = null;
    var min_phrase: usize = default_min_phrase;
    var context_lines: usize = 2;
    var json = false;

    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "--min-phrase")) {
            min_phrase = flags.count(argv, &i, "--min-phrase");
        } else if (std.mem.eql(u8, arg, "-C") or std.mem.eql(u8, arg, "--context")) {
            context_lines = flags.count(argv, &i, "-C");
        } else if (std.mem.eql(u8, arg, "--json")) {
            json = true;
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1 and text != null) {
            die("blast provenance: unknown flag {s}\n", .{arg});
        } else if (text == null) {
            text = arg;
        } else die(usage_msg, .{});
    }

    const query = text orelse die(usage_msg, .{});
    if (query.len == 0) die("blast provenance: empty TEXT\n", .{});

    const run = assay.Run.open(gpa, io, json);
    var shelf = shelf_mod.open(gpa, io) catch |e| outcome.needArtifact(
        e,
        "codex shelf",
        shelf_mod.shelfFile(),
        "`relate index --shelf` (or `gist codex build`)",
    );
    defer shelf.deinit(gpa);

    var parsed = try cento.parse(&shelf.cx, gpa, query);
    defer parsed.deinit(gpa);
    const parse_dur = run.elapsed();

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    var located: usize = 0;
    var drifted: usize = 0;
    var skipped: usize = 0;
    for (parsed.phrases) |ph| {
        // Escapes (unseen bytes) and below-floor phrases name no provenance.
        if (ph.width == 0 or ph.len < min_phrase) {
            skipped += 1;
            continue;
        }
        const phrase = query[ph.pos .. ph.pos + ph.len];
        const path: ?[]const u8 = blk: {
            const pos = switch (shelf.cx.posOf(ph.row)) {
                .declined => break :blk null,
                .got => |p| p,
            };
            break :blk shelf.paths[shelf.docOf(pos)];
        };
        // Re-read the exemplar's CURRENT bytes and re-find the phrase exactly.
        const src = path orelse {
            drifted += 1;
            emit(&out, gpa, json, phrase, null, null, ph.width);
            continue;
        };
        const bytes = Dir.cwd().readFileAlloc(io, src, gpa, .unlimited) catch {
            drifted += 1;
            emit(&out, gpa, json, phrase, src, null, ph.width);
            continue;
        };
        defer gpa.free(bytes);
        if (provenance.verify(bytes, phrase, context_lines)) |loc| {
            located += 1;
            emit(&out, gpa, json, phrase, src, .{ .loc = loc, .bytes = bytes }, ph.width);
        } else {
            drifted += 1;
            emit(&out, gpa, json, phrase, src, null, ph.width);
        }
    }
    corpus_mod.emitStdout(out.items);

    const stale = shelf_mod.staleCount(gpa, io, shelf.built_ns);
    if (stale > 0)
        assay.diag("provenance: {d} file(s) changed since the shelf was built — `relate index --shelf` refreshes\n", .{stale});
    run.emit("provenance: {d} phrase(s) located · {d} drifted · {d} skipped (escape/<{d}B) · {d} files in shelf · load+parse {d:.0} ms\n", .{
        located, drifted, skipped, min_phrase, shelf.paths.len, parse_dur.ms(),
    }, .{
        .{ "verb", "s", "provenance" },
        .{ "located", "d", located },
        .{ "drifted", "d", drifted },
        .{ "skipped", "d", skipped },
        .{ "min_phrase", "d", min_phrase },
        .{ "shelf_files", "d", shelf.paths.len },
        .{ "load_parse_ms", "d:.0", parse_dur.ms() },
    });
}

const Hit = struct { loc: provenance.Located, bytes: []const u8 };

/// One phrase row: located (path:line + context), or drift (`path` present but
/// current bytes can't confirm it, or `path` null when attribution failed).
fn emit(out: *std.ArrayList(u8), gpa: std.mem.Allocator, json: bool, phrase: []const u8, path: ?[]const u8, hit: ?Hit, occurrences: u32) void {
    if (json) {
        out.append(gpa, '{') catch oom();
        out.appendSlice(gpa, "\"text\":") catch oom();
        jsonsafe.str(out, gpa, phrase);
        out.print(gpa, ",\"occurrences\":{d},\"source\":", .{occurrences}) catch oom();
        if (path) |p| jsonsafe.str(out, gpa, p) else out.appendSlice(gpa, "null") catch oom();
        if (hit) |h| {
            out.print(gpa, ",\"verified\":true,\"line\":{d}", .{h.loc.line}) catch oom();
        } else {
            out.appendSlice(gpa, ",\"verified\":false,\"line\":null") catch oom();
        }
        out.appendSlice(gpa, "}\n") catch oom();
        return;
    }
    if (hit) |h| {
        out.print(gpa, "{s}\n", .{emit_mod.locator(gpa, path.?, h.loc.line)}) catch oom();
        var lines = std.mem.splitScalar(u8, h.loc.context(h.bytes), '\n');
        while (lines.next()) |ln| out.print(gpa, "    {s}\n", .{ln}) catch oom();
    } else {
        // A drift row names the file the phrase USED to be in, and the whole
        // point of reading one is to go look — but only when there is a file.
        out.print(gpa, "(drift) {s}  ", .{if (path) |p| emit_mod.anchor(gpa, p) else "(not in corpus)"}) catch oom();
        emit_mod.jsonStr(out, gpa, phrase);
        out.append(gpa, '\n') catch oom();
    }
}

// ── tests ──────────────────────────────────────────────────────────────────
//
// `runProvenance` needs a live codex shelf (a build-time artifact) and the
// filesystem, so it is out of a unit test's reach. `emit` is not: it is the
// verb's whole rendering contract — the three row shapes (located / drift /
// unattributed) and the NDJSON escaping every consuming tool parses — and it
// takes plain values. These drive it directly, and hold the JSON output to a
// REAL parser rather than eyeballing the bytes, because a dropped quote or a
// raw control byte in a phrase or path is exactly the failure a hand-rolled
// emitter ships and a brace-count never catches. `verify` (relate) mints the
// `Located` so the located row's line is the one the kernel would actually
// report, not a hand-picked integer.

const t = std.testing;

/// Split an NDJSON buffer on newlines and parse each non-empty line as one JSON
/// object, or fail — the parser is the oracle for "is this even valid JSON?".
fn expectNdjson(buf: []const u8, comptime want_lines: usize) ![want_lines]std.json.Parsed(std.json.Value) {
    var out: [want_lines]std.json.Parsed(std.json.Value) = undefined;
    var it = std.mem.tokenizeScalar(u8, buf, '\n');
    var n: usize = 0;
    while (it.next()) |line| : (n += 1) {
        try t.expect(n < want_lines);
        out[n] = try std.json.parseFromSlice(std.json.Value, t.allocator, line, .{});
        try t.expect(out[n].value == .object);
    }
    try t.expectEqual(want_lines, n);
    return out;
}

test "provenance emit: located, drift, and unattributed rows are valid NDJSON" {
    const bytes = "alpha line\nbeta has the PHRASE right here\ngamma line\n";
    const loc = provenance.verify(bytes, "PHRASE", 2).?; // line 2

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    emit(&out, t.allocator, true, "PHRASE", "src.zig", .{ .loc = loc, .bytes = bytes }, 3);
    emit(&out, t.allocator, true, "orphan phrase", "gone.zig", null, 1); // drift: path but no confirm
    emit(&out, t.allocator, true, "no home", null, null, 5); // unattributed

    var rows = try expectNdjson(out.items, 3);
    defer for (&rows) |*r| r.deinit();

    const located = rows[0].value.object;
    try t.expectEqualStrings("PHRASE", located.get("text").?.string);
    try t.expectEqual(@as(i64, 3), located.get("occurrences").?.integer);
    try t.expectEqualStrings("src.zig", located.get("source").?.string);
    try t.expectEqual(true, located.get("verified").?.bool);
    try t.expectEqual(@as(i64, 2), located.get("line").?.integer);

    const drift = rows[1].value.object;
    try t.expectEqualStrings("gone.zig", drift.get("source").?.string);
    try t.expectEqual(false, drift.get("verified").?.bool);
    try t.expectEqual(std.json.Value.null, drift.get("line").?);

    const orphan = rows[2].value.object;
    try t.expectEqual(std.json.Value.null, orphan.get("source").?);
    try t.expectEqual(false, orphan.get("verified").?.bool);
}

test "provenance emit: an adversarial phrase and path survive JSON losslessly" {
    // Every byte the escaper must handle, in BOTH the phrase (user TEXT) and the
    // path (a filename) — decoded back through a real parser, they must equal the
    // input exactly. A missed escape corrupts an agent's provenance answer.
    const phrase = "quote\" back\\ nl\n tab\t ctl\x01\x1f del\x7f uni\u{00e9}\u{1F980}";
    const path = "dir/od\"d\\name\n.zig";

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    emit(&out, t.allocator, true, phrase, path, null, 2);

    var rows = try expectNdjson(out.items, 1);
    defer for (&rows) |*r| r.deinit();
    try t.expectEqualStrings(phrase, rows[0].value.object.get("text").?.string);
    try t.expectEqualStrings(path, rows[0].value.object.get("source").?.string);
}

test "provenance emit: the human drift row anchors the file and quotes the phrase" {
    // `locator`/`anchor` allocate from `gpa` and are never freed (a short-lived
    // process's contract) — an arena absorbs that so the leak detector stays
    // quiet while the rendering is still the production path.
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const ga = arena.allocator();

    var out: std.ArrayList(u8) = .empty;
    emit(&out, ga, false, "a quoted phrase", "path/to/file.zig", null, 1);
    emit(&out, ga, false, "orphaned", null, null, 1);
    const bytes = "one\ntwo THREE four\nfive\n";
    const loc = provenance.verify(bytes, "THREE", 0).?;
    emit(&out, ga, false, "THREE", "hit.zig", .{ .loc = loc, .bytes = bytes }, 1);

    try t.expect(std.mem.indexOf(u8, out.items, "(drift)") != null);
    try t.expect(std.mem.indexOf(u8, out.items, "file.zig") != null);
    try t.expect(std.mem.indexOf(u8, out.items, "\"a quoted phrase\"") != null);
    try t.expect(std.mem.indexOf(u8, out.items, "(not in corpus)") != null);
    // The located row indents its own context line under the locator.
    try t.expect(std.mem.indexOf(u8, out.items, "    two THREE four") != null);
}
