`TestContextPicksOnlyMatchingFiles` and `TestFamilyNarrowsToMatching` no longer
skip on a laptop, and CI no longer exports a PATH to stop them.

Both lower into `relate pack --matching` / `relate echoes --matching`, and the
shared resolver in the irregex module had no rung that could see a sibling
checkout - it looked in this checkout's `zig-out/bin`, then in a path shaped like
the monorepo all four packages were extracted from, then PATH. `zig build` here
mints `blast` and never a `relate`, so the two tests skipped, which is a green
run over the one seam this package exists for. The resolver now walks to the
sibling that owns the name, so a built `../relate` is found where it actually
is.

The Go job's PATH export is gone with it: it was covering for the dead rung and
it resolved nothing that the ladder does not now resolve on its own. Keeping it
would also have hidden the next regression in that ladder, which is the failure
this whole thing was. What replaces it is the assertion the export was really
standing in for - the job now fails if any test skipped itself, so an unreachable
binary is a red X rather than a quieter green one. Both directions checked
locally against the same four-repo layout CI assembles.

The README's rung-by-rung explanation said a sibling was unreachable and gave
you a PATH recipe. It is now the shorter true thing: build both, export nothing.
