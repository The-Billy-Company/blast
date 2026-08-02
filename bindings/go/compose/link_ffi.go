//go:build cgo && irgx_ffi

package compose

/*
// Pull libblast into the final link so blast_run is visible to the substrate
// runtime's dlsym lookup. Without this, an -tags irgx_ffi build of this
// module would open the engine but find no compose producer.
#cgo CFLAGS:  -I${SRCDIR}/../../../zig-out/include
#cgo LDFLAGS: -L${SRCDIR}/../../../zig-out/lib -lblast -lirgx
#cgo LDFLAGS: -Wl,-rpath,${SRCDIR}/../../../zig-out/lib
#include <blast.h>
*/
import "C"
