---
doc_radar:
  sentinels:
    - description: "blast exposes the composed verbs"
      file: bindings/rust/src/lib.rs
      contains: ["pub fn provenance", "pub fn blast", "pub fn context", "pub fn family"]
    - description: "blast depends on the irregex substrate"
      file: bindings/rust/Cargo.toml
      contains: ["irregex ="]
---

# blast — composed verbs

The Rust face of the `blast` package. Exact narrows, compression reasons inside
the candidate set. Four verbs: `context`, `family`, `provenance`, `blast`.

```rust
use blast::provenance;

let rows = provenance("a pasted snippet").rows()?;
```

Depends on [`irregex`](../../../irregex/bindings/rust/) for the substrate.
Does not re-export gist's search surface or relate's kinship verbs.
