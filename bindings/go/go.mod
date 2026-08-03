// Standalone Go module — intentionally NOT in any parent workspace.
//
// Default build is pure Go and answers through the installed `blast` binary.
// The in-process tier is opt-in (`-tags irgx_ffi`) and links `libblast`
// plus `libirgx` from this checkout's zig-out/.
//
// Contract + runtime come from the irregex module; typed kinship row views
// come from the relate module. This module is the composed verbs only.
module github.com/The-Billy-Company/blast/bindings/go

go 1.24

toolchain go1.26.5

// Both are required at their published versions, with no `replace`. A `replace`
// in a dependency's go.mod is ignored by whoever imports it, so one here would
// have meant every consumer trying to fetch a v0.0.0 that does not exist.
// Cross-repo work uses a local `go.work` (gitignored), which is the mechanism
// that is allowed to override a published version.
require (
	github.com/The-Billy-Company/irregex/bindings/go v1.0.0
	github.com/The-Billy-Company/relate/bindings/go v1.0.0
)
