# Contributing

Thanks for looking. This page is the practical half - what to install, what to
run, and what a reviewable change looks like here. The design half is
[`README.md`](README.md): why these two questions need both engines at once, and
why composing beats piping the faces together by hand.

Two other files bound this one. Report a vulnerability privately, never in an
issue: [`SECURITY.md`](SECURITY.md). How we treat each other:
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## What this repository is, and what it is not

`blast` is the composed face, and it is deliberately thin: two verbs, and
neither engine. `provenance` re-verifies a quotation against a file's **current**
bytes. `blast` computes a live blast radius from current bytes with no
precomputed graph. Everything they stand on is imported - [`irregex`][irregex]
(the regex engines, the corpus walk, argv), [`relate`][relate] (kinship, the
codex shelf, the compose kernels), and [`gist`][gist] (the CLI chassis and the
manifest driver).

That thinness decides where an issue goes. "The radius missed an obvious
caller", "a provenance phrase pointed at the wrong file", "`--budget` trimmed
the wrong tail" - all here. "The kinship distance is wrong" is `relate`'s. "The
pattern matched the wrong span" is `irregex`'s. File it wherever you like; we
move it rather than bounce you.

Composition-as-*narrowing* is not here either, and that is on purpose: the old
`context` and `family` verbs folded into `relate`'s `--matching` flag, where
they compose with every other axis those verbs have. A proposal to add a third
verb here has to argue that it needs **current bytes**, not merely both engines.

**You need four checkouts.** This package has the only two-level path graph in
the ecosystem: its `build.zig.zon` points at `../irregex` and `../relate`,
relate's own manifest then points at `../irregex` and `../gist`, and the build
installs `../gist/include/gist.h` beside this package's header. Clone all four
as siblings:

```text
Billy-Company/
├── irregex/     ← the engine
├── gist/        ← the chassis; relate needs it, and the header install does
├── relate/      ← the compression engine
└── blast/       ← you are here
```

This is why CI checks out four repositories into subdirectories of one
workspace: `actions/checkout` refuses a path outside the workspace, and nothing
in the package is patched for CI on purpose. What builds there is the layout you
actually clone.

## Setup

