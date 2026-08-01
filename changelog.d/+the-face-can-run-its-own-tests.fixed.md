`zig build test` now exists here, and it runs the tests this package ships.

Two things were missing, and each hid the other. The build graph declared no
`test` step at all, so `zig build test` answered "no step named 'test'" - which
reads like a package that has no tests, rather than one whose five tests
nothing could reach. Adding the step then reported "All 0 tests passed", the
more dangerous of the two failures: the only `@import` of the face's modules
sits inside `main`, which a test build never references and therefore never
analyzes, so no test was ever collected. A green step that ran nothing.

`main.zig` now names the three face modules in a `test` block, the same way the
sibling packages' roots do, so a future test in any of them is collected by
default. Six tests run.

Neither gap existed before the split: the monorepo this was extracted from has
a root that imports all three, and the extraction took the face without it.
