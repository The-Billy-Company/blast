The Windows installer now builds the requested native target in ReleaseFast
mode. Re-running it can reuse the artifact CI or an earlier install already
built instead of recompiling a second configuration.
