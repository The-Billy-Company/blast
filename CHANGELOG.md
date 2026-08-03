# Changelog

All notable changes to `blast` (the composed face; ships the `irregex`
binary) are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions track
`build.zig.zon`.

<!-- towncrier release notes start -->

## [1.0.0] - 2026-08-02

### Added

- A fifth CI job, and it checks the one formatter nothing here was checking.
  The
  Rust crate already had `cargo fmt --check` inside its own job; Zig, which is
  what the face and the FFI are written in, had nothing.

  That gap is not theoretical. `zig fmt` lays a column-aligned multiline
  literal
  out as a padded grid, so a rename that shrinks the widest cell in a column
  leaves every row beneath it one space too wide — in files nobody opened. The
  sibling substrate shipped exactly that and no gate said a word. blast owns
  seven Zig files, which is the size of tree where this is easiest to skip and
  easiest to let rot quietly.

  Its own job, for the reason the other four are: a formatting nit and an
  engine
  regression should not arrive as the same red X. It is the cheapest job here
  by
  a distance, and the only one that needs no ecosystem at all — even `rust`,
  which
  skips the builds, still wants irregex on disk for a path dependency. This one
  wants a single checkout, because reading files is not configuring a build. It
  pins the same Zig everything else builds with, since the formatter's output
  is
  a property of the compiler release — a different Zig is a different grid.

  The file list is enumerated with `git ls-files -co --exclude-standard
  '*.zig'`
  rather than written out, which matters more here than seven files suggests:
  all
  of it lives under one subtree today, and a path list would quietly stop
  covering
  the day it does not. Tracked plus untracked-not-ignored leaves out exactly
  the
  ignored trees, `.zig-cache` and the fetched `zig-pkg/` with its own
  `build.zig`,
  so the exclusions live in `.gitignore` where someone can read them. The one
  piece that looks like belt-and-braces is the existence test on each path, and
  it
  is not: `git ls-files` still names a tracked file you have deleted, so
  without
  it a mid-edit working tree fails the gate with `FileNotFound` and teaches
  everyone to ignore it.
- Apache-2.0, matching the packages underneath it. Nothing third-party is
  bundled in a face this thin, so NOTICE carries only the copyright and points
  at `irregex`, `relate`, and `gist` for what they bundle.
- CI, four jobs: the Zig engine on Linux and macOS, the Python binding across
  3.12 to 3.14, the Go module, and the Rust crate. Four rather than one because
  a
  clippy nit and an engine regression are different news.

  The interesting part is the checkout. blast composes two engines it does not
  contain, and one of those composes a third, so a bare clone cannot even
  configure: this package wants `../irregex` and `../relate`, relate then wants
  an
  `../irregex` and `../gist` of its own, and the build installs gist's header
  beside ours. `actions/checkout` refuses to write outside the workspace, so
  the
  workflow checks blast itself into a subdirectory and puts the other three
  packages beside it; every relative path resolves at both levels then, because
  that flat layout is the one each repo already assumes and the one a laptop
  already has. relate is not a public repository, so its checkout reads a token
  secret; the two public packages fetch without one.

  The Python and Go jobs both build the engines before they run anything, since
  every composed test is guarded on a resolvable binary and would otherwise
  skip
  its way to a green tick over nothing.
- Every one of these repositories has shipped a `deny.toml` since the crate
  existed, and not one of them ever ran it. Four checks were written down and
  none enforced: a RustSec advisory against anything in the graph, the banned
  crates that would mean a regex binding grew a TLS stack or an async runtime,
  the license allowlist, and which registries a crate may come from. A policy
  nobody runs is a policy nobody has.

  So `cargo deny check` is a step in the `rust` job now, on a prebuilt binary
  rather than the Docker action - that action takes a repo-root-relative
  manifest path and the checkout layout differs in every repo here, so a plain
  step inheriting the working directory is both shorter and harder to get
  wrong.

  It passed first try in all four, which is the good version of this news and
  also exactly why it needed wiring: nothing was wrong, so nothing would have
  said when something became wrong. One thing needed saying out loud. The
  allowlist is a policy - the licenses this project accepts - not a snapshot of
  today's graph, so most entries go unmatched and cargo-deny warns once each.
  Shrinking the list to silence that would invert the point, because the next
  permissively-licensed crate would fail and get fixed by widening the list
  again, one entry at a time, with nobody deciding anything.
  `unused-allowed-license = "allow"` says that instead.
