# blast

The composed face - the two questions that need BOTH engines and CURRENT
bytes:

- `irregex blast SYMBOL` - the live blast radius of a symbol before an
  edit: dependents (def/use classified), dependencies, tangential twins,
  same-language ripple, and the comments that mention it. No precomputed
  graph; every edge is derived from the bytes on disk right now.
- `irregex provenance "<text>"` - quote attribution re-verified against
  live bytes: a phrase surfaces only if its source file still holds it.

The engines behind both verbs live in [`relate`](../relate)'s compose
tier (composition-as-narrowing, `--matching PAT`, is a flag there too);
this package is the face - the argv, the rendering, and the wiring that
runs the exact engine and the compression engine together against the
current tree.

The package is named `blast`; the binary it ships is still `irregex`,
so `irregex blast` / `irregex provenance` invocations are untouched. The
`irregex` package name belongs to [the library](../irregex).

## Layout

One tier: `src/surface/face/irregex/` - the face and its verbs. All the
machinery is imported: [`irregex`](../irregex) (engines, corpus, argv),
[`relate`](../relate) (kinship, the shelf), [`gist`](../gist) (the CLI
chassis and manifest driver).

## Build

```bash
zig build          # the irregex binary → zig-out/bin/irregex
zig build check    # compile-only
```

ReleaseFast by default (`-Dcli-optimize` overrides). No unit suite of
its own; the face is a thin composition and its behavior is covered by
the engine suites underneath it. Architecture is machine-checked by
`contract/blast.ward` (two hops of reach, and no more).

## Provenance

Extracted from `billy/libs/kernels/irregex` (cut at billy@ce430bbaab,
PLAN v5 split). Formerly the in-tree `irregex` composed face (ADR-367).
Dev model: sibling checkouts via `build.zig.zon` path-deps; releases pin
url + hash. Apache-2.0, like the packages underneath it.
