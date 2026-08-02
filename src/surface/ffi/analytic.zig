//! Blast's C-ABI dispatch — one entry, one cursor.
//!
//! This module materializes a BLAST answer — the composed verbs that need
//! both engines over CURRENT bytes — into a pull cursor of self-describing
//! `rows.Row`s. Four verbs share the entry because a verb is a `u32` op plus
//! the compose params family, so a new verb adds no C symbol. Kinship and
//! sweep live in `librelate`; `rank` lives in `libgist`.
//!
//! The cursor itself (`Answer`) and the four walk symbols (`irgx_rows_*`)
//! live in `libirgx`. This module only produces: it builds an Answer, fills
//! the arena, and hands it over. A host walks it with the shared substrate.
//!
//! ## Declinature is a feature, not a stub
//!
//! A verb this build cannot answer in-process returns `.stale`, which the ABI
//! defines as *this tier declines — answer through the subprocess fallback, the
//! answer there is identical*. That is the same fail-open contract the exact
//! plane uses for a pattern outside linear syntax, and it is what lets the
//! plane graduate verb by verb without any binding changing a line: a binding
//! calls the FFI, reads `.stale`, and shells the CLI exactly as it does today.
//!
//! ## Why the answer is materialized whole
//!
//! An analytic verb has no meaningful partial state: `blast` must see every
//! dependent before it knows the radius. So the work runs to completion into
//! one arena, and the cursor walks a finished slice. Rows stay valid until
//! `irgx_rows_close`.

const std = @import("std");
const api = @import("irregex").api;
const answer = @import("irregex").ffi.answer;
const contract = @import("irregex").ffi.contract;
const rows = @import("irregex").ffi.rows;

const Status = contract.Status;
const Row = rows.Row;
const table = rows.table;
const Answer = answer.Answer;

/// What one dispatch arm is handed: the arena its rows must live in, the warm
/// engine, and the cancellation token the host may trip mid-answer.
const Ctx = struct {
    arena: std.mem.Allocator,
    engine: *api.Engine,
    cancel: ?*const api.CancelToken,
    out: *std.ArrayList(Row),
    stats: *rows.Stats,
};

/// `Decline` is the hosted spelling of `.stale`: not an error, a tier boundary.
const ArmError = error{ OutOfMemory, Decline };

fn owned(op: table.Op) bool {
    return switch (op) {
        .context, .family, .provenance, .blast => true,
        .similar,
        .dups,
        .clusters,
        .echoes,
        .concepts,
        .fragments,
        .distinct,
        .recall,
        .pack,
        .quote,
        .patterns,
        .pattern_counts,
        .rank,
        => false,
    };
}

/// Run one blast verb and materialize its cursor.
///
/// Fails closed before doing any work: an unknown op, an op this library does
/// not own, a params pointer of the wrong family or size, or an unassigned
/// flag bit is `.invalid` — never a reinterpret of memory the caller did not
/// write.
pub fn run(
    engine: *api.Engine,
    op: u32,
    params_ptr: ?*const rows.Params,
    cancel: ?*api.CancelToken,
    out: ?**Answer,
) Status {
    contract.beginCall();
    const slot = out orelse return .invalid;
    const params = params_ptr orelse return .invalid;
    if (op == 0 or op > table.verbs.len) return .invalid;
    const verb = table.verbs[op - 1];
    if (!owned(verb.op)) return .invalid;

    // The family check is the whole point of declaring `params` per verb: it
    // catches a host that passed `KinshipParams` to `blast` HERE, at the
    // boundary, instead of reading a `[*]const u8` out of an f64's bytes.
    switch (verb.params) {
        .compose => if (rows.params(rows.ComposeParams, &params.compose) == null) return .invalid,
        .kinship, .retrieval, .sweep, .rank => return .invalid,
    }

    const cursor = Answer.begin() catch return contract.report(.{ .code = error.OutOfMemory });
    errdefer answer.close(cursor);

    var collected: std.ArrayList(Row) = .empty;
    const started = std.Io.Clock.now(.awake, engine.io).nanoseconds;
    var st = rows.Stats{ .struct_size = @sizeOf(rows.Stats) };
    var ctx = Ctx{
        .arena = cursor.arena.allocator(),
        .engine = engine,
        .cancel = cancel,
        .out = &collected,
        .stats = &st,
    };

    dispatch(&ctx, verb, params) catch |err| switch (err) {
        error.Decline => {
            answer.close(cursor);
            return .stale;
        },
        error.OutOfMemory => return contract.report(.{ .code = error.OutOfMemory }),
    };

    const items = collected.toOwnedSlice(ctx.arena) catch
        return contract.report(.{ .code = error.OutOfMemory });
    st.rows = items.len;
    const elapsed = std.Io.Clock.now(.awake, engine.io).nanoseconds - started;
    st.elapsed_ns = if (elapsed > 0) @intCast(elapsed) else 0;
    cursor.finish(items, st);
    slot.* = cursor;
    return .ok;
}

/// The verb table's one switch. Every arm not yet in-process declines, so the
/// binding answers through the CLI and the caller sees the same rows.
fn dispatch(ctx: *Ctx, verb: table.Verb, params: *const rows.Params) ArmError!void {
    _ = ctx;
    _ = params;
    return switch (verb.op) {
        // Graduating in the analytic plane's staged order: compose needs both
        // the atlas resolve and the exact PatternSet.
        .context, .family, .provenance, .blast => error.Decline,

        .similar,
        .dups,
        .clusters,
        .echoes,
        .concepts,
        .fragments,
        .distinct,
        .recall,
        .pack,
        .quote,
        .patterns,
        .pattern_counts,
        .rank,
        => unreachable,
    };
}