- Markdown, spelling, YAML, TOML, EditorConfig, Python, Go, Rust, and workflow
  security now fail in CI under configs written for this repository rather than
  rules inherited from the monorepo it left.
- The composed face's binary is `blast` again (it had kept the engine's name
  `irregex` after the ecosystem split), and `libblast` + `include/blast.h` ship
  `blast_run` for the four composed verbs. They decline in-process today
  (`.stale` → CLI) exactly as they did under `gist_run`; the win is that a host
  links the compose library for compose questions, not the search library.
- The repository had a license, a NOTICE, and five CI jobs, and nothing that
  told
  a contributor how to work in it. It now carries the paper trail a public
  project is supposed to have.

  [`CONTRIBUTING.md`](CONTRIBUTING.md) is the practical half, and it leads with
  the thing that actually stops people: this package has the only two-level
  path
  graph in the ecosystem, so it needs four checkouts beside each other, not
  one.
  It says what each toolchain is pinned by, why a bare `zig build` proves
  something `check` and `test` do not, and why a composed test that cannot
  resolve
  a binary skips itself into a green run - which is why CI greps its own output
  for a skip and fails on one. It also states the constraints a change is held
  to:
  current bytes are the whole point, exact and statistical evidence never fuse
  into one number, and the ward contract stays at two hops of reach.

  [`SECURITY.md`](SECURITY.md) names the threat model. The corpus is the
  attacker,
  as everywhere - but these two verbs are used to *decide* things, so the
  vulnerabilities here are shaped differently: a phrase that survives the bytes
  that justified it, a radius that hides a real dependent behind a
  complete-looking
  answer, a compression twin presenting itself as an exact dependent. It says
  what
  is not one, too: a blast radius is corpus-wide by nature, and costing what a
  corpus costs is arithmetic.

  [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) is Contributor Covenant 3.0, with
  reports going to a maintainer address rather than a committee that does not
  exist. Of the four repositories this is the one where the crediting clause is
  not boilerplate: a tool that attributes other people's writing for a living
  has
  no business being careless about attributing other people's work.

  The dotfiles are small and load-bearing. `.editorconfig` restates what each
  formatter already emits, so an editor save and `zig fmt --check` cannot
  disagree. `.gitattributes` normalizes line endings - this face re-finds a
  phrase
  in a file's current bytes, and a CRLF checkout would change the bytes it
  verifies against - marks resolver output as generated, binds the hunk-header
  drivers, and deliberately declines `export-ignore`, which would invalidate
  every
  url+hash pin that already exists. `.mailmap` collapses two author spellings
  into
  one person.

  On GitHub: `CODEOWNERS` routes review, Dependabot watches the one ecosystem
  it
  can actually resolve here, a pull-request template asks whether the change
  still
  reads current bytes, and the issue forms send kinship questions to relate,
  pattern questions to irregex, and daemon questions to gist before anyone
  spends
  an afternoon in the wrong repository.
- Windows is now a first-class runtime target. `install.ps1` builds and places
  `blast.exe` on the per-user PATH without elevation and can be rerun safely.
  Native x64 and arm64 CI assemble all four sibling repositories, execute the
  Zig suite and a composed query, and exercise the installer instead of
  treating a cross-compile as runtime evidence.
- `.mise.toml` and a committed `mise.lock` turn the Setup table in
  `CONTRIBUTING.md` into `mise install`. Zig, Rust, Go, Python, and uv are
  pinned at the versions CI already uses, with checksums recorded for all four
  release platforms. The pins are mirrors of `build.zig.zon`,
  `bindings/rust/rust-toolchain.toml`, `bindings/go/go.mod`, and the `--python`
  CI hands uv - never the authority, so a bump has to touch both files or
  nothing resolves the way it reads.

  The discipline gate's binaries are pinned the same way, and for the same
  reason a red X should mean the same thing in both places: markdownlint-cli2,
  typos, and golangci-lint, each at the version its CI step already resolves.
  Two of those come from the versions their actions bundle, which is why the
  markdownlint action moved up to v24.1.0 in the same pass - it had been
  running markdownlint-cli2 0.22.1, one minor behind the 0.23.1 pinned here.

  The other half of the gate is deliberately not here. Ruff, yamllint, taplo,
  editorconfig-checker, and zizmor arrive through `uv run --no-project --with
  <pkg>==<version>`, which is a version authority already - written in the
  workflow, repeated verbatim in `CONTRIBUTING.md`, and needing no install step
  at all. A second pin for those could only ever disagree with the first.

  Two things are deliberately left out. kcov backs `zig build coverage`, a
  local instrument nothing gates on, and it has no package to pin, so it stays
  a `brew install`. And the sibling checkouts are not versions at all: blast is
  the composed face and builds against `irregex` and `relate` sitting beside
  this repo, which are things you clone rather than things a lockfile resolves.
