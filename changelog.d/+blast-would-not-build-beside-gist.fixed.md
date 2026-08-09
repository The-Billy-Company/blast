`blast` did not build, with the same failure `relate` had and for the same reason: `file exists in modules 'irregex' and 'irregex0'`.

Dependency dedup keys on the whole option set. `gist` asks the engine for `lib-optimize` as well as target and optimize, so blast's two-option call produced a second instance of `irregex/src/root.zig`, and the two collided as soon as one binary reached both blast's own import and the one arriving through relate.

The one option set had also been doing double duty for two dependencies with different option surfaces - `relate` does not declare `lib-optimize`, so simply widening the shared set traded the collision for `error: invalid option`. They are now separate: `opts` for siblings, `engine_opts` for the engine.