test "an unknown op and a foreign verb both fail closed" {
    const t = std.testing;
    // No engine is dereferenced on these paths — validation precedes work, by
    // design, so a bad call cannot reach the corpus at all.
    const engine: *api.Engine = @ptrFromInt(@alignOf(api.Engine));
    var out: *Answer = undefined;

    var params = rows.Params{
        .compose = .{
            .struct_size = @sizeOf(rows.ComposeParams),
            .flags = 0,
            .text = null,
            .text_len = 0,
            .patterns = null,
            .npatterns = 0,
            .max_distance = 0,
            .min_echo = 0,
            .budget = 0,
            .top = 0,
        },
    };
    try t.expectEqual(Status.invalid, run(engine, 0, &params, null, &out));
    try t.expectEqual(Status.invalid, run(engine, table.verbs.len + 1, &params, null, &out));
    try t.expectEqual(Status.invalid, run(engine, @intFromEnum(table.Op.provenance), &params, null, null));
    try t.expectEqual(Status.invalid, run(engine, @intFromEnum(table.Op.provenance), null, null, &out));

    // `patterns` is relate's verb: handed to blast_run, the ownership check
    // rejects it rather than declining into a CLI fallback for the wrong binary.
    try t.expectEqual(Status.invalid, run(engine, @intFromEnum(table.Op.patterns), &params, null, &out));

    params.compose.flags = 1 << 30; // never assigned by this build
    try t.expectEqual(Status.invalid, run(engine, @intFromEnum(table.Op.provenance), &params, null, &out));
}

test "every blast verb declines today — none can fall through" {
    // A `switch` over the owned ops with no `else` makes this structural:
    // adding a verb to this library's set fails the BUILD until this file
    // names it. The test pins that the global table still enumerates every
    // op, including the ones other libraries own.
    const t = std.testing;
    for (table.verbs, 1..) |verb, op| {
        try t.expectEqual(@as(u32, @intCast(op)), @intFromEnum(verb.op));
        try t.expect(@intFromEnum(verb.schema) >= 1 and @intFromEnum(verb.schema) <= table.schemas.len);
    }
}

// ── adversarial additions: the decline matrix, exhaustively ────────────────
//
// The two tests above spot-check the fail-closed boundary. These make it a
// MATRIX, so a future "graduate this op off Decline" change cannot silently
// skip a rejection this file already guaranteed: every wrong `struct_size`,
// every op a sibling library owns, every op code past the table, and a spread
// of unassigned flag bits must all be `.invalid` — and each of these paths
// returns BEFORE the engine is dereferenced, which is why a bogus engine
// pointer is safe here (validation precedes work, by contract).

const fake_engine: *api.Engine = @ptrFromInt(@alignOf(api.Engine));

fn composeParams() rows.Params {
    return .{ .compose = .{
        .struct_size = @sizeOf(rows.ComposeParams),
        .flags = 0,
        .text = null,
        .text_len = 0,
        .patterns = null,
        .npatterns = 0,
        .max_distance = 0,
        .min_echo = 0,
        .budget = 0,
        .top = 0,
    } };
}

test "FFI: a wrong params struct_size fails closed before any work" {
    const t = std.testing;
    var out: *Answer = undefined;
    const prov = @intFromEnum(table.Op.provenance);
    for ([_]u32{ 0, @sizeOf(rows.ComposeParams) - 4, @sizeOf(rows.ComposeParams) + 4, 1 }) |sz| {
        var p = composeParams();
        p.compose.struct_size = sz; // the family/size gate rejects at the boundary
        try t.expectEqual(Status.invalid, run(fake_engine, prov, &p, null, &out));
    }
}

test "FFI: no op a sibling library owns is answered by blast_run" {
    // Every relate/gist verb, handed to blast's entry with otherwise-valid
    // params, is rejected at the ownership gate rather than declining into a
    // CLI fallback for the wrong binary. Also pins the owned set is exactly the
    // four compose verbs — a fifth appearing here without the switch below
    // learning it would be caught by the sibling test's build break.
    const t = std.testing;
    var out: *Answer = undefined;
    var p = composeParams();
    var owned_count: usize = 0;
    for (table.verbs, 1..) |verb, op| {
        if (owned(verb.op)) {
            owned_count += 1;
        } else {
            try t.expectEqual(Status.invalid, run(fake_engine, @intCast(op), &p, null, &out));
        }
    }
    try t.expectEqual(@as(usize, 4), owned_count); // context, family, provenance, blast
}

test "FFI: op codes past the table fail closed" {
    const t = std.testing;
    var out: *Answer = undefined;
    var p = composeParams();
    for (0..8) |k| {
        const op: u32 = @intCast(table.verbs.len + 1 + k);
        try t.expectEqual(Status.invalid, run(fake_engine, op, &p, null, &out));
    }
}

test "FFI: unassigned flag bits fail closed" {
    // Only bits 0..8 are assigned (rows.known_an_flags); anything at or above
    // bit 9 is a caller writing into reserved space and must be refused, alone
    // or combined with a legitimate bit.
    const t = std.testing;
    var out: *Answer = undefined;
    const prov = @intFromEnum(table.Op.provenance);
    for ([_]u32{ 1 << 9, 1 << 15, 1 << 20, 1 << 31, (1 << 9) | rows.an_max_distance }) |bit| {
        var p = composeParams();
        p.compose.flags = bit;
        try t.expectEqual(Status.invalid, run(fake_engine, prov, &p, null, &out));
    }
}
