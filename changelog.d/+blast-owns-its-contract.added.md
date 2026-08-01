`contract/compose.toml` is blast's own contract, carrying the three tables that
describe what this package does: `[compose]` (the exact-before-statistical seam
— candidate set, comparison unit, distinct, scoring, scope, blast tiers),
`[compose.verbs]` (`provenance` and `blast`), and `[compose.retired]` (the two
composed verbs that became relate's `--matching` flag, with the coaching that
sends a caller to the new spelling).

They were declared in `gist/contract/surface.toml`, which had no claim on them:
gist does not answer either verb. The rows they return stay substrate, declared
with every other analytic row in `irregex/contract/analytic.toml`, and
`blast_run` and its op codes stay in that file's `[analytic.producers]` and
`[analytic.verbs]` — op numbers are ecosystem-wide on purpose.

The verbs' `argv` had gone stale in the move here: both still spelled
`irregex provenance` / `irregex blast` from before the binary was renamed. They
say `blast` now, which is what the binary is called.
