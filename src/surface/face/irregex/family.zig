//! irregex — the `family` verb: fork families inside the exact filter.
//!
//!   irregex family PATTERN [--unit function|match|file]
//!                  [--max-structure-distance T | --max-distance T | --echo-min E]
//!                  [-C N] [--only family|distinct|all] [--brief]
//!                  [-F] [-i] [--top N] [--json] ROOT...
//!       exact hits become comparison-sized functions or match windows before
//!       kinship runs. Families and genuinely distinct regions both surface.
//!
//! Why compose instead of `gist -l | relate clusters`: clusters over the whole
//! corpus can't scope to a symbol, and the hand-join re-derives membership.
//! Here the exact selector bounds the graph, so a family is by construction all
//! files that matched AND are kin. Scope is mandatory (ROOT... or --all).
//! Results stdout, diagnostics stderr (ADR-367).

const std = @import("std");
const corpus_mod = @import("../../../corpus/tree/corpus.zig");
const cli_args = @import("../../exec/cold/argv/args.zig");
const family_mod = @import("../../../kernel/compose/family.zig");
const regions = @import("../../../kernel/compose/regions.zig");
const flags = @import("../../cli/flags.zig");
const emit = @import("../../cli/emit.zig");
const shared = @import("shared.zig");

const die = cli_args.die;
const oom = cli_args.oom;
const nowNs = cli_args.nowNs;
const ms = cli_args.ms;

const Only = enum { all, family, distinct };
const usage_msg = "usage: irregex family PATTERN [--unit function|match|file] [--max-structure-distance T | --max-distance T | --echo-min E] [-C N] [--min-size N] [--only family|distinct|all] [--brief] [-F] [-i] [--top N] [--json] {{ROOT... | --all}}\n";

