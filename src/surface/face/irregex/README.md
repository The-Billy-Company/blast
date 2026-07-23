---
doc_radar:
  counts:
    - description: "the irregex face: dispatch, four verb drivers, schema, shared plumbing"
      glob: libs/kernels/irregex/src/surface/face/irregex/*.zig
      unit: files
      equals: 7
  sentinels:
    - description: "main.zig lists exactly the four composed verbs on the unknown-verb line"
      file: libs/kernels/irregex/src/surface/face/irregex/main.zig
      contains: "context | family | provenance | blast"
    - description: "the composed verbs are contract-documented, not CLI folklore"
      file: libs/kernels/irregex/contract/search_api.toml
      contains: "[compose.verbs]"
---

# irregex: the composed face

## What it is

`gist` answers _"where is this exact pattern?"_ and `relate` answers _"what is
this text like / which files cover it / what forked?"_. `irregex` is the third
face, for the questions that need **both** engines at once
([ADR-367](../../../../../../../docs/architecture/3-decisions/367-composed-irregex-cli.md)):
the exact engine narrows the corpus to a typed candidate set, then the
compression engine reasons **only inside that narrowing**.

```text
irregex context TEXT -e P [-e P...] [--match any|all] [-F] [-i]
                [--top N] [--json] {ROOT... | --all}
    the minimal non-redundant reading set among files that ACTUALLY match the
    -e patterns. The patterns compile to a PatternSet (the match half);
    candidates.select narrows the corpus to the docs they admit (any = >=1
    pattern, all = every pattern); then greedy submodular coverage (the relate
    half) packs TEXT over a lexicon built from ONLY those docs — so a file the
    patterns never hit can never be picked

irregex family PATTERN [--unit function|match|file]
               [--max-structure-distance T | --max-distance T | --echo-min E]
               [-C N] [--only family|distinct|all] [--brief]
               [-F] [-i] [--top N] [--json] {ROOT... | --all}
    compare the implementations that match PATTERN, not their containing
    files. Function is the default unit; match gives bounded line windows and
    file preserves whole-file analysis. Structural families surface together;
    every genuinely distinct region remains visible with its nearest neighbor
    and separate structure/byte distances. Families rank by conservative
    consolidation opportunity: shortest member lines × redundant copies ×
    channel confidence. --brief emits only one compact line per family, with
    paths relative to the requested scope; --only selects either answer class

irregex provenance TEXT [--min-phrase N] [-C N] [--json]
    where did this pasted text come from, and does the tree still contain it?
    relate's quotation attribution names one exemplar file per verbatim phrase
    on the codex shelf; irregex then re-reads that file's CURRENT bytes and
    re-finds the phrase exactly — a phrase surfaces only if the live file still
    holds it (>=12-byte floor), never a stale line

irregex blast SYMBOL [--budget N] [--json] [ROOT...]
    what moves if I change this symbol? The live blast radius from CURRENT bytes
    (no precomputed graph, so a mid-edit file counts the instant it saves): the
    seed's definition site(s) + parser-free kind guess; direct.dependents
    (functions referencing it, def/use classified) and direct.dependencies
    (identifiers the seed's body resolves to their own def sites); tangential.twins
    (compression kin of the seed's file — co-edit risk) and tangential.ripple
    (same-language second-hop callers, hops=2); and comments that MENTION it
    (the stale-doc / TODO / invariant surface). Exact and statistical evidence
    stay in separate fields; --budget N trims the lowest-priority tail into
    stats.omitted; scope defaults to the whole CWD corpus, narrowable with ROOT...
```

Plus the conventions every irregex face keeps: `--help` / `--version` /
`--schema` (JSON capability manifest), results on stdout (`--json` = NDJSON),
diagnostics on stderr, unknown verbs exit 2.

## Why compose instead of piping the two faces

`gist -l | relate pack` and `gist -l | relate clusters` throw the match
information away between steps and pay whole-corpus statistical noise —
README/changelog files that never matched still rank high on coverage, and a
whole-tree clusters sweep can't scope to a symbol. Composing keeps two things
the hand-join loses:

- The **exact selector bounds the statistical work.** `context` builds its
  coverage lexicon from the candidate docs alone; `family` builds its kinship
  graph over exact-hit functions or windows alone. Noise the patterns excluded
  and unrelated bytes elsewhere in a matching file are gone before compression
  runs.
- **Similarity and difference are both answers.** Family members identify
  consolidation candidates. Distinct regions are not dropped as singletons:
  each carries the closest structural neighbor and both independent distances,
  so a reviewer can see why similar names do not imply the same implementation.
- The **scores stay separate.** Each `context` pick carries the patterns that
  admitted it _and_ its marginal bits; there is no fused, uncalibrated
  relevance number. `provenance` never reports a line the current bytes can't
  confirm.

## Scope is mandatory

`context` and `family` require `ROOT...` or an explicit `--all`, so a composed
query can never silently sweep `vendor/`/`.etc`. `provenance` needs no scope:
it reads the corpus-wide codex shelf (`relate index --shelf` / `gist codex
build`). `blast` is corpus-wide by nature (a blast radius that stopped at a
directory would lie), so it defaults to the whole CWD corpus, narrowable with
`ROOT...`.

## When to edit here

- A composed verb, flag, help string, or `--schema` field changes.
- Exit-code / stdout vs stderr framing changes.

This directory is only the face: `main.zig` classifies the verb and hands off
to the sibling drivers (`context.zig` · `family.zig` · `provenance.zig` ·
`blast.zig`), with shared PatternSet-compile + mask-decode plumbing in
`shared.zig` and the JSON manifest in `schema.zig`. The composition kernels —
pure, I/O-free — live under
[`src/kernel/compose/`](../../../kernel/compose/README.md). `gist` and `relate`
are unchanged; this face forwards none of their verbs.

Contract authority for the composed verbs and the `CandidateSet` model:
[`../../../../contract/search_api.toml`](../../../../contract/search_api.toml).
