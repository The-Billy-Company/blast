package compose

import (
	"flag"
	"fmt"
	"os"
	"testing"

	"github.com/The-Billy-Company/irregex/bindings/go/runtime"
)

// tools are the engines this package's tests drive. The composed face needs
// both: relate answers the compression half, blast the composition itself.
var tools = []string{runtime.ToolRelate, runtime.ToolBlast}

// engines names the binary TestMain certified for each of [tools], so a failing
// run can close by saying which builds produced it. The store that makes every
// later call agree is [runtime.Binary]'s own cache, which TestMain primes:
// resolving here fixes the answer for the whole process, so a test that chdirs
// into a temp dir cannot re-walk from a different anchor and judge something
// else.
var engines = map[string]string{}

// TestMain hands the harness its binaries once, and refuses to run the package
// without them.
//
// A test knows something the library cannot: which build it is judging.
// [runtime.Binary] staying a *discovering* affordance is right for a library
// consumer, who genuinely has no other way to find the engine. But a missing
// binary during a test run is a broken environment rather than an optional
// capability, and failing the whole package is the honest severity for that.
//
// The per-test requireEngine guard this replaces is exactly what hid a dead
// rung in the resolver: discovery quietly returned nothing, every test that
// needed a child skipped, and the package reported ok over a seam nothing had
// exercised. Nothing in this package is optional — a composed verb is a claim
// about two engines agreeing, and neither is present by accident.
func TestMain(m *testing.M) {
	flag.Parse()
	for _, tool := range tools {
		bin, err := runtime.Binary(tool)
		if err != nil {
			fmt.Fprintf(os.Stderr, "this package's tests drive the real %s engine, and none was found.\n%v\n", tool, err)
			os.Exit(1)
		}
		engines[tool] = bin
		if testing.Verbose() {
			fmt.Fprintf(os.Stderr, "judging %s: %s\n", tool, bin)
		}
	}
	code := m.Run()
	if code != 0 {
		for _, tool := range tools {
			fmt.Fprintf(os.Stderr, "judged %s: %s\n", tool, engines[tool])
		}
	}
	os.Exit(code)
}