| For | Install | Pinned by |
| --- | --- | --- |
| the binary | Zig **0.16.0** | `minimum_zig_version` in [`build.zig.zon`](build.zig.zon), `ZIG_VERSION` in CI |
| the Python binding | [uv](https://docs.astral.sh/uv/) | `requires-python` floor 3.12 |
| the Rust binding | rustup | `bindings/rust/rust-toolchain.toml` |
| the Go binding | Go | `bindings/go/go.mod` |
| the discipline gate | markdownlint-cli2, typos, golangci-lint | the actions in [`ci.yml`](.github/workflows/ci.yml), mirrored into `.mise.toml` |
| coverage | kcov | only for `zig build coverage`, a local instrument |

If you run [mise](https://mise.jdx.dev), that table is one command:

```bash
mise install
```

`.mise.toml` pins every row at the version CI uses and `mise.lock` carries the
checksums for all four release platforms. The pins are mirrors of the files in
the third column and never the authority, so bumping one means bumping the
other in the same commit. kcov is the exception and stays a `brew install`: it
backs a local instrument nothing gates on, and there is no package to pin.

What no lockfile can install is the siblings. blast is the composed face and
builds against `irregex` and `relate` checked out beside this repo - versions
are a package manager's job, a checkout is not.

```bash
zig build                 # ReleaseFast blast → zig-out/bin/blast, plus libblast
zig build check           # compile only - the fastest "did I break it"
zig build check --watch   # ... and again on every save
zig build test            # the unit suite plus the FFI dispatch tests
```

Note what a bare `zig build` does that `check` and `test` skip: it runs the
macOS libtool re-archive, links `libblast` against `libirgx`, and stages the
three headers. Those are the artifact a consumer receives, so run it before
claiming the install path works.

## The test loop

The Zig suite here is small on purpose - the face is a thin composition, so most
of its behavior is covered by the engine suites underneath it. That makes the
**binding** suites disproportionately important, and they all drive real
binaries:

```bash
# Build every package the suites resolve, in the checkout that owns it.
for p in irregex gist relate blast; do (cd ../$p && zig build --summary none); done

cd bindings/python && uv run pytest -q
cd bindings/go     && go vet ./... && go test ./...
cd bindings/rust   && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
```

A composed test that cannot resolve a binary **skips itself**, and a suite that
skipped everything still exits 0. That failure mode is why CI greps its own Go
output for `--- SKIP` and fails on one. If you are adding a test that needs a
binary, make it fail loudly when the binary is missing rather than returning
early.

The Rust crate is the exception and needs none of this: it is a subprocess face,
and its tests prove that a composed request lowers into an argv and that a
missing scope is a typed refusal. Neither opens a file.

## The constraints a change is held to

- **Current bytes are the whole point.** `provenance` may only surface a phrase
  the live file still holds; `blast` may not consult a precomputed graph. If a
  change makes either faster by trusting something persisted, it has changed
  what the verb means. Say so loudly or do not do it.
- **Exact and statistical evidence stay in separate fields.** Never a fused
  relevance number. A reviewer must be able to see that a twin is a compression
  result and a dependent is an exact one.
- **The kind guess belongs to the strongest definition.** Only a source file can
  declare; a definition list in prose or a key in a spec is a mention. A change
  that lets a weak shape win because it sorted first alphabetically is a
  regression even if every test still passes.
- **Two hops of reach, and no more.** [`contract/blast.ward`](contract/blast.ward)
  is the shortest contract in the ecosystem and should stay that way. If your
  change wants a third tier, the work probably belongs in one of the engines.

## What CI will check

Ten jobs in [`.github/workflows/ci.yml`](.github/workflows/ci.yml), split on
purpose - a Zig engine regression, malformed Markdown, and a poisoned workflow
are different news and deserve different red Xs. Runtime jobs assemble the
ecosystem on disk; static discipline jobs read this checkout alone and fail
before a build would matter.

| Job | What it holds |
| --- | --- |
| `engine` | `zig build check`, `test`, and the full install on Linux and macOS |
| `python` | three interpreters against one ecosystem build - 3.12, 3.13, 3.14 |
| `go` | golangci-lint, `go vet`, and `go test`, then proof no test skipped |
| `rust` | fmt, clippy, tests, and `cargo deny` over advisories, bans, licenses, and sources; the one job that needs no Zig |
| `fmt` | `zig fmt --check` over every tracked and untracked-not-ignored `.zig` file |
| `docs` | markdownlint over every page, plus US-English typo checking |
| `config` | yamllint, Taplo lint/format, and `.editorconfig` conformance |
| `python-lint` | Ruff lint and format over the binding and maintenance tools |
| `actions-sec` | zizmor over workflows and Dependabot configuration |
| `version` | every published manifest still agrees with `build.zig.zon` |

The separate [`windows`](.github/workflows/windows.yml) workflow runs the Zig
suite, composed CLI smoke, and idempotent installer on native x64 and arm64
Windows. Cross-compilation is not treated as runtime evidence.

Run the formatter before you push - `zig fmt` reflows column-aligned literals,
so a rename that shrinks the widest cell leaves rows you never touched one space
too wide:

```bash
zig fmt .
```

## Every change carries its own news

Write a towncrier fragment in the **same PR**:

```bash
towncrier create '+<slug>.<type>.md'    # types: added changed deprecated removed fixed security
```

Fragment names read like the sentence they are:
`+the-composed-tests-find-relate-by-themselves.fixed.md`. The leading `+` tells
towncrier there is no issue number attached. The body is prose for a person
reading release notes - what changed and what it means for them, not a
restatement of the diff.

Skip it only for comment-only, format-only, or genuinely invisible internal
work. When unsure, write it.

## The version is written once

You will not edit a version by hand, and you should not try. `build.zig.zon`'s
`.version` is the only place this package's number is written:

- **Zig** reads it through a build option, which is what `blast --version` and
  the `--schema` manifest answer with;
- **Rust** reads `CARGO_PKG_VERSION`;
- **Python** reads its installed distribution metadata.

That leaves `Cargo.toml` and `pyproject.toml`, which cannot import anything.
Both carry an `x-release-please-version` marker, `release-please-config.json`
lists them, and one merged release PR moves all three in a single commit.
`python3 tools/version_parity.py` proves they agree, and fails just as loudly on
a marked line the release config was never told about. It runs in CI.

The three siblings this composes - `irregex`, `relate`, and `gist` - are each a
different axis, pinned as dependencies and never mirrored here. This face used
to print the engine's version as its own - 1.0.0 against a package at 0.1.0 -
which is exactly what the arrangement above makes impossible.

**Cutting a release.** Merge the release PR that release-please opens; that tags
`vX.Y.Z` and `release.yml` publishes the wheels. towncrier owns `CHANGELOG.md`,
so run `towncrier build --version <the version the PR bumps to>` and push it
onto the release branch - the tag and the notes should land together.

## Commits and pull requests

Commit subjects here are a conventional prefix plus a lowercase sentence that
says what changed, in the voice of the change rather than the ticket:

```text
fix: the binary signs its own name
feat: libblast and the blast binary
ci: the workflow fetches what blast composes
```

Prefixes in use: `feat` `fix` `perf` `refactor` `docs` `test` `build` `ci`
`chore`. Keep the subject under about 72 characters and put the reasoning in the
body, where reviewers and `git log` both find it.

For the pull request: one concern per PR, describe what would have caught the
bug if it had existed, and fill in the template. Reviews here ask three
questions more than any others - *what proves this?*, *what does it cost?*, and
*what did it replace?* Answering them in the description saves a round trip.

If you removed something that a newer path superseded, remove it completely.
Leaving the old implementation beside the new one to be safe is how a codebase
grows two spellings of the same bug.

## Architecture is machine-checked

Zig has no visibility rules between files in a package, so every boundary the
READMEs describe would be convention.
[`contract/blast.ward`](contract/blast.ward) is the machine-checkable half. If
your change needs a new import edge, edit the contract in the same commit and
say why in the exception. Do not route around it.

The seam has the same property.
[`contract/compose.toml`](contract/compose.toml) declares the candidate set, the
unit, the scoring split, the two verbs, and the composed spellings that retired
into `relate --matching`. The rows the verbs return are substrate and are
declared in `irregex/contract/analytic.toml` with every other analytic row -
which is worth knowing before you invent a row shape here.

## Licensing

This project is Apache-2.0. There is no CLA: contributions are accepted under
the same license the project already carries, per the inbound=outbound norm in
section 5 of the license itself.

Nothing third-party is bundled here; [`NOTICE`](NOTICE) says so and points at
the packages underneath, whose own notices carry what they do bundle. If you
bring in code, data, or an idea from another tool, credit it at the call site
and in the NOTICE of whichever package ends up holding it.

## A small thing that makes diffs readable

Git ships hunk-header patterns for Go, Python, Rust, C, and Markdown, and
[`.gitattributes`](.gitattributes) already binds them. Zig has none, so teach
your own git what a Zig declaration looks like once:

```bash
git config diff.zig.xfuncname '^((pub |export |inline |noinline )*fn .*|(pub )?(const|var) [A-Za-z_].* = (struct|union|enum|opaque)\b.*)$'
```

The attribute is already in place; until you run this, it simply falls back to
git's default.

[irregex]: https://github.com/The-Billy-Company/irregex
[relate]: https://github.com/The-Billy-Company/relate
[gist]: https://github.com/The-Billy-Company/gist
