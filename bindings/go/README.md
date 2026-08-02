<!--
doc_radar:
  counts:
    - glob: "bindings/go/*/"
      equals: 1
      unit: dirs
-->

# `bindings/go/`

Go binding for [blast](../../README.md) — what moves if I change this. The
composed verbs live in [`compose/`](compose/). Shared contract and runtime come
from irregex; typed kinship row views come from relate.

```bash
go get github.com/The-Billy-Company/blast/bindings/go
```

Default build is pure Go. In-process is opt-in with `-tags irgx_ffi` after
`zig build`. Release tags are nested: `bindings/go/vX.Y.Z`.
