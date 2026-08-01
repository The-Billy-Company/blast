# the `blast` face

The dispatch shell for the composed binary. What the verbs mean, why
composing beats piping the two faces, and how scope resolves are in the
[repository README](../../../../README.md); this note covers only what is
in this directory.

## When to edit here

- A composed verb, flag, help string, or `--schema` field changes.
- Exit-code / stdout vs stderr framing changes.

[`repertoire.zig`](repertoire.zig) declares the composed verbs once -
usage form, both descriptions, typed flags, and the handler that runs
each, plus the **retired** table that teaches `blast context` /
`blast family` their new relate spelling instead of answering "unknown
command". `gist`'s `src/surface/cli/manifest.zig` renders `--help`,
`--schema`, the dispatch, the unknown-verb line, and the process itself
from that table, the same way relate's face does. So
[`main.zig`](main.zig) holds no surface at all: it names its repertoire
and hands over, which is why the two faces' entrypoints are the same six
lines with a different table.

The work lives in the sibling drivers ([`provenance.zig`](provenance.zig)
and [`blast.zig`](blast.zig)). The composition kernels - pure, I/O-free -
live in the `relate` package under `src/kernel/compose/`. Contract
authority for the composed verbs and the `CandidateSet` model is gist's
`irregex/contract/analytic.toml`.