- `blast` is its own package: the composed face extracted from a private
  monorepo package path at ce430bbaab. It
  ships the `blast` binary (`blast` / `provenance`) over the `irregex`,
  `relate`, and `gist` packages; the composed engines live in relate's compose
  tier, and the package name frees `irregex` for the library.
- `contract/compose.toml` is blast's own contract, carrying the three tables
  that
  describe what this package does: `[compose]` (the exact-before-statistical
  seam
  — candidate set, comparison unit, distinct, scoring, scope, blast tiers),
  `[compose.verbs]` (`provenance` and `blast`), and `[compose.retired]` (the
  two
  composed verbs that became relate's `--matching` flag, with the coaching that
  sends a caller to the new spelling).

  They were declared in `gist/contract/surface.toml`, which had no claim on
  them:
  gist does not answer either verb. The rows they return stay substrate,
  declared
  with every other analytic row in `irregex/contract/analytic.toml`, and
  `blast_run` and its op codes stay in that file's `[analytic.producers]` and
  `[analytic.verbs]` — op numbers are ecosystem-wide on purpose.

  The verbs' `argv` had gone stale in the move here: both still spelled
  `irregex provenance` / `irregex blast` from before the binary was renamed.
  They
  say `blast` now, which is what the binary is called.

### Changed

- Every package index this project publishes to now shows the repository's own
  `README.md` as the project's page, rather than the short one kept beside each
  binding. PyPI and crates.io are where most people meet this project first,
  and
  they were being shown a page about the Python binding's verbs - not the
  composed face, or why it needs both engines at once.

  The README could not simply be pointed at, because a relative link resolves
  against whatever page displays it. `src/surface/face/blast/README.md` is
  correct on GitHub and a 404
  under `pypi.org/project/blast-search/`. crates.io is the worse of the two: it
  rewrites
  relative links against the crate's own subdirectory, so the same path becomes
  a
  well-formed URL into `bindings/rust/` pointing at a file that was never
  there,
  and nothing looks broken.

  So `tools/registry_readme.py` is now the one rewriter both ends share. It
  absolutizes every relative target against the `repository` URL the manifest
  already declares, in the form that serves what the target is - `raw` for an
  image, `tree` or `blob` chosen by what the path is on disk - and a target the
  repository does not contain fails the build instead of publishing a dead
  link.
  GitHub's `> [!NOTE]` alert, which renders as literal text anywhere else, is
  lowered to a bold lead line. Headings need no help: both renderers rewrite
  in-document anchors to match the ids they mint, so the table of contents
  arrives
  intact.

  Python gets it through a Hatchling metadata hook, so the corrected page
  exists
  only inside the artifact. Cargo has no metadata hook, so `readme` now points
  at
  a gitignored `bindings/rust/PROJECT_README.md` that the same tool mints at
  package time - `cargo package` fails loudly if it was never generated, and
  `cargo build` never reads it. Both indexes end up with a byte-identical page.

  An sdist is the one artifact with no repository above it, so it carries the
  corrected README beside the sources and a source build reads that, rather
  than
  being asked for a file the archive does not contain.

  Go needed no rewriting - pkg.go.dev renders the README at the module root and
  resolves its links against the repository - but a dead one there is still a
  dead
  link on the module's landing page, and a Go module has no build step to catch
  it. `--check` now proves those targets resolve too, on every commit.

  The README stays written for the repository it lives in.
- Lowered the Go module floor from `go 1.26.3` to `go 1.24`, matching the other
  three packages. The higher floor existed only for `new(0.6)` — Go 1.26 sugar
  for the address of a literal — in the compose suite's optional-knob fixtures;
  a small `ptr[T any]` helper replaces it. No production file needed anything
  past 1.24.