pub fn runFamily(gpa: std.mem.Allocator, io: std.Io, argv: []const []const u8) !void {
    var roots: std.ArrayList([]const u8) = .empty;
    defer roots.deinit(gpa);
    var mode: ?family_mod.Mode = null;
    var mode_set = false;
    var unit: regions.Unit = .function;
    var context: usize = 3;
    var min_size: usize = 2;
    var only: Only = .all;
    var brief = false;
    var c: shared.Common = .{ .top = 50 };

    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "--max-distance")) {
            if (mode_set) die("irregex family: --max-distance and --echo-min are mutually exclusive\n", .{});
            mode = .{ .dup = flags.unitFloat(flags.need(argv, &i, "--max-distance needs a number in [0,1]\n"), "--max-distance") };
            mode_set = true;
        } else if (std.mem.eql(u8, arg, "--max-structure-distance")) {
            if (mode_set) die("irregex family: similarity channel flags are mutually exclusive\n", .{});
            mode = .{ .structure = flags.unitFloat(flags.need(argv, &i, "--max-structure-distance needs a number in [0,1]\n"), "--max-structure-distance") };
            mode_set = true;
        } else if (std.mem.eql(u8, arg, "--echo-min") or std.mem.eql(u8, arg, "--min-echo")) {
            if (mode_set) die("irregex family: --max-distance and --echo-min are mutually exclusive\n", .{});
            mode = .{ .echo = flags.unitFloat(flags.need(argv, &i, "--echo-min needs a number in [0,1]\n"), "--echo-min") };
            mode_set = true;
        } else if (std.mem.eql(u8, arg, "--unit")) {
            const value = flags.need(argv, &i, "--unit needs function, match, or file\n");
            unit = if (std.mem.eql(u8, value, "function"))
                .function
            else if (std.mem.eql(u8, value, "match"))
                .match
            else if (std.mem.eql(u8, value, "file"))
                .file
            else
                die("--unit: expected function, match, or file; got {s}\n", .{value});
        } else if (std.mem.eql(u8, arg, "-C") or std.mem.eql(u8, arg, "--context")) {
            context = flags.count(argv, &i, "--context");
        } else if (std.mem.eql(u8, arg, "--min-size")) {
            min_size = flags.minSize(argv, &i);
        } else if (std.mem.eql(u8, arg, "--only")) {
            const value = flags.need(argv, &i, "--only needs family, distinct, or all\n");
            only = if (std.mem.eql(u8, value, "family"))
                .family
            else if (std.mem.eql(u8, value, "distinct"))
                .distinct
            else if (std.mem.eql(u8, value, "all"))
                .all
            else
                die("--only: expected family, distinct, or all; got {s}\n", .{value});
        } else if (std.mem.eql(u8, arg, "--brief")) {
            brief = true;
            only = .family;
        } else shared.commonArg(gpa, argv, &i, &c, &roots, "family");
    }

    const pat = c.positional orelse die(usage_msg, .{});
    if (pat.len == 0) die("irregex family: empty PATTERN\n", .{});
    if (roots.items.len == 0 and !c.all) die("irregex family: scope is mandatory — pass ROOT... or --all\n", .{});

    var set = shared.compileSet(gpa, &.{pat}, c.fixed, c.ignore_case) catch |e| shared.dieCompile(e);
    defer set.deinit(gpa);

    const t0 = nowNs(io);
    const rr = try flags.rootsOf(gpa, roots.items);
    defer rr.deinit(gpa);
    var corpus = try corpus_mod.load(gpa, io, rr.items);
    defer corpus.deinit();
    const loaded_ns = nowNs(io);

    const searchable = try gpa.alloc([]const u8, corpus.docs.len);
    defer gpa.free(searchable);
    for (corpus.docs, corpus.paths, searchable) |doc, path, *dest|
        dest.* = if (unit == .file or isSourcePath(path)) doc else "";
    var selected = regions.select(gpa, searchable, &set, unit, context) catch |e| shared.dieCompile(e);
    defer selected.deinit();
    const bodies = try gpa.alloc([]const u8, selected.items.len);
    defer gpa.free(bodies);
    const labels = try gpa.alloc([]const u8, selected.items.len);
    defer {
        for (labels) |label| gpa.free(label);
        gpa.free(labels);
    }
    for (selected.items, bodies, labels) |region, *body, *label| {
        body.* = corpus.docs[region.doc][region.start..region.end];
        label.* = try std.fmt.allocPrint(gpa, "{s}#L{d}", .{ corpus.paths[region.doc], region.line_start });
    }

    const chosen_mode = mode orelse if (unit == .file) family_mod.Mode{ .dup = 0.25 } else family_mod.Mode{ .structure = 0.35 };
    var analysis = try family_mod.analyze(gpa, bodies, labels, chosen_mode, min_size, if (unit == .file) 16 else 1, true, unit != .file);
    defer analysis.deinit();
    rankFamilies(analysis.list, selected.items, chosen_mode);

    const channel: []const u8 = switch (chosen_mode) {
        .dup => "dup",
        .structure => "structure",
        .echo => "echo",
    };
    const unit_name: []const u8 = switch (unit) {
        .file => "file",
        .function => "function",
        .match => "match",
    };
    const unit_plural: []const u8 = switch (unit) {
        .file => "files",
        .function => "functions",
        .match => "matches",
    };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    var emitted: usize = 0;
    if (only != .distinct) {
        for (analysis.list, 1..) |f, rank| {
            if (emitted >= c.top) break;
            const repeated = repeatedLines(f, selected.items);
            const score = opportunity(f, selected.items, chosen_mode);
            if (c.json) {
                out.print(gpa, "{{\"kind\":\"family\",\"rank\":{d},\"size\":{d},\"unit\":\"{s}\",\"channel\":\"{s}\",\"edge\":{d:.4},\"repeated_lines\":{d},\"score\":{d:.2},\"members\":", .{ rank, f.members.len, unit_name, channel, f.edge, repeated, score }) catch oom();
                out.append(gpa, '[') catch oom();
                for (f.members, 0..) |m, k| {
                    if (k != 0) out.append(gpa, ',') catch oom();
                    emitRegionJson(&out, gpa, corpus.docs, corpus.paths, selected.items[m], unit);
                }
                out.appendSlice(gpa, "]}\n") catch oom();
            } else if (brief) {
                emitFamilyBrief(&out, gpa, corpus.docs, corpus.paths, roots.items, selected.items, f, rank, channel, repeated, score, unit);
            } else {
                out.print(gpa, "family {d} · {d} {s} · ~{d} repeated lines · {s} {d:.4}\n", .{ rank, f.members.len, unit_plural, repeated, channel, f.edge }) catch oom();
                for (f.members) |m| emitRegionHuman(&out, gpa, corpus.docs, corpus.paths, selected.items[m], unit, "    ");
            }
            emitted += 1;
        }
    }
    if (only != .family) {
        for (analysis.distinct) |item| {
            if (emitted >= c.top) break;
            const r = selected.items[item.member];
            if (c.json) {
                out.print(gpa, "{{\"kind\":\"distinct\",\"unit\":\"{s}\",\"member\":", .{unit_name}) catch oom();
                emitRegionJson(&out, gpa, corpus.docs, corpus.paths, r, unit);
                out.print(gpa, ",\"nearest\":", .{}) catch oom();
                if (item.nearest) |nearest|
                    emitRegionJson(&out, gpa, corpus.docs, corpus.paths, selected.items[nearest], unit)
                else
                    out.appendSlice(gpa, "null") catch oom();
                out.print(gpa, ",\"byte_distance\":{d:.4},\"structure_distance\":{d:.4}}}\n", .{ item.byte_distance, item.structure_distance }) catch oom();
            } else {
                emitRegionHuman(&out, gpa, corpus.docs, corpus.paths, r, unit, "distinct · ");
                if (item.nearest) |nearest| {
                    out.appendSlice(gpa, "    nearest · ") catch oom();
                    emitRegionHuman(&out, gpa, corpus.docs, corpus.paths, selected.items[nearest], unit, "");
                    out.print(gpa, "    distances · structure {d:.4} · bytes {d:.4}\n", .{ item.structure_distance, item.byte_distance }) catch oom();
                }
            }
            emitted += 1;
        }
    }
    corpus_mod.emitStdout(out.items);

    std.debug.print("family: {d} files · {d} {s} candidate(s) for '{s}' · {d} edge(s) · {d} family(s) · {d} distinct · load {d:.0} ms · graph {d:.0} ms\n", .{
        corpus.docs.len,
        selected.items.len,
        unit_name,
        pat,
        analysis.edges,
        analysis.list.len,
        analysis.distinct.len,
        ms(loaded_ns - t0),
        ms(nowNs(io) - loaded_ns),
    });
}

