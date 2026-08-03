# blast: A Blast Radius Tool for Coding Agents

- [Overview](#overview)
- [Why this over grep?](#why-this-over-grep)
- [Support](#support)
- [Install](#install)
- [Reading a Report](#reading-a-report)
  - [Seed](#seed)
  - [Dependents](#dependents)
  - [Dependencies](#dependencies)
  - [Comments](#comments)
  - [Twins and Ripple](#twins-and-ripple)
- [What Outranks What](#what-outranks-what)
- [Recipes](#recipes)
- [Provenance](#provenance)
- [Contracts](#contracts)
- [Build and Test](#build-and-test)
- [Where This Came From](#where-this-came-from)

## Overview

An agent about to change a symbol has one question, and it is not "where does
this string appear". It is "what breaks". Those are different questions, and a
grep answers only the first.

`blast SYMBOL` answers the second. It reports where the symbol is declared,
which functions lean on it, what it leans on in turn, the comments that
describe it and will be wrong once you edit it, and the files that historically
move alongside it.

Every edge is derived on demand from the corpus as it is right now. There is no
project model to configure and no graph to rebuild, so a file another agent
saved a second ago is already in the answer, and a symbol in a language nobody
taught the tool about still resolves.

That last part is the trade. A compiler front end would be more precise on the
one language it was built for; blast is parser-free and reads byte shape, so it
covers every language in a polyglot tree at once and pays for it with
heuristics it is required to label rather than hide.

## Why this over grep?

Use blast when you are about to change code and want the change's footprint
before you make it. It is built for an agent editing an unfamiliar tree, and
for a human doing the same thing at 2am.

Reach for [gist](https://github.com/The-Billy-Company/gist) instead when you
know the pattern and want the matching lines. gist is a ripgrep-parity indexed
search, and a blast report is a much more expensive thing to compute than the
list of lines you actually asked for.

Reach for [relate](https://github.com/The-Billy-Company/relate) instead when
the question is about similarity rather than a symbol - what resembles this
file, what repeats across the tree, which files jointly explain a task.

Reach for a language server instead when you have one, the tree is one
language, and the project builds. blast is what you use when any of those three
is false.

## Support

File a bug against this repository when a report is wrong: a call site blast
missed, a row it invented, or a definition it failed to find. Paste the symbol
and the `--json` report, which is the whole of what blast believes.

File it against [irregex](https://github.com/The-Billy-Company/irregex) when
the fault is in matching itself - a pattern that should match and does not, or
a Unicode boundary that reads wrong. irregex is the engine underneath all three
faces, and a matching bug reproduces there in isolation.

File it against relate when the fault is in similarity - a twin that is not a
twin, or a provenance phrase attributed to the wrong file. The kinship and
attribution kernels live there; blast only composes them.

Report a vulnerability through the process in [SECURITY.md](SECURITY.md), never
as a public issue.

## Install

Build from source with a Zig toolchain, or take the CLI from a release.

```bash
zig build            # blast → zig-out/bin/blast
```

On Windows, the installer builds `blast.exe`, places it in a per-user directory,
and adds that directory to the user PATH without elevation:

```powershell
.\install.ps1
```

The binary is standalone for the `blast` verb. `provenance` additionally reads
the codex shelf that relate writes, so install
[relate](https://github.com/The-Billy-Company/relate) if you want attribution.

## Reading a Report

A report has six sections, and they are ordered by how likely you are to have
to edit them. Run it on any symbol to see the shape.

```bash
blast runBlast
```

Every section is capped, so a report cannot flood a context window however
popular the symbol is. Pass `--budget N` to cap it harder in approximate
tokens; what gets trimmed is counted into `stats.omitted` rather than silently
dropped.

Exact evidence and statistical evidence never mix. A line number and a
def/use classification come from matching the bytes; a twin distance comes from
compression kinship; they stay in separate fields and are never fused into one
relevance score you cannot take apart.

### Seed

The seed is where the symbol is declared, plus a guess at what kind of thing it
is. A symbol declared in several places lists all of them, strongest
declaration first.

Only a source file can declare anything. A definition list in prose and a key
in a config file both wear shapes that read like declarations, so they are
recorded as mentions and can never pose as the symbol's home.

### Dependents

Dependents are the references, and they are the reason you ran the tool. Each
row names the file, the line, the enclosing function when there is one, and
whether that line uses the symbol or redefines it.

A reference outside a function body counts. Registries, dispatch tables, export
lists, route maps, and dependency-injection wiring are exactly the edges that
break a build when a name moves, and they live at file scope where a
function-shaped search cannot see them.

A reference inside a string literal counts too, marked `str`. Names get wired
by string in reflection, in SQL, and in route tables, so dropping them loses
real edges - but a string is weaker evidence than a call, and the report says
which it found rather than flattening the two.

### Dependencies

Dependencies invert the question: what does the seed itself lean on. This is
the list of things whose change would break *it*, which is what you want when
the symbol is misbehaving rather than moving.

Resolution is deliberately conservative. The seed's own parameters and locals
are excluded, a qualified `head.member` resolves only inside the module its
head names, and a name that a whole package declares is treated as ambient
rather than as a dependency.

Only a function has a body to lean on anything, so a type or a value reports no
dependencies at all rather than reporting the neighboring words of its
declaration.

### Comments

Comments that mention the symbol are the documentation your edit is about to
falsify. This is the stale-doc surface, and it is the part of a change that
review catches last and users notice first.

A mention inside a comment is never counted as a dependent, and a mention
inside a string is never counted as a comment. The same parser-free lexer
decides both, so the two sections cannot disagree about where a comment ends.

### Twins and Ripple

Twins are files that compress well against the seed's file - near-duplicates,
forks, and parallel implementations. They are a co-edit signal rather than a
dependency: nothing references anything, but historically these files move
together, so a change here usually wants the same change there.

Ripple is the second hop. It names files that call the seed's dependents, so a
change that propagates through one of them can reach here, and each row records
which dependent bridges the two.

Both are statistical and both are labeled as such. A twin carries its
distance so you can see how strong the claim is, and a ripple row carries its
bridging name so you can dismiss it in one read.

## What Outranks What

Authored code outranks generated code everywhere in the report. A generated
file is regenerated from a contract, so it is almost never an agent's edit
target - and left unranked it dominates, because codegen repeats a symbol in
every stub, descriptor, and client shim it emits.

Generated rows are tagged `gen` and sorted last rather than deleted. Sometimes
the generated call site is the evidence you wanted, and a tool that silently
hid it would be lying about the radius.

Ranking runs before the caps, which is the part that matters. It means a
symbol with six authored call sites and four hundred generated ones reports the
six, where a first-come report would fill its entire budget with stubs and
never mention the code you have to change.

Codegen is recognized from a generated-by header marker first and a filename
convention second. Both are liberal by design: a false demotion only reorders a
report, and no signal here can hide a match.

## Recipes

Ask what a rename would touch, before you rename anything.

```bash
blast WalletService
```

Narrow to one subtree when you already know the change is local. Scope is
optional because a blast radius that stopped at a directory would lie, so
narrowing is something you must ask for.

```bash
blast Session services/backend clients/web
```

Take the report as one JSON object when an agent is going to read it rather
than a person. The schema is stable, every section is a named key, and nothing
is truncated without being counted.

```bash
blast Session --json
```

Cap the report when context is tight. The seed, the stats, and the notes are
the spine and are never trimmed; the tail goes first, cheapest evidence first.

```bash
blast Session --budget 800
```

Ask what the tool can do, in a form written for a machine reader with no other
documentation.

```bash
blast --schema
```

## Provenance

`blast provenance TEXT` answers a different question with the same discipline:
where did this text come from, and does the tree still contain it. It is the
verb for a snippet you were handed and are about to paste.

Attribution is relate's, verification is blast's. relate attributes each
maximal verbatim phrase to one exemplar file on the codex shelf, then blast
re-reads that file's current bytes and re-finds the phrase exactly.

A phrase surfaces only if the live file still holds it. That is the whole point
of doing this here rather than in relate: an attribution against a shelf built
yesterday can name a line that has since been deleted, and blast will not
report one.

```bash
blast provenance 'const fd = std.posix.openat(std.posix.AT.FDCWD, path'
```

Raise `--min-phrase` above its twelve-byte floor to drop trivial quotes, and
`-C` to widen the context lines around each located phrase. The shelf comes
from `relate index --shelf`, and provenance says so plainly when it is missing
rather than reporting an empty answer.

Note the two verbs shape their JSON differently, because their answers are
different objects. A blast report is one JSON object; provenance emits NDJSON,
one row per attributed phrase.

## Contracts

Results go to stdout and diagnostics go to stderr, always. A run you piped and
a run you watched produce the same bytes on stdout, so a captured report and a
read one can never disagree.

Exit codes are ripgrep-shaped. Zero means the verb ran, two means a usage,
parse, or missing-shelf error, and a report with no rows is still a zero.

A name that used to be a verb is a diagnostic, never a silent alias. `blast
context` and `blast family` folded into relate's `--matching` modifier, and
invoking either prints the invocation that replaced it and exits two - so a
pinned script fails loudly instead of drifting onto semantics that moved.

`blast --schema` is the machine-readable contract: every verb, every flag, its
type and default, the exit codes, and the notes. Read it rather than parsing
`--help`, which is written for a person, and note that `--version` reports this
package's own number rather than the engine's.

## Build and Test

Build, test, and typecheck with the Zig toolchain.

```bash
zig build          # the blast binary → zig-out/bin/blast
zig build test     # the unit suite
zig build check    # compile-only
```

Builds are ReleaseFast unless `-Dcli-optimize` says otherwise. The suite here
is deliberately small: this package is a face over engines that carry their own
much larger suites, so most of blast's behavior is proven underneath it.

The package's import topology is machine-checked by
[`contract/blast.ward`](contract/blast.ward), which allows two hops of reach
and no more. The face lives in
[`src/surface/face/blast/`](src/surface/face/blast/) and imports everything
else: irregex for engines, corpus, and argv; relate for kinship, the shelf, and
the composition kernels; gist for the CLI chassis.

## Where This Came From

blast was extracted from a package path inside a private monorepo, cut at
`ce430bbaab`. It was briefly named irregex, which is why that name now belongs
to the engine package rather than to a binary.

Development uses sibling checkouts wired by `build.zig.zon` path dependencies;
releases pin a url and a hash. The license is Apache-2.0, matching every
package underneath it.