- Seven READMEs carried a `doc_radar:` block - YAML frontmatter on most, an
  HTML
  comment on the rest - declaring path, count, and sentinel assertions for a
  freshness gate that lives in the monorepo this package was split out of. That
  gate was never ported here, so every one of those blocks was inert. On
  `bindings/python/blast/README.md` it was also the first thing a PyPI reader
  would meet, where the renderer turns a YAML preamble into a horizontal rule
  followed by a heading made of raw YAML. They are gone, and the prose below
  each
  is untouched.
- The Go compose tests stopped guarding themselves one at a time. A `TestMain`
  resolves both engines the package composes - `relate` and `blast` - before
  any
  test runs, and a package that cannot find one fails outright.

  Three of the five tests opened with `requireEngine`, which skipped when
  discovery returned nothing. In a package whose entire subject is two engines
  running against each other, every one of those skips is the suite reporting a
  clean pass over the thing it exists to check; the CI workflow already had to
  build both engines up front precisely so the tests would not skip their way
  to a
  green tick. That is a fact the harness should hold, not something each test
  re-negotiates.

  So the harness holds it. Both binaries are resolved once at package start,
  the
  paths are stored, and a miss prints which engine was wanted and what the
  resolver looked at before exiting non-zero. The three guards are deleted and
  the
  tests assert instead.

  Worth noting what this needed underneath: blast composes two engines it does
  not
  contain, so resolving `relate` from here means finding a *sibling* checkout.
  The
  Go binding could already do that. The Rust one could not, which is a separate
  fix in irregex.
- The Python binding declared `requires-python = ">=3.14,<3.15"`, which was the
  monorepo's pinned interpreter wearing the costume of a library requirement.
  It is now `>=3.12`, tracking the `irregex` substrate this package cannot
  import without, with no upper bound.

  The lower bound locked out 3.12 and 3.13 for no reason the source supports;
  the binding imports and runs there. The upper bound was the worse half,
  because it fails in the future: `<3.15` turns the day CPython 3.15 ships into
  the day this package stops resolving.
- The Python distribution is `blast-search`; the import is still `blast`.
  `blast`
  on PyPI belongs to an unrelated author - a web music player - so the name was
  never available to publish under, and, worse, a plain `pip install blast`
  fetches that stranger's package into a tree that then imports `blast` and
  gets
  whatever it contains. Splitting the two names closes that: `pip install
  blast-search`, `import blast`, which is the same shape bs4, PIL, and cv2
  already
  ship, and the same split `gist-search` and `relate-search` made next door.
  Only
  `[project].name` and the dependency spelling moved; the package directory,
  the
  wheel's `packages` entry, and every `import blast` in the tree are untouched.

  The repository also gets a release workflow, which is what forced the
  question.
  It publishes one `py3-none-any` wheel plus a genuinely buildable sdist
  through
  PyPI Trusted Publishing on a `v*` tag, and refuses to publish a tag that does
  not name the declared version. Two gates run before anything leaves: the
  built
  wheel must declare both `irregex` and `relate-search` as index-resolvable
  requirements, because the `[tool.uv.sources]` paths that make a local
  checkout
  work never reach core metadata and a wheel missing the sibling imports fine
  right up until the first composed verb runs; and the artifact is installed on
  the declared 3.12 floor from a directory that is not the project. That second
  gate also enforces the ordering this face cannot avoid - the resolver goes to
  the index for `relate-search`, so a blast release cannot land ahead of the
  sibling it needs. The binary is not published: the Zig package is consumed
  through a tag's tarball, and the CLI is built from source.
- The README opened by describing blast as a composed face over two engines.
  That is true of the implementation and useless to the reader, who does not
  care which kernels are underneath and does care whether this thing tells them
  what their edit will break.

  It now opens on the question the tool answers - what moves if I change this
  symbol - and walks the six sections of a report in the order they print.
  Composition is still explained, one layer down, where it belongs.

  The restyle follows the house shape: no tables, no horizontal rules, one idea
  per paragraph, and the first sentence of each section carrying the section.
  `provenance` keeps its own section rather than sharing top billing, because
  it answers a different question and a reader looking for blast radius should
  not have to sort that out.
