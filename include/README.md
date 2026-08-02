---
doc_radar:
  sentinels:
    - description: "public C ABI keeps blast_run and the blast op macros"
      file: include/blast.h
      contains: ["blast_run", "BLAST_OP_PROVENANCE", "BLAST_OP_BLAST", "#include <irgx.h>"]
    - description: "Zig artifact root exports the same producer"
      file: src/surface/ffi/exports.zig
      contains: ["export fn blast_run"]
---

# `include/` — public C ABI (`libblast`)

The flat, versioned header non-Zig hosts compile against. One file:
[`blast.h`](blast.h). It `#include`s `<gist.h>` for the warm engine and
`<irgx.h>` for the substrate. Implementation lives in
[`../src/surface/ffi/`](../src/surface/ffi/). Link `libblast`, `libgist`,
and `libirgx`.
