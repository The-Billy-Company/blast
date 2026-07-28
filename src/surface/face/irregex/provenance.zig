//! irregex — the `provenance` verb: quotation attribution, gist-verified.
//!
//!   irregex provenance TEXT [--min-phrase N] [-C N] [--json]
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
//! never points at a line the live tree no longer holds (ADR-367).
//!
//! Reads the corpus-wide shelf (`relate index --shelf` / `gist codex build`);
//! no scope needed. Results stdout, diagnostics stderr.

const std = @import("std");
const corpus_mod = @import("../../../corpus/tree/corpus.zig");
const shelf_mod = @import("../../../corpus/index/shelf/shelf.zig");
const outcome = @import("../../cli/outcome.zig");
const assay = @import("../../../assay/assay.zig");
const cento = @import("../../../kernel/codex/cento.zig");
const provenance = @import("../../../kernel/compose/provenance.zig");
const flags = @import("../../cli/flags.zig");
const emit_mod = @import("../../cli/emit.zig");

const die = @import("../../cli/outcome.zig").die;
const oom = @import("../../cli/outcome.zig").oom;
const Dir = std.Io.Dir;

/// Default phrase floor: a matched phrase shorter than this is trivially shared
/// (`the `, `();`) and names no real provenance — drop it from the report.
const default_min_phrase = 12;

const usage_msg = "usage: irregex provenance TEXT [--min-phrase N] [-C N] [--json]\n";

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
            die("irregex provenance: unknown flag {s}\n", .{arg});
        } else if (text == null) {
            text = arg;
        } else die(usage_msg, .{});
    }

    const query = text orelse die(usage_msg, .{});
    if (query.len == 0) die("irregex provenance: empty TEXT\n", .{});

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
        emit_mod.jsonStr(out, gpa, phrase);
        out.print(gpa, ",\"occurrences\":{d},\"source\":", .{occurrences}) catch oom();
        if (path) |p| emit_mod.jsonStr(out, gpa, p) else out.appendSlice(gpa, "null") catch oom();
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
