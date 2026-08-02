//! JSON-safe string emission for the byte slices blast does not control.
//!
//! `emit.jsonStr` is the ecosystem's one JSON string escaper, and by contract
//! it assumes the caller already holds valid UTF-8: a JSON string MUST be valid
//! Unicode (RFC 8259 §7), and jsonStr's vectorized fast path passes multi-byte
//! sequences through RAW for speed rather than validating them. Its own header
//! spells the division of labor out — "callers that may hold invalid UTF-8 gate
//! to base64 upstream".
//!
//! blast renders two byte slices it never sanctioned: filesystem PATHS (a Linux
//! filename is arbitrary bytes, not guaranteed UTF-8) and the provenance TEXT
//! argument (argv bytes). Handed straight to jsonStr, a path like `a\xffb.zig`
//! produces a JSON string holding a raw ill-formed byte — which a conformant
//! parser rejects outright (std.json returns `SyntaxError`), corrupting the
//! whole `--json` document an agent's tool is trying to read.
//!
//! This module is the caller-side gate that contract names. Valid UTF-8 takes
//! the identical path it always did (one validate pass, then the same jsonStr —
//! byte-for-byte the same output, so the common case is unchanged); only a
//! genuinely ill-formed slice pays a single rewrite, each maximal invalid
//! subpart replaced by U+FFFD, the Unicode-standard substitution. That keeps
//! every field a plain JSON string — no schema change — and the price is that a
//! non-UTF-8 path renders lossily rather than losslessly. The lossless
//! alternative (ripgrep's `{"bytes":"<base64>"}`) would change the field's very
//! shape, and with it every consumer, so it is deliberately not taken here.

const std = @import("std");
const emit = @import("irregex").inner.cli.emit;
const oom = @import("irregex").inner.cli.outcome.oom;

const replacement = "\u{FFFD}"; // EF BF BD — one code point substituted per bad subpart

/// Append `s` to `out` as a JSON string literal (surrounding quotes included),
/// guaranteed to be valid JSON for ANY input bytes.
pub fn str(out: *std.ArrayList(u8), gpa: std.mem.Allocator, s: []const u8) void {
    if (std.unicode.utf8ValidateSlice(s)) return emit.jsonStr(out, gpa, s);
    var clean: std.ArrayList(u8) = .empty;
    defer clean.deinit(gpa);
    sanitize(&clean, gpa, s);
    emit.jsonStr(out, gpa, clean.items);
}

/// Rewrite `s` into `out` as well-formed UTF-8: copy each valid scalar as-is,
/// and emit one U+FFFD for each byte that does not begin a complete, valid
/// sequence, advancing one byte so no input is silently dropped.
fn sanitize(out: *std.ArrayList(u8), gpa: std.mem.Allocator, s: []const u8) void {
    var i: usize = 0;
    while (i < s.len) {
        const len = std.unicode.utf8ByteSequenceLength(s[i]) catch {
            out.appendSlice(gpa, replacement) catch oom();
            i += 1;
            continue;
        };
        if (i + len <= s.len and std.unicode.utf8ValidateSlice(s[i .. i + len])) {
            out.appendSlice(gpa, s[i .. i + len]) catch oom();
            i += len;
        } else {
            out.appendSlice(gpa, replacement) catch oom();
            i += 1;
        }
    }
}

const t = std.testing;

test "str: valid UTF-8 is byte-identical to raw jsonStr (the common path is unchanged)" {
    // The whole design rests on valid input costing nothing but one validate
    // pass, so prove the bytes match jsonStr exactly across the adversarial-but-
    // valid domain: quotes, backslashes, controls, and multi-byte scalars.
    for ([_][]const u8{
        "plain.zig",
        "a\"b\\c\nd\te\x01\x1f\x7f.zig",
        "café/\u{1F980}/naïve.rs",
        "",
    }) |s| {
        var got: std.ArrayList(u8) = .empty;
        defer got.deinit(t.allocator);
        var want: std.ArrayList(u8) = .empty;
        defer want.deinit(t.allocator);
        str(&got, t.allocator, s);
        emit.jsonStr(&want, t.allocator, s);
        try t.expectEqualStrings(want.items, got.items);
    }
}

test "str: invalid UTF-8 becomes valid JSON, parseable, with U+FFFD for the bad bytes" {
    for ([_][]const u8{
        "a\xffb", // a lone 0xFF
        "\x80\x81", // stray continuation bytes
        "e\xc3", // a truncated 2-byte lead at EOF
        "\xed\xa0\x80", // a UTF-16 surrogate, ill-formed in UTF-8
        "ok\xf0\x28\x8c\x28", // overlong/broken 4-byte sequence amid ASCII
    }) |s| {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(t.allocator);
        str(&buf, t.allocator, s);
        // The output must be valid UTF-8 and parse as a JSON string.
        try t.expect(std.unicode.utf8ValidateSlice(buf.items));
        const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, buf.items, .{});
        defer parsed.deinit();
        try t.expect(parsed.value == .string);
        try t.expect(std.mem.indexOf(u8, parsed.value.string, replacement) != null);
    }
}