fn regionLines(r: regions.Region) usize {
    return @as(usize, r.line_end - r.line_start) + 1;
}

fn repeatedLines(f: family_mod.Family, items: []const regions.Region) usize {
    var smallest: usize = std.math.maxInt(usize);
    for (f.members) |member| smallest = @min(smallest, regionLines(items[member]));
    return if (f.members.len < 2) 0 else smallest * (f.members.len - 1);
}

fn opportunity(f: family_mod.Family, items: []const regions.Region, mode: family_mod.Mode) f64 {
    const confidence = switch (mode) {
        .dup, .structure => 1.0 - f.edge,
        .echo => f.edge,
    };
    return @as(f64, @floatFromInt(repeatedLines(f, items))) * @max(confidence, 0.0);
}

fn rankFamilies(list: []family_mod.Family, items: []const regions.Region, mode: family_mod.Mode) void {
    const Ctx = struct {
        items: []const regions.Region,
        mode: family_mod.Mode,

        fn less(self: @This(), a: family_mod.Family, b: family_mod.Family) bool {
            const as = opportunity(a, self.items, self.mode);
            const bs = opportunity(b, self.items, self.mode);
            if (as != bs) return as > bs;
            if (a.members.len != b.members.len) return a.members.len > b.members.len;
            return a.members[0] < b.members[0];
        }
    };
    std.mem.sort(family_mod.Family, list, Ctx{ .items = items, .mode = mode }, Ctx.less);
}