- The docs and the compose contract stopped citing the private monorepo this
  was
  split out of. `blast.blast("WalletService")` was the first line of the Python
  package docstring and the example in `contract/compose.toml` narrowed on the
  same name; neither resolves for anyone who does not already have that tree,
  and
  a blast radius example is worthless if the reader cannot picture the symbol.
  It
  is `SessionStore` now, which asks the same question of the same machinery.

  The provenance note no longer quotes the internal package path it was cut
  from -
  the commit is the part that can actually be checked - and the scope section
  warns
  about sweeping `vendor/`/`upstream/` rather than `.etc`, which was another
  convention that did not survive the move out.
- The engine's caller-facing name shortened from `irregex` to `irgx`, and this
  face followed it everywhere it names the substrate. `<irgx.h>` is the header
  `blast.h` includes, `irgx_*` is the symbol prefix it declares against,
  `irgx::` is what the Rust binding imports, and `irgx_ffi` is the build tag
  that turns on the Go in-process tier. The project, the repo, and the Zig
  module are all still `irregex`; what changed is the identifier a caller
  types, which is exactly the set that freezes at v1.

  Linking followed in the same window, because leaving it behind would have
  meant naming the old library on the linker line while including `irgx.h` to
  call `irgx_compile()`. The substrate is `libirgx.{dylib,a}` now and
  `libblast` links `-lirgx`. Every C library in wide use keeps the linker line,
  the header, and the symbol prefix spelled identically, since the linker line
  is the first thing a consumer types and the last thing they want to look up.
  The status codes moved with the header that declares them: `IRGX_OK` /
  `IRGX_STALE` / `IRGX_INVALID`. Rebuild clean, because a renamed library file
  fails at load time rather than compile time, so a warm build directory can
  hide it.

  Untouched on purpose: the `irregex` Zig module this face imports, the Go
  module path `github.com/The-Billy-Company/irregex/bindings/go`, the crates.io
  and PyPI identities, and the `blast` CLI's own verbs. `blast blast` and
  `blast provenance` were `irregex blast` and `irregex provenance` back when
  this binary carried that name, and the prose describing that history still
  says so.
- The shared artifact home moved from `.local/gist-verify/` to `.gist/`. blast
  writes none of it, but `blast` and `provenance` read all of it - the trigram
  index, the kinship atlas, and the codex shelf the sibling binaries build - so
  the move is as visible here as anywhere. `.local` was the monorepo's
  machine-local scratch convention and means nothing outside it; `.gist` names
  itself the way `.git`, `.ruff_cache`, and `.mypy_cache` do, and it reads
  correctly against the `GIST_DIR` override that was always the real knob.

  This orphans whatever you already built. Nothing migrates and nothing is
  deleted; the old directory just stops being consulted, so the first
  `provenance`
  after this lands has no shelf to read and says so. Regenerating is cheap -
  `gist index` is about 3 seconds and `relate index` about 4 on a full tree -
  and
  `GIST_DIR=.local/gist-verify` pins the old location if you would rather not.

  `.gist/` is gitignored here now, alongside `upstream/` for clones kept to
  study.
- This package answers two questions and the metadata described neither of
  them.
  "Importable Python API for blast composed search verbs" tells a reader
  nothing:
  "composed verbs" is how the thing is built, not what it is for, and a person
  looking for this is searching "blast radius", "impact analysis", "what breaks
  if
  I change this", or - for the other half - "provenance", "code attribution".

  Both vocabularies are in the keywords now, the summary asks the questions in
  plain words, and the README h1 does the same instead of being the bare word
  `blast`. The repository description also stopped claiming it ships the
  `irregex`
  binary; it has shipped `blast` since the rename gave `irregex` back to the
  engine package, and the description had not caught up.

  The Python binding's README was twelve lines of contributor notes and would
  have
  been the whole PyPI page. It is a real one now, with worked examples for both
  verbs. Two details it gets right that the old prose did not: `twins` and
  `ripple` are flat attributes on `Blast`, not nested under a `tangential`
  field -
  that nesting is the JSON shape, not the Python one - and `paths` /
  `exact_paths` are worth showing, because the split between "the whole edit
  set"
  and "only files that provably name the symbol" is the thing a program calls
  this
  for.
