# blast - blast radius and provenance for Python

Two questions, both answered from the bytes on disk right now:

- **What breaks if I change this symbol?** The live blast radius, with no
  precomputed graph, so a file someone saved thirty seconds ago counts.
- **Where did this pasted text come from?** Quote attribution re-verified
  against each source's current bytes, so a citation you get back is one you
  can actually follow.

```bash
pip install blast-search
```

The distribution is `blast-search`; the import stays `blast`. The bare name on
PyPI belongs to an unrelated author, so this is the same split bs4, PIL, and
cv2 already ship.

## Blast radius

```python
import blast

radius = blast.blast("SessionStore")

print(radius.symbol, radius.kind)
for site in radius.definitions:
    print("defined", site.path, site.line)
for ref in radius.dependents:
    print("used by", ref.path, ref.line, ref.enclosing)
```

The report separates what it knows from what it suspects, and never fuses them
into one number. `definitions`, `dependents`, and `dependencies` are exact;
`twins` (compression kin of the seed's file, so co-edit risk) and `ripple`
(second-hop callers in the same language) are statistical. `comments` catches
the mentions in prose, because that is where the stale docs and the TODOs live.

That split is a property you can read off directly, which is usually what a
program wants:

```python
radius.paths        # the whole edit set, most load-bearing first
radius.exact_paths  # only files that provably name the symbol
```

Scope is the whole corpus by default, since a blast radius that stopped at a
directory would lie. Narrow it with `roots` when you know the change is
contained, and use `budget` as a soft cap that trims the lowest-priority tail
into `stats.omitted` rather than silently truncating.

```python
radius = blast.blast("SessionStore", roots=["services/backend"], budget=4000)
if radius.stats.omitted:
    print("trimmed", radius.stats.omitted)
```

## Provenance

```python
for cite in blast.provenance("const fd = std.posix.openat(std.posix.AT.FDCWD"):
    print(cite.source, cite.line, cite.verified, cite.text)
```

`verified` is the whole point. [`relate quote`](https://pypi.org/project/relate-search/)
attributes phrases off the codex shelf, which is a snapshot and can therefore
name a line that no longer exists. blast re-reads the file and re-finds the
phrase, so `verified=False` is drift being reported rather than hidden.

## What it needs

The `blast` binary on `PATH` (or `$BLAST_BIN`), which
[the repository](https://github.com/The-Billy-Company/blast) builds with
`zig build`. `provenance` reads relate's codex shelf, built by
`relate.atlas_index(shelf=True)`.

## Why compose instead of piping two tools

Piping an exact search into a similarity tool throws the match information away
between the steps and then pays whole-corpus statistical noise: a changelog
that never matched still ranks high on coverage. Composing keeps the exact and
the statistical evidence in separate fields on one answer.

Composition-as-_narrowing_ lives next door as the `matching` argument on
`relate.similar` / `relate.families` / `relate.pack`. What is here is the pair
of questions that need current bytes instead of a narrowing.

## The rest of the family

| Package | Question |
|---|---|
| [`gist-search`](https://pypi.org/project/gist-search/) | where is this exact pattern? |
| [`relate-search`](https://pypi.org/project/relate-search/) | what resembles this, and what repeats? |
| **`blast-search`** | what breaks if I change this symbol? |
| [`irregex`](https://pypi.org/project/irregex/) | the linear-time regex engine underneath all three |

## Development

```bash
uv sync --group dev
uv run pytest
```

Depends on `irregex` and `relate-search` (path sources for local checkouts;
PyPI for published wheels). Behavioral tests also pull `gist-search` as a dev
oracle.
