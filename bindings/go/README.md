# `bindings/go/`

Go binding for [blast](../../README.md) — what moves if I change this. The
composed verbs live in [`compose/`](compose/). Shared contract and runtime come
from irregex; typed kinship row views come from relate.

```bash
go get github.com/The-Billy-Company/blast/bindings/go
```

The module path is not itself importable — there is no package at its root. The
one package is [`compose`](compose/):

```go
import "github.com/The-Billy-Company/blast/bindings/go/compose"
```

Default build is pure Go, answering through the `blast` binary, so that has to
be on `PATH` (or `$BLAST_BIN`);
[the repository](https://github.com/The-Billy-Company/blast) builds it with
`zig build`. In-process is opt-in with `-tags irgx_ffi` after `zig build`.

The module is nested, so the proxy resolves it by a subdirectory-prefixed tag —
`bindings/go/v1.0.0`, not `v1.0.0`. `go get` handles that; it only matters if
you are reading the tag list.
