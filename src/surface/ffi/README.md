# surface/ffi — in-process C-ABI compose producer

`blast_run` materializes a composed answer (`context` · `family` ·
`provenance` · `blast`) into an `irgx_rows *` walked by `libirgx`.
Every verb declines in-process today (`.stale` → CLI fallback); the point of
the seam is that a host links `libblast` for compose and `librelate` for
kinship, never one library for both.

## Shape

| Symbol | Role |
| --- | --- |
| `blast_run(engine, op, params, cancel, out)` | materialize one verb into an `irgx_rows *` |
| `irgx_rows_next` / `_next_batch` / `_stats` / `_close` | walk that cursor (`libirgx`) |

### Files

| File | Owns |
| --- | --- |
| `exports.zig` | The `libblast` artifact root — `export fn blast_run` |
| `analytic.zig` | Dispatch (all four verbs decline today) |

C declarations: [`../../../include/blast.h`](../../../include/blast.h).
