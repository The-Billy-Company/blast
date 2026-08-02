# `include/` — public C ABI (`libblast`)

The flat, versioned header non-Zig hosts compile against. One file:
[`blast.h`](blast.h). It `#include`s `<gist.h>` for the warm engine and
`<irgx.h>` for the substrate. Implementation lives in
[`../src/surface/ffi/`](../src/surface/ffi/). Link `libblast`, `libgist`,
and `libirgx`.
