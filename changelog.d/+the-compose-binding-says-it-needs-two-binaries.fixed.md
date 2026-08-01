The Go binding's README said it "answers through the `blast` binary", and half
its own verb table does not. `Context` and `Family` lower into
`relate pack --matching` / `relate echoes --matching`, because
composition-as-narrowing is a modifier on relate's verbs rather than a verb
here; only `Provenance` and `Blast` reach the binary this package builds.

That sentence is the reason a local `go test ./...` quietly runs three of five.
The resolver checks the env override, then *this* checkout's `zig-out/bin`,
then PATH - and a sibling checkout's `zig-out` is on none of those rungs, so
`zig build` here mints `blast` and no `relate` will ever appear beside it. The
two composed tests then skip, which is a pass over the one seam this package
exists for. CI already knew: its Go job builds the sibling and puts both on
PATH, and the comment there spells out why. Nothing said it anywhere a person
reading the binding would look.

The verb table now carries which binary answers each verb, with the rung-by-rung
reason underneath and the two-line recipe to build the sibling and run the suite
the way CI does. Ran it verbatim from a clean shell: five tests, none skipped.

No test was touched. The skip guard stays a skip - it is the resolver's honest
report that a binary is unreachable, and unlike an early `return` in a Rust
harness it prints SKIP where you can see it. What was missing was the sentence
telling you how to stop seeing it.
