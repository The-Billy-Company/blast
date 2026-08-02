<!--
Thanks for sending this. Delete any section that does not apply rather than
writing "n/a" in all of them - a short, honest PR body beats a filled-in form.
CONTRIBUTING.md has the long version of everything below.
-->

## What changed

<!-- One or two sentences in the voice of the change. What is different now? -->

## Why

<!-- The problem, not the patch. If there is an issue, link it. -->

## What proves it

<!--
The question review asks first. Name the test, the fixture, or the corpus - and
what it would have done before this change. "Existing tests pass" is not proof
that a new behaviour is right, and it is especially weak here: a composed test
that cannot resolve a binary skips itself, so a green suite can mean nothing
ran. Say which binaries were built.

Changing what a verb reports? Show it on a tree: which dependents appeared or
disappeared, which phrase survived re-verification and which did not.
-->

## Does it still read current bytes

<!--
The whole reason these two verbs live here rather than in relate. If this change
makes an answer faster by trusting something persisted - a shelf entry, a cached
radius, a graph - say so explicitly, because that is a change to what the verb
means rather than an optimization.
-->

## What it costs

<!--
Allocation, syscalls, a wider public surface, a slower cold path, another hop of
reach. If the answer is genuinely nothing, say so - that is an answer.
-->

## What it replaces

<!--
If a newer path supersedes an older one, the older one should be gone in this
same PR. Two spellings of the same thing is how a codebase grows two spellings
of the same bug.
-->

---

- [ ] `zig build test` passes, `zig build` completes the install path, and
      `zig fmt .` leaves the tree clean
- [ ] The binding suites ran against freshly built binaries, and nothing skipped
      itself
- [ ] A news fragment is in `changelog.d/` (`+<slug>.<type>.md`), unless this is
      comment-only, format-only, or genuinely invisible
- [ ] Exact and statistical evidence are still in separate fields
- [ ] `contract/blast.ward` is updated in this PR if a new import edge was
      needed, and `contract/compose.toml` if the seam moved
