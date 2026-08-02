`blast --version` said `1.0.0`. blast was `0.1.0`. It was printing the engine's semver, which is the one number in reach that nobody had to hand-maintain - and the wrong one, since this package composes three siblings that each version on their own schedule.

Now `build.zig` lifts `.version` out of `build.zig.zon` as a build option and the face exposes it, so `--version` and the `--schema` manifest report this package's number, read from the one place it is written and restated nowhere. `irregex.version_string` is still how you ask what is underneath.

`Cargo.toml` and `pyproject.toml` keep a copy because neither can import anything, both marked with `x-release-please-version` and both listed in the new `release-please-config.json`, so one merged release PR moves all three together. `tools/version_parity.py` fails if a copy drifts or if a marked line was never declared to the bot, and runs in CI as the `version` job.
