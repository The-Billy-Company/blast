`TestContextPicksOnlyMatchingFiles` proves the whole point of a composed
`context`: the exact engine admits a candidate set, and the compression engine
may only pick inside it. Extraction broke it twice, and only one of the two was
visible.

The loud half: it priced the query "how does the resident session reconcile
freshness" against whatever tree it ran in. In the package this was split out
of, that tree was the whole engine and "resident" was everywhere. Here it
appears in two files, `pack` has nothing to price, and the test failed on an
empty reading set — a corpus assumption the split invalidated, not a defect in
the engine, which reports `0.0 priced bits` and suggests widening the pattern.
It now asks about `compose` over `src/`, where 7 files match and the pack
resolves to two picks explaining 73% of the priced bits.

The quiet half is the one worth reading. Scope came from "the nearest ancestor
holding a `build.zig`" — a nested package before, this repository's own root
now. A scope equal to the root excludes nothing, so "every pick was inside the
declared scope" had become true of any answer at all, and half the test had
stopped being an assertion without ever going red. Fixing only the visible
failure would have shipped that. The scope is a fixed subdirectory now, and the
test opens by counting matches outside it and refusing to run if there are none,
so the trap has to be proven armed before the answer is trusted. Flipping the
scope back to the root fails on that check rather than passing vacuously.

Both engines are on PATH in CI's Go job now. All five compose tests run there;
none skip.
