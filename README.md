# blast

The composed face - the two questions that need BOTH engines and CURRENT
bytes. The package is named `blast` and so is the binary. The `irregex`
name stays with the engine library (`libirregex` / `include/irregex.h`).

## What it is

`gist` answers _"where is this exact pattern?"_ and `relate` answers _"what is
this text like / which files cover it / what forked?"_. `blast` is the third
face, for the two questions that need **current bytes** rather than a narrowing
(exact ∩ compression over current bytes).
Composition-as-narrowing is a modifier on relate —
`relate pack --matching` and `relate echoes --matching` are what
`blast context` / `blast family` were.

```text
blast provenance TEXT [--min-phrase N] [-C N] [--json]
    where did this pasted text come from, and does the tree still contain it?
    relate's quotation attribution names one exemplar file per verbatim phrase
    on the codex shelf; blast then re-reads that file's CURRENT bytes and
    re-finds the phrase exactly — a phrase surfaces only if the live file still
    holds it (>=12-byte floor), never a stale line

blast blast SYMBOL [--budget N] [--json] [ROOT...]
    what moves if I change this symbol? The live blast radius from CURRENT bytes
    (no precomputed graph, so a mid-edit file counts the instant it saves): the
    seed's definition site(s) + parser-free kind guess (only a source file can
    declare, so a definition list in prose or a key in a spec is a mention, and
    the body read for dependencies belongs to the STRONGEST definition rather
    than whichever weak shape sorts first alphabetically); direct.dependents
    (functions referencing it, def/use classified) and direct.dependencies
    (what the seed's body leans on, minus its own parameters and locals, homed
    inside the seed's package — a `head.member` resolves only in the file its
    head names, never against the nearest same-named declaration in the tree,
    and a name a packageful of files declares is ambient rather than a
    dependency unless the seed's own file declares or imports it);
    tangential.twins
    (compression kin of the seed's file — co-edit risk) and tangential.ripple
    (same-language second-hop callers, hops=2); and comments that MENTION it
    (the stale-doc / TODO / invariant surface). Exact and statistical evidence
    stay in separate fields; --budget N trims the lowest-priority tail into
    stats.omitted; scope defaults to the whole CWD corpus, narrowable with ROOT...
```

Plus the conventions every face keeps: `--help` / `--version` /
`--schema` (JSON capability manifest), results on stdout (`--json` = NDJSON),
diagnostics on stderr, unknown verbs exit 2.

## Why compose instead of piping the two faces

`gist -l | relate pack` and `gist -l | relate echoes` throw the match
information away between steps and pay whole-corpus statistical noise —
README/changelog files that never matched still rank high on coverage, and a
whole-tree repetition sweep can't scope to a symbol. Composing (whether as the
`--matching` modifier on relate or as a verb here) keeps three things the
hand-join loses:

- The **exact selector bounds the statistical work.** `pack --matching` builds
  its coverage lexicon from the candidate docs alone; `echoes --matching` builds
  its kinship graph over exact-hit units alone. Noise the patterns excluded and
  unrelated bytes elsewhere in a matching file are gone before compression runs —
  which also means the noise floors are calibrated against the matching set
  rather than the corpus.
- **Similarity and difference are both answers.** Families identify
  consolidation candidates; `--shape distinct` keeps the singletons rather than
  dropping them, each carrying its closest miss and both independent distances,
  so a reviewer can see why similar names do not imply the same implementation.
- The **scores stay separate.** Each narrowed `pack` pick carries the patterns
  that admitted it _and_ its marginal bits; there is no fused, uncalibrated
  relevance number. `provenance` never reports a line the current bytes can't
  confirm.

## Scope

`provenance` needs none: it reads the corpus-wide codex shelf (`relate index --shelf` / `gist codex build`). `blast` is corpus-wide by nature (a blast radius
that stopped at a directory would lie), so it defaults to the whole CWD corpus,
narrowable with `ROOT...`. The narrowing questions moved to `relate`, where
`--matching` requires `ROOT...` or an explicit `--all` — a composed query can
never silently sweep `vendor/`/`.etc`.
## Layout

One tier: [`src/surface/face/blast/`](src/surface/face/blast/) - the
face and its verbs. All the machinery is imported: `irregex` (engines,
corpus, argv), `relate` (kinship, the shelf, the compose kernels),
`gist` (the CLI chassis and manifest driver).

## Build and test

```bash
zig build          # the blast binary → zig-out/bin/blast
zig build test     # the unit suite
zig build check    # compile-only
```

ReleaseFast by default (`-Dcli-optimize` overrides). The suite here is
small on purpose - the face is a thin composition, so most of its
behavior is covered by the engine suites underneath it. Architecture is
machine-checked by [`contract/blast.ward`](contract/blast.ward): two
hops of reach, and no more.

## Provenance

Extracted from a private monorepo package path (formerly
`libs/kernels/irregex`, cut at ce430bbaab). Dev model is sibling
checkouts via `build.zig.zon` path-deps; releases pin url + hash.
Apache-2.0, like the packages underneath it.
