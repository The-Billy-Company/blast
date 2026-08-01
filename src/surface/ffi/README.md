---
doc_radar:
  sentinels:
    - description: "C ABI producer exports live in the artifact root"
      file: src/surface/ffi/exports.zig
      contains: ["export fn blast_run"]
    - description: "public header declares blast_run and includes the substrate"
      file: include/blast.h
      contains: ["int32_t blast_run(", "#include <gist.h>", "#include <irregex.h>"]
---

# surface/ffi — in-process C-ABI compose producer

`blast_run` materializes a composed answer (`context` · `family` ·
`provenance` · `blast`) into an `irregex_rows *` walked by `libirregex`.
Every verb declines in-process today (`.stale` → CLI fallback); the point of
the seam is that a host links `libblast` for compose and `librelate` for
kinship, never one library for both.

## Shape

| Symbol | Role |
| --- | --- |
| `blast_run(engine, op, params, cancel, out)` | materialize one verb into an `irregex_rows *` |
| `irregex_rows_next` / `_next_batch` / `_stats` / `_close` | walk that cursor (`libirregex`) |

### Files

| File | Owns |
| --- | --- |
| `exports.zig` | The `libblast` artifact root — `export fn blast_run` |
| `analytic.zig` | Dispatch (all four verbs decline today) |

C declarations: [`../../../include/blast.h`](../../../include/blast.h).
