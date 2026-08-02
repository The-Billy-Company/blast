<!--
doc_radar:
  sentinels:
    - file: compose.go
      contains:
        - "func Over(roots ...string) *Corpus"
        - "func (c *Corpus) All() *Corpus"
        - "func (c *Corpus) Context(ctx context.Context, p analytic.Compose) ([]relate.Pick, error)"
        - "func (c *Corpus) Family(ctx context.Context, p analytic.Compose) ([]relate.Family, error)"
        - "func (c *Corpus) Provenance(ctx context.Context, p analytic.Compose) ([]Attribution, error)"
        - "func (c *Corpus) Blast(ctx context.Context, p analytic.Compose) (Blast, error)"
        - "var ErrUnscoped"
    - file: ../../../contract/compose.toml
      contains:
        - "[compose.verbs]"
-->

# `compose` — both engines at once

Go binding for [blast](../../../README.md)'s composed verbs. The pattern set
narrows the corpus to a typed candidate set; the compression kernel then reasons
**only inside that subset**. Exact search is gist; kinship is relate; the shared
contract and runtime are irregex.

```bash
go get github.com/The-Billy-Company/blast/bindings/go/compose
```

Default build is pure Go. In-process is opt-in: `go build -tags irgx_ffi`
after `zig build` has minted `zig-out/lib/libblast.dylib`.

```go
c := compose.Over(".").In(repoRoot)

picks, _ := c.Context(ctx, analytic.Compose{Text: "how does the resident session reconcile freshness",
                                           Patterns: []string{"resident"}, Top: 6})
radius, _ := c.Blast(ctx, analytic.Compose{Text: "Assemble"})
```

| Verb         | Question                                                                               | Answers through |
| ------------ | -------------------------------------------------------------------------------------- | --------------- |
| `Context`    | the reading set among the files that _actually_ match some intents                     | `relate`        |
| `Family`     | which matching files are forks or renamed twins of each other                          | `relate`        |
| `Provenance` | where a pasted text is really from, re-verified against **current** bytes              | `blast`         |
| `Blast`      | what moves if I change this symbol — dependents, dependencies, twins, ripple, mentions | `blast`         |

## Two binaries, not one

The right-hand column is load-bearing, and it is why this package needs more on
disk than its own build. Composition-as-narrowing is a `--matching` modifier on
relate's own verbs, so `Context` and `Family` lower into `relate pack` /
`relate echoes`; only the two current-bytes questions reach the `blast` binary.

The resolver reads `RELATE_BIN`/`BLAST_BIN`, then a built `zig-out/bin/` up the
tree from here, then the **sibling checkout** that owns the name, then PATH. The
four packages sit flat beside one another, so `zig build` here mints `blast` and
the sibling rung finds `relate` where it actually is — build both once and
export nothing:

```bash
# from the blast checkout root, with the relate sibling beside it
zig build && ( cd ../relate && zig build )
cd bindings/go && go test ./...   # the module root is here, not the repo root
```

Skip the sibling build and the two composed tests in `compose_test.go` skip
themselves, which is a green run over the seam this package exists for. CI
therefore asserts that no test skipped rather than trusting the ladder held.

Release tags are nested on the blast module: `bindings/go/vX.Y.Z`.
