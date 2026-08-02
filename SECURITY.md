# Security Policy

`blast` is pointed at trees it did not write, and it answers two questions that
are unusually easy to act on: *where did this text come from?* and *what breaks
if I change this?* An agent that trusts the second one edits code. So a wrong
answer here is not a missed search hit - it is a false claim about a codebase,
and the threat model starts from **"the corpus is the attacker"**: hostile file
names, hostile bytes, a committed config file, a persisted shelf left behind by
something else. Every one of those is input.

## Reporting a vulnerability

**Do not open a public issue, pull request, or discussion.**

Use GitHub's private reporting - the **Security** tab on this repository,
"Report a vulnerability" - which opens a thread only the maintainers can read.
If that is unavailable to you, email **security@billylives.com**.

Please include:

- what you found and what it lets an attacker do;
- the smallest reproduction you can manage: the tree (a script that builds it
  beats a tarball), the exact command line, and whether the shelf or a resident
  session was warm;
- `blast --version`, and the versions of the packages underneath if you built
  from source;
- your OS and architecture, and how you built the binary.

We will acknowledge within **72 hours** and give you a triage verdict with a
severity within **7 days**. If it is real we will agree a disclosure date with
you, credit you in the changelog fragment and the release notes unless you would
rather we did not, and ship the fix before the details go public. There is no
paid bounty.

We will not pursue anyone who reports in good faith, works against their own
machines and their own data, and gives us a reasonable window to fix the thing
before publishing.

## Supported versions

Pre-1.0, and the version number says so. Fixes land on `main` and ship in the
next release; there are no maintained release branches and no backports to
earlier tags. Watch releases on this repository if you pin.

This package contains neither engine, so a great deal of what could go wrong
belongs to a neighbour with its own policy: [`irregex`][irregex] owns the regex
engines, the corpus walk, and the FM-index; [`relate`][relate] owns kinship, the
codex shelf, and the compose kernels; [`gist`][gist] owns argv, the resident
daemon, and the answer keep. Any tracker reaches us, and we will move a report
rather than bounce you.

## What we consider a vulnerability here

- **A phrase that survives its bytes.** `provenance` re-reads the named file's
  **current** bytes and re-finds the phrase exactly; that re-verification is the
  entire reason this verb exists rather than being `relate quote`. Anything that
  lets a stale line, a deleted file, or a shelf entry the tree no longer
  supports reach the output is a vulnerability, not a caching bug.
- **A false attribution.** Input that makes `provenance` name a file which never
  held the phrase - or that lets a file claim text belonging to another - is in
  scope. Someone will cite that answer.
- **A radius that hides a dependent.** `blast` is used to decide whether an edit
  is safe. A corpus that can suppress a real caller from `direct.dependents`,
  or push it past `--budget` into `stats.omitted` while looking complete, is a
  security issue in the same way a search that hides a file is: the answer looks
  whole and is not.
- **A fused or forged score.** Exact and statistical evidence stay in separate
  fields by design. Anything that lets a compression result present itself as an
  exact one - a twin appearing as a dependent, a mention appearing as a
  definition - is in scope.
- **Escaping the scope you were given.** A symlink, a `..` in a name, or a path
  spelling that walks a sweep out of the roots it was handed.
- **Terminal escape injection.** Paths, quoted phrases, and matched bytes are
  printed, and hyperlinks are emitted when stdout is an interactive terminal.
  Content that can drive a terminal emulator - relocate the cursor, rewrite
  earlier output, set the title, or forge a link target that does not match its
  label - is in scope. A pipe, a redirect, and `--json` are supposed to be plain
  bytes with none of that layer.
- **A config file reaching past its ceiling.** A tree's committed
  `.irregex.toml` is read from the corpus you are searching, which means a
  repository you cloned gets a vote. Its reach is capped at **corpus** and may
  never change what matches, never run a command, and never read a path outside
  the tree.
- **Memory safety anywhere in this repository.** Release builds are
  `ReleaseFast`, where Zig's safety checks are off, so a bug that is a clean
  panic in your debug build may be memory corruption in the shipped binary. That
  includes `libblast`: a host linking it gets our bytes in its address space.

## What is not a vulnerability

- **Cost proportional to the corpus.** A blast radius is corpus-wide by nature -
  one that stopped at a directory would lie - so a big tree costs more than a
  small one. That is arithmetic, and `--budget` is the knob.
- **A twin you disagree with.** `tangential.twins` is compression kin, offered as
  co-edit risk rather than as a call graph. It is labelled tangential because it
  is a guess. A bad one is a quality report, with the corpus.
- **`provenance` needing a shelf.** It reads the corpus-wide codex shelf and
  says so when there is not one. Refusing to answer is the correct behaviour.
- **The daemon obeying the user who started it.** Same-user access is the
  design, not a hole.

## What already tries to catch this

None of it is a guarantee, and finding something these missed is exactly the
kind of report we want:

- the binding suites drive **real** binaries rather than fakes, and CI fails on
  a test that skipped itself - a suite that quietly checked nothing is treated
  as a broken gate, not as a pass;
- the full install path runs on Linux and macOS both, because linking
  `libblast` against `libirgx` and staging the headers is where the two hosts
  disagree;
- an architecture contract ([`contract/blast.ward`](contract/blast.ward)) that
  machine-checks the import topology, and a seam contract
  ([`contract/compose.toml`](contract/compose.toml)) that declares the scoring
  split this face is not allowed to blur.

## Provenance

[`NOTICE`](NOTICE) records that nothing third-party is bundled here and points
at the packages underneath, whose notices carry what they do bundle.

[irregex]: https://github.com/The-Billy-Company/irregex/blob/main/SECURITY.md
[relate]: https://github.com/The-Billy-Company/relate/blob/main/SECURITY.md
[gist]: https://github.com/The-Billy-Company/gist/blob/main/SECURITY.md
