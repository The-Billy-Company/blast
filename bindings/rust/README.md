# blast - blast radius and provenance for Rust

The Rust face of the `blast` package: what breaks if I change this symbol, and
where a pasted snippet came from. Exact narrows, compression reasons inside the
candidate set. Four verbs: `context`, `family`, `provenance`, `blast`.

```rust
use blast::provenance;

let rows = provenance("a pasted snippet").rows()?;
```

Depends on [`irregex`](../../../irregex/bindings/rust/) for the substrate.
Does not re-export gist's search surface or relate's kinship verbs.
