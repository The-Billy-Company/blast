# blast - blast radius and provenance for Rust

The Rust face of the `blast` package: what breaks if I change this symbol, and
where a pasted snippet came from. Exact narrows, compression reasons inside the
candidate set. Four verbs: `context`, `family`, `provenance`, `blast`.

```bash
cargo add blast-search
```

The package on crates.io is
[`blast-search`](https://crates.io/crates/blast-search) and the library is
`blast`, so you still write `use blast::…`. The bare name belongs to an
unrelated crate and names there are permanent, which is the same reason the PyPI
distribution is `blast-search` too.

```rust
use blast::provenance;

let rows = provenance("a pasted snippet").rows()?;
```

Every verb answers by running the `blast` binary, so that has to be on `PATH`
(or `$BLAST_BIN`); [the repository](https://github.com/The-Billy-Company/blast)
builds it with `zig build`.

Depends on [`irgx`](https://crates.io/crates/irgx) for the substrate - resolved
from the registry in a published build, by path in this checkout. Does not
re-export gist's search surface or relate's kinship verbs.
