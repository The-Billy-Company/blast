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

Default build is pure Go (answers through the `blast` binary). In-process is
opt-in: `go build -tags irregex_ffi` after `zig build` has minted
`zig-out/lib/libblast.dylib`.

```go
c := compose.Over(".").In(repoRoot)

picks, _ := c.Context(ctx, analytic.Compose{Text: "how does the resident session reconcile freshness",
                                           Patterns: []string{"resident"}, Top: 6})
radius, _ := c.Blast(ctx, analytic.Compose{Text: "Assemble"})
```

| Verb         | Question                                                                               |
| ------------ | -------------------------------------------------------------------------------------- |
| `Context`    | the reading set among the files that _actually_ match some intents                     |
| `Family`     | which matching files are forks or renamed twins of each other                          |
| `Provenance` | where a pasted text is really from, re-verified against **current** bytes              |
| `Blast`      | what moves if I change this symbol — dependents, dependencies, twins, ripple, mentions |

Release tags are nested on the blast module: `bindings/go/vX.Y.Z`.
