A fifth CI job, and it checks the one formatter nothing here was checking. The
Rust crate already had `cargo fmt --check` inside its own job; Zig, which is
what the face and the FFI are written in, had nothing.

That gap is not theoretical. `zig fmt` lays a column-aligned multiline literal
out as a padded grid, so a rename that shrinks the widest cell in a column
leaves every row beneath it one space too wide — in files nobody opened. The
sibling substrate shipped exactly that and no gate said a word. blast owns
seven Zig files, which is the size of tree where this is easiest to skip and
easiest to let rot quietly.

Its own job, for the reason the other four are: a formatting nit and an engine
regression should not arrive as the same red X. It is the cheapest job here by
a distance, and the only one that needs no ecosystem at all — even `rust`, which
skips the builds, still wants irregex on disk for a path dependency. This one
wants a single checkout, because reading files is not configuring a build. It
pins the same Zig everything else builds with, since the formatter's output is
a property of the compiler release — a different Zig is a different grid.

The file list is enumerated with `git ls-files -co --exclude-standard '*.zig'`
rather than written out, which matters more here than seven files suggests: all
of it lives under one subtree today, and a path list would quietly stop covering
the day it does not. Tracked plus untracked-not-ignored leaves out exactly the
ignored trees, `.zig-cache` and the fetched `zig-pkg/` with its own `build.zig`,
so the exclusions live in `.gitignore` where someone can read them. The one
piece that looks like belt-and-braces is the existence test on each path, and it
is not: `git ls-files` still names a tracked file you have deleted, so without
it a mid-edit working tree fails the gate with `FileNotFound` and teaches
everyone to ignore it.