- `blast blast Corpus` was the way in. Now it is `blast Corpus`, and the old
  spelling keeps working because the verb never went anywhere.

  Every row in the report also says what kind of reference it is: `[use]` for a
  call site, `[def]` for a redeclaration, `[str]` for the name inside a string
  literal, and a `gen` suffix on any of them when the file is generated. That
  is the difference between a file to edit and a file to regenerate, and it
  used to be the reader's job to infer it from the path.

  Dependents are ranked instead of listed in corpus order, so `--budget` trims
  codegen off the tail rather than whichever hand-written caller happened to
  sort last.

### Fixed

- Every function in this package is annotated, public and private alike, and
  every consumer's type checker has been ignoring all of it. PEP 561 says
  annotations inside an installed package are invisible unless the package
  ships a `py.typed` marker, and this one never did. The work was done and then
  hidden: `mypy` run against code importing this package got `Any` for the
  whole API and reported nothing wrong.

  The marker is there now, and hatchling ships it because it sits inside the
  package directory. There is a test for it too, because the failure mode is
  silent in both directions - nothing here breaks when it goes missing, and
  nobody downstream is told.
- The Go binding's README said it "answers through the `blast` binary", and
  half
  its own verb table does not. `Context` and `Family` lower into
  `relate pack --matching` / `relate echoes --matching`, because
  composition-as-narrowing is a modifier on relate's verbs rather than a verb
  here; only `Provenance` and `Blast` reach the binary this package builds.

  That sentence is the reason a local `go test ./...` quietly runs three of
  five.
  The resolver checks the env override, then *this* checkout's `zig-out/bin`,
  then PATH - and a sibling checkout's `zig-out` is on none of those rungs, so
  `zig build` here mints `blast` and no `relate` will ever appear beside it.
  The
  two composed tests then skip, which is a pass over the one seam this package
  exists for. CI already knew: its Go job builds the sibling and puts both on
  PATH, and the comment there spells out why. Nothing said it anywhere a person
  reading the binding would look.

  The verb table now carries which binary answers each verb, with the
  rung-by-rung
  reason underneath and the two-line recipe to build the sibling and run the
  suite
  the way CI does. Ran it verbatim from a clean shell: five tests, none
  skipped.

  No test was touched. The skip guard stays a skip - it is the resolver's
  honest
  report that a binary is unreachable, and unlike an early `return` in a Rust
  harness it prints SKIP where you can see it. What was missing was the
  sentence
  telling you how to stop seeing it.
- The binary now signs its diagnostics as `blast:` instead of `gist:`. The
  kernel used to hardcode the product name at every diagnostic site, so a bad
  knob passed to this binary was reported under a program the user never
  invoked. The engine grew a brand seam (`irregex.Brand`, read from the root
  module at comptime) and this face declares `.{ .name = "blast" }`. Only the
  name moves — the knob namespace stays `GIST_*` and the artifact directory
  stays shared, since `blast` and `provenance` read the index, atlas, and shelf
  the sibling binaries write. Its `--help` also stopped citing an internal
  decision record that no reader outside the original monorepo could reach; the
  line says what composition is instead of pointing at where it was decided.
- The declared dependencies carry bounds: `irregex>=1.0.0,<2` and
  `relate-search>=0.1.0,<2`.

  Unbounded, the substrate requirement resolves to `irregex==0.1.0` - the
  pre-rename placeholder on the index, which has no `irgx` module in it at all,
  so an install would succeed and then fail on the first import. The floor is
  1.0.0 because that is where `irgx` starts existing; the ceiling is the same
  fact from the other side, since 1.0.0 is where the substrate froze the C ABI
  and the `irgx` surface and a 2.0 is free to move both. blast composes
  relate's kinship verbs across the same kind of boundary, so that requirement
  is bounded for the same reason, at its own version.
- The packaging suite asked whether libblast had absorbed the engine by
  deleting libirgx from a staging directory and requiring the load to fail.
  That is a proxy for a question about symbols, and it answered differently per
  machine: Zig records the dependency's build-cache directory as a search path,
  and where `ZIG_LOCAL_CACHE_DIR` is absolute the loader resolves the deleted
  library straight back out of the cache. So the gate held on a dev machine and
  asserted nothing on CI, where it then failed for a reason that was never
  about the invariant. It reads the export table now, which is what "does not
  redefine `irgx_*`" actually means, and a companion case runs the same probe
  over both libraries so an empty answer cannot pass for a clean one.

  What it deliberately does not assert is that libblast records libirgx as a
  needed dependency. That record is the linker's decision rather than this
  repository's: ELF drops an `--as-needed` library that no undefined symbol
  needs, so a product whose statically linked Zig already satisfies everything
  records nothing, while Mach-O keeps the entry regardless - which is exactly
  how libblast diverged from its siblings on Linux under identical link calls.
  Absent redefinition is what makes the engine vocabulary single; the
  dependency table only ever explained it, so it is reported in the failure
  message rather than gated.
