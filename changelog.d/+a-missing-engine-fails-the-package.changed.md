The Go compose tests stopped guarding themselves one at a time. A `TestMain`
resolves both engines the package composes - `relate` and `blast` - before any
test runs, and a package that cannot find one fails outright.

Three of the five tests opened with `requireEngine`, which skipped when
discovery returned nothing. In a package whose entire subject is two engines
running against each other, every one of those skips is the suite reporting a
clean pass over the thing it exists to check; the CI workflow already had to
build both engines up front precisely so the tests would not skip their way to a
green tick. That is a fact the harness should hold, not something each test
re-negotiates.

So the harness holds it. Both binaries are resolved once at package start, the
paths are stored, and a miss prints which engine was wanted and what the
resolver looked at before exiting non-zero. The three guards are deleted and the
tests assert instead.

Worth noting what this needed underneath: blast composes two engines it does not
contain, so resolving `relate` from here means finding a *sibling* checkout. The
Go binding could already do that. The Rust one could not, which is a separate
fix in irregex.
