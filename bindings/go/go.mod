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

require (
	github.com/The-Billy-Company/irregex/bindings/go v0.0.0
	github.com/The-Billy-Company/relate/bindings/go v0.0.0
)

replace github.com/The-Billy-Company/irregex/bindings/go => ../../../irregex/bindings/go

replace github.com/The-Billy-Company/relate/bindings/go => ../../../relate/bindings/go