- The test runner is pinned by url and hash instead of assumed to sit beside
  this
  repository.

  `.brigade = .{ .path = "../brigade" }` resolves on a machine that happens to
  have
  the sibling checked out, and nowhere else - so a fresh clone, and CI, could
  not
  build this package at all. brigade is a published package now
  (github.com/The-Billy-Company/brigade), pinned the way the vendored engines
  already were.

  The co-developed siblings stay path deps on purpose: those change together
  with
  this repository and a checkout beside it is the point. A test runner does
  not,
  so this repository chooses its version deliberately.
- `TestContextPicksOnlyMatchingFiles` and `TestFamilyNarrowsToMatching` no
  longer
  skip on a laptop, and CI no longer exports a PATH to stop them.

  Both lower into `relate pack --matching` / `relate echoes --matching`, and
  the
  shared resolver in the irregex module had no rung that could see a sibling
  checkout - it looked in this checkout's `zig-out/bin`, then in a path shaped
  like
  the monorepo all four packages were extracted from, then PATH. `zig build`
  here
  mints `blast` and never a `relate`, so the two tests skipped, which is a
  green
  run over the one seam this package exists for. The resolver now walks to the
  sibling that owns the name, so a built `../relate` is found where it actually
  is.

  The Go job's PATH export is gone with it: it was covering for the dead rung
  and
  it resolved nothing that the ladder does not now resolve on its own. Keeping
  it
  would also have hidden the next regression in that ladder, which is the
  failure
  this whole thing was. What replaces it is the assertion the export was really
  standing in for - the job now fails if any test skipped itself, so an
  unreachable
  binary is a red X rather than a quieter green one. Both directions checked
  locally against the same four-repo layout CI assembles.

  The README's rung-by-rung explanation said a sibling was unreachable and gave
  you a PATH recipe. It is now the shorter true thing: build both, export
  nothing.
- `TestContextPicksOnlyMatchingFiles` proves the whole point of a composed
  `context`: the exact engine admits a candidate set, and the compression
  engine
  may only pick inside it. Extraction broke it twice, and only one of the two
  was
  visible.

  The loud half: it priced the query "how does the resident session reconcile
  freshness" against whatever tree it ran in. In the package this was split out
  of, that tree was the whole engine and "resident" was everywhere. Here it
  appears in two files, `pack` has nothing to price, and the test failed on an
  empty reading set — a corpus assumption the split invalidated, not a defect
  in
  the engine, which reports `0.0 priced bits` and suggests widening the
  pattern.
  It now asks about `compose` over `src/`, where 7 files match and the pack
  resolves to two picks explaining 73% of the priced bits.

  The quiet half is the one worth reading. Scope came from "the nearest
  ancestor
  holding a `build.zig`" — a nested package before, this repository's own root
  now. A scope equal to the root excludes nothing, so "every pick was inside
  the
  declared scope" had become true of any answer at all, and half the test had
  stopped being an assertion without ever going red. Fixing only the visible
  failure would have shipped that. The scope is a fixed subdirectory now, and
  the
  test opens by counting matches outside it and refusing to run if there are
  none,
  so the trap has to be proven armed before the answer is trusted. Flipping the
  scope back to the root fails on that check rather than passing vacuously.

  Both engines are on PATH in CI's Go job now. All five compose tests run
  there;
  none skip.