fn emitFamilyBrief(
    out: *std.ArrayList(u8),
    gpa: std.mem.Allocator,
    docs: []const []const u8,
    paths: []const []const u8,
    roots: []const []const u8,
    items: []const regions.Region,
    f: family_mod.Family,
    rank: usize,
    channel: []const u8,
    repeated: usize,
    score: f64,
    unit: regions.Unit,
) void {
    out.print(gpa, "{d}. score {d:.1} · ~{d} lines · {d}× · {s} {d:.4} · ", .{ rank, score, repeated, f.members.len, channel, f.edge }) catch oom();
    const shown = @min(f.members.len, 2);
    for (f.members[0..shown], 0..) |member, i| {
        if (i > 0) out.appendSlice(gpa, " ↔ ") catch oom();
        const r = items[member];
        out.print(gpa, "{s}:{d} {s}", .{ compactPath(paths[r.doc], roots), r.line_start, headline(docs[r.doc], r, unit) }) catch oom();
    }
    if (f.members.len > shown) out.print(gpa, " +{d}", .{f.members.len - shown}) catch oom();
    out.append(gpa, '\n') catch oom();
}

fn compactPath(path: []const u8, roots: []const []const u8) []const u8 {
    var best: []const u8 = path;
    for (roots) |root| {
        if (std.mem.eql(u8, root, ".") or path.len <= root.len or path[root.len] != '/') continue;
        if (std.mem.startsWith(u8, path, root) and path.len - root.len - 1 < best.len) best = path[root.len + 1 ..];
    }
    return best;
}

fn emitRegionJson(out: *std.ArrayList(u8), gpa: std.mem.Allocator, docs: []const []const u8, paths: []const []const u8, r: regions.Region, unit: regions.Unit) void {
    out.appendSlice(gpa, "{\"path\":") catch oom();
    emit.jsonStr(out, gpa, paths[r.doc]);
    out.print(gpa, ",\"line_start\":{d},\"line_end\":{d},\"headline\":", .{ r.line_start, r.line_end }) catch oom();
    emit.jsonStr(out, gpa, headline(docs[r.doc], r, unit));
    out.append(gpa, '}') catch oom();
}

fn emitRegionHuman(out: *std.ArrayList(u8), gpa: std.mem.Allocator, docs: []const []const u8, paths: []const []const u8, r: regions.Region, unit: regions.Unit, prefix: []const u8) void {
    out.print(gpa, "{s}{s}:{d}-{d} · {s}\n", .{ prefix, paths[r.doc], r.line_start, r.line_end, headline(docs[r.doc], r, unit) }) catch oom();
}

fn headline(doc: []const u8, r: regions.Region, unit: regions.Unit) []const u8 {
    var start = if (unit == .match) r.match_start else r.start;
    while (start < r.end) {
        const end = std.mem.indexOfScalarPos(u8, doc, start, '\n') orelse r.end;
        const line = std.mem.trim(u8, doc[start..@min(end, r.end)], " \t\r");
        if (line.len > 0 and !std.mem.startsWith(u8, line, "//") and !std.mem.startsWith(u8, line, "#") and
            !std.mem.startsWith(u8, line, "/*") and !std.mem.startsWith(u8, line, "*")) return line;
        start = @min(end + 1, r.end);
    }
    return "";
}

fn isSourcePath(path: []const u8) bool {
    const extensions = [_][]const u8{
        ".c",  ".cc",  ".cpp", ".cxx", ".ex",    ".exs", ".go",  ".h",     ".hpp", ".java",
        ".js", ".jsx", ".kt",  ".kts", ".m",     ".mm",  ".php", ".proto", ".py",  ".pyx",
        ".rb", ".rs",  ".sh",  ".sql", ".swift", ".ts",  ".tsx", ".zig",
    };
    for (extensions) |extension| if (std.mem.endsWith(u8, path, extension)) return true;
    return false;
}
