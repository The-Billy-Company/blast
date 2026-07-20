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
const codex_face = @import("../gist/lifecycle/codex.zig");
const cli_args = @import("../../exec/cold/argv/args.zig");
const cento = @import("../../../corpus/index/codex/cento.zig");
const provenance = @import("../../../kernel/compose/provenance.zig");
const kinship = @import("../relate/kinship.zig");

const die = cli_args.die;
const oom = cli_args.oom;
const nowNs = cli_args.nowNs;
const ms = cli_args.ms;
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
            min_phrase = std.fmt.parseInt(usize, kinship.need(argv, &i, "--min-phrase needs a number\n"), 10) catch die("--min-phrase: bad number: {s}\n", .{argv[i]});
        } else if (std.mem.eql(u8, arg, "-C") or std.mem.eql(u8, arg, "--context")) {
            context_lines = std.fmt.parseInt(usize, kinship.need(argv, &i, "-C needs a number\n"), 10) catch die("-C: bad number: {s}\n", .{argv[i]});
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

    const t0 = nowNs(io);
    var shelf = codex_face.loadShelf(gpa, io, "`relate index --shelf` (or `gist codex build`)");
    defer shelf.deinit(gpa);

    var parsed = try cento.parse(&shelf.cx, gpa, query);
    defer parsed.deinit(gpa);
    const parsed_ns = nowNs(io);

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
            const pos = shelf.cx.posOf(ph.row) catch break :blk null;
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

    const stale = codex_face.shelfStaleCount(gpa, io, shelf.built_ns);
    if (stale > 0)
        std.debug.print("provenance: {d} file(s) changed since the shelf was built — `relate index --shelf` refreshes\n", .{stale});
    std.debug.print("provenance: {d} phrase(s) located · {d} drifted · {d} skipped (escape/<{d}B) · {d} files in shelf · load+parse {d:.0} ms\n", .{
        located, drifted, skipped, min_phrase, shelf.paths.len, ms(parsed_ns - t0),
    });
}

const Hit = struct { loc: provenance.Located, bytes: []const u8 };

/// One phrase row: located (path:line + context), or drift (`path` present but
/// current bytes can't confirm it, or `path` null when attribution failed).
fn emit(out: *std.ArrayList(u8), gpa: std.mem.Allocator, json: bool, phrase: []const u8, path: ?[]const u8, hit: ?Hit, occurrences: u32) void {
    if (json) {
        out.append(gpa, '{') catch oom();
        out.appendSlice(gpa, "\"text\":") catch oom();
        kinship.jsonStr(out, gpa, phrase);
        out.print(gpa, ",\"occurrences\":{d},\"source\":", .{occurrences}) catch oom();
        if (path) |p| kinship.jsonStr(out, gpa, p) else out.appendSlice(gpa, "null") catch oom();
        if (hit) |h| {
            out.print(gpa, ",\"verified\":true,\"line\":{d}", .{h.loc.line}) catch oom();
        } else {
            out.appendSlice(gpa, ",\"verified\":false,\"line\":null") catch oom();
        }
        out.appendSlice(gpa, "}\n") catch oom();
        return;
    }
    if (hit) |h| {
        out.print(gpa, "{s}:{d}\n", .{ path.?, h.loc.line }) catch oom();
        var lines = std.mem.splitScalar(u8, h.loc.context(h.bytes), '\n');
        while (lines.next()) |ln| out.print(gpa, "    {s}\n", .{ln}) catch oom();
    } else {
        out.print(gpa, "(drift) {s}  ", .{path orelse "(not in corpus)"}) catch oom();
        kinship.jsonStr(out, gpa, phrase);
        out.append(gpa, '\n') catch oom();
    }
}