- `blast --json` could emit JSON that no parser would take. A file path is
  whatever bytes the filesystem hands back, and on Linux that is not guaranteed
  to be UTF-8 - a Latin-1 filename, a truncated multibyte sequence, a stray
  `0xFF`. The escaper underneath assumed valid UTF-8, so a path with a bad byte
  rode straight into a string literal and `std.json.parseFromSlice` rejected
  the whole document with a `SyntaxError`. The one consumer that mattered - a
  machine reading `--json` - got nothing.

  A new `jsonsafe.str` gate now sits in front of every string blast does not
  control (paths in `blast blast --json`, phrases and paths in `blast
  provenance --json`). It validates the bytes first; a valid string takes the
  fast path unchanged, and an invalid one is rewritten to well-formed UTF-8 -
  one U+FFFD per byte that does not begin a complete sequence, advancing a byte
  at a time so nothing is silently dropped. The output is always parseable, the
  string field keeps its shape, and a clean path costs one `utf8ValidateSlice`
  and nothing else.

  Regression-pinned by round-tripping adversarial paths (embedded quotes,
  backslashes, newlines, control bytes, and raw invalid sequences) through
  `std.json` in both faces, so a future edit that reaches for the raw escaper
  again fails the parse.
- `blast --version` said `1.0.0`. blast was `0.1.0`. It was printing the
  engine's semver, which is the one number in reach that nobody had to
  hand-maintain - and the wrong one, since this package composes three siblings
  that each version on their own schedule.

  Now `build.zig` lifts `.version` out of `build.zig.zon` as a build option and
  the face exposes it, so `--version` and the `--schema` manifest report this
  package's number, read from the one place it is written and restated nowhere.
  `irregex.version_string` is still how you ask what is underneath.

  `Cargo.toml` and `pyproject.toml` keep a copy because neither can import
  anything, both marked with `x-release-please-version` and both listed in the
  new `release-please-config.json`, so one merged release PR moves all three
  together. `tools/version_parity.py` fails if a copy drifts or if a marked
  line was never declared to the bot, and runs in CI as the `version` job.
- `libblast.a` resolves its substrate symbols through libirgx rather than
  redefining them, so a static consumer links the pair - and the install prefix
  only ever held one half of it. `libirgx.so` was installed, `libirgx.a` was
  not,
  so anyone following the archive path had to go find the engine's archive in
  another checkout and hope it was built for the same target.

  It installs now, taken off the dependency graph as a named lazy path rather
  than copied from a sibling `zig-out`, so it is the right target and the right
  optimize mode by construction.

  The ELF `libblast.a` also stops registering a second build artifact named
  `blast`. The dylib already owns that name, and a duplicate makes a
  dependent's
  `dep.artifact("blast")` ambiguous enough to panic the build runner - in the
  DEPENDENT, never here, and only on the arm macOS does not take. Both arms
  install the archive as a file now, the way the macOS arm already did for its
  own alignment reasons.
- `libblast` was not loadable outside the tree that built it. Linking the
  substrate records the dependency's own build output directory as an rpath,
  and that path is a *relative* `.zig-cache/o/<hash>` — true on the machine
  that produced it, meaningless anywhere else — so a consumer's
  `dlopen("libblast.dylib")` failed with `Library not loaded:
  @rpath/libirgx.dylib` before a single call reached the engine. `build.zig`
  now adds a loader-relative rpath (`@loader_path`, `$ORIGIN` off macOS),
  making the shape we actually ship — every library in one lib directory — the
  loadable one.

  This hid behind the bindings, which load the substrate first: once `libirgx`
  is in the process, the loader satisfies a later `@rpath` reference from the
  already-loaded image by install name. Every binding worked; only an honest
  standalone consumer failed, which is the one case nothing tested.

  `tests/test_packaging.py` now stages both libraries into a directory and
  opens the product in a child process with a clean environment, from an
  unrelated working directory — a same-process check would inherit exactly the
  rescue that hid this. Mutation-proven by deleting the rpath from the built
  dylib; a sibling test asserts the complement, that removing the substrate
  still breaks the load.
- `zig build test` now exists here, and it runs the tests this package ships.

  Two things were missing, and each hid the other. The build graph declared no
  `test` step at all, so `zig build test` answered "no step named 'test'" -
  which
  reads like a package that has no tests, rather than one whose five tests
  nothing could reach. Adding the step then reported "All 0 tests passed", the
  more dangerous of the two failures: the only `@import` of the face's modules
  sits inside `main`, which a test build never references and therefore never
  analyzes, so no test was ever collected. A green step that ran nothing.

  `main.zig` now names the three face modules in a `test` block, the same way
  the
  sibling packages' roots do, so a future test in any of them is collected by
  default. Six tests run.

  Neither gap existed before the split: the monorepo this was extracted from
  has
  a root that imports all three, and the extraction took the face without it.
