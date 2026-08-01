The shared artifact home moved from `.local/gist-verify/` to `.gist/`. blast
writes none of it, but `blast` and `provenance` read all of it - the trigram
index, the kinship atlas, and the codex shelf the sibling binaries build - so
the move is as visible here as anywhere. `.local` was the monorepo's
machine-local scratch convention and means nothing outside it; `.gist` names
itself the way `.git`, `.ruff_cache`, and `.mypy_cache` do, and it reads
correctly against the `GIST_DIR` override that was always the real knob.

This orphans whatever you already built. Nothing migrates and nothing is
deleted; the old directory just stops being consulted, so the first `provenance`
after this lands has no shelf to read and says so. Regenerating is cheap -
`gist index` is about 3 seconds and `relate index` about 4 on a full tree - and
`GIST_DIR=.local/gist-verify` pins the old location if you would rather not.

`.gist/` is gitignored here now, alongside `upstream/` for clones kept to study.
