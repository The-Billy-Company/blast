package compose

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/The-Billy-Company/irregex/bindings/go/analytic"
	"github.com/The-Billy-Company/irregex/bindings/go/runtime"
)

// planted is a corpus whose composed answers are known in advance: the two twins
// carry Reticulate functions, the third file carries none, so a pattern-narrowed
// question has exactly two admissible files.
func planted(t *testing.T) *Corpus {
	t.Helper()
	root := t.TempDir()
	var body strings.Builder
	body.WriteString("package sample\n\n")
	for i := 1; i <= 11; i++ {
		fmt.Fprintf(&body, "// Stanza %d: the reticulation of splines, a matter of some delicacy.\n"+
			"func Reticulate%d(splines []int) int {\n\ttotal := 0\n\tfor _, s := range splines {\n\t\ttotal += s * %d\n\t}\n\treturn total\n}\n\n", i, i, i)
	}
	for name, text := range map[string]string{
		"alpha.go": body.String(),
		"beta.go":  body.String() + "// a trailing remark, so the pair is near rather than exact\n",
		"gamma.go": "package sample\n\n" + strings.Repeat("// Wholly unrelated prose about tunnels, weather, and the price of tin.\n", 30),
	} {
		if err := os.WriteFile(filepath.Join(root, name), []byte(text), 0o600); err != nil {
			t.Fatalf("write %s: %v", name, err)
		}
	}
	return Over(root).In(root)
}

func requireEngine(t *testing.T, tool string) {
	t.Helper()
	if _, err := runtime.Binary(tool); err != nil {
		t.Skipf("no %s binary: %v", tool, err)
	}
}

// TestScopeIsMandatory pins the containment rule: a composed query with no scope
// is refused rather than quietly sweeping every vendored tree on the machine, and
// All() is the explicit way to ask for that sweep.
func TestScopeIsMandatory(t *testing.T) {
	for name, run := range map[string]func(*Corpus) error{
		"context": func(c *Corpus) error {
			_, err := c.Context(t.Context(), analytic.Compose{Text: "anything", Patterns: []string{"x"}})
			return err
		},
		"family": func(c *Corpus) error {
			_, err := c.Family(t.Context(), analytic.Compose{Patterns: []string{"x"}})
			return err
		},
	} {
		if err := run(Over()); !errors.Is(err, ErrUnscoped) {
			t.Errorf("%s unscoped = %v, want ErrUnscoped", name, err)
		}
	}
}

// TestComposedVerbsNeedTheirSubject pins that the text a composed verb reasons
// about is required at the seam — a blast with no symbol is a malformed question,
// not an empty answer.
func TestComposedVerbsNeedTheirSubject(t *testing.T) {
	c := planted(t)
	if _, err := c.Blast(t.Context(), analytic.Compose{}); err == nil {
		t.Error("blast accepted an empty symbol")
	}
	if _, err := c.Context(t.Context(), analytic.Compose{Patterns: []string{"x"}}); err == nil {
		t.Error("context accepted empty task text")
	}
	if _, err := c.Provenance(t.Context(), analytic.Compose{}); err == nil {
		t.Error("provenance accepted an empty snippet")
	}
}

// TestContextPicksOnlyMatchingFiles is the composition itself: the exact engine
// admits the candidate set, and the compression engine may only pick inside it.
// Every pick is re-checked by reading the file, so the containment claim is proven
// against bytes rather than taken from the engine's own report. It runs over the
// kernel's own tree because pricing a query needs a corpus with a lexicon — a
// three-file fixture has too few phrases for a composed pack to price at all.
func TestContextPicksOnlyMatchingFiles(t *testing.T) {
	requireEngine(t, runtime.ToolRelate)
	repo := checkout(t)
	const pattern = "resident"
	scope := kernelScope(t, repo)
	picks, err := Over(scope).In(repo).
		Context(t.Context(), analytic.Compose{
			Text:     "how does the resident session reconcile freshness",
			Patterns: []string{pattern},
			Top:      4,
		})
	if err != nil {
		t.Fatalf("context: %v", err)
	}
	if len(picks) == 0 {
		t.Fatal("no reading set among the matching files")
	}
	inScope := filepath.Join(repo, scope) + string(os.PathSeparator)
	for _, p := range picks {
		if !strings.HasPrefix(filepath.Join(repo, p.Path), inScope) {
			t.Errorf("pick %s is outside the declared scope %s", p.Path, scope)
		}
		body, err := os.ReadFile(filepath.Join(repo, p.Path))
		if err != nil {
			t.Fatalf("read pick %s: %v", p.Path, err)
		}
		if !strings.Contains(string(body), pattern) {
			t.Errorf("pick %s does not contain %q, so the exact engine did not admit it", p.Path, pattern)
		}
		if !slices.Contains(p.Patterns, pattern) {
			t.Errorf("pick %s reports patterns %v, want the one that admitted it", p.Path, p.Patterns)
		}
	}
}

// TestFamilyNarrowsToMatching pins the other composition: fork families computed
// only among the files the pattern admitted.
func TestFamilyNarrowsToMatching(t *testing.T) {
	requireEngine(t, runtime.ToolRelate)
	families, err := planted(t).Family(t.Context(), analytic.Compose{
		Patterns:    []string{"Reticulate"},
		MaxDistance: ptr(0.6),
		Top:         5,
	})
	if err != nil {
		t.Fatalf("family: %v", err)
	}
	if len(families) == 0 {
		t.Fatal("the two twins matched the pattern but formed no family")
	}
	for _, f := range families {
		for _, m := range f.Members {
			if base := filepath.Base(m.Path); base != "alpha.go" && base != "beta.go" {
				t.Errorf("family member %s was not in the candidate set", m.Path)
			}
		}
	}
}

// TestBlastReadsCurrentBytes pins the blast radius against a symbol this very
// package defines, so the expectation comes from the tree rather than from a
// recorded answer: the definition site must be the file that declares it, and the
// dependents must include a use that is not the definition.
func TestBlastReadsCurrentBytes(t *testing.T) {
	requireEngine(t, runtime.ToolBlast)
	repo := checkout(t)
	blast, err := Over(bindingScope(t, repo)).In(repo).
		Blast(t.Context(), analytic.Compose{Text: "ErrUnscoped", Budget: 64})
	if err != nil {
		t.Fatalf("blast: %v", err)
	}
	if blast.Symbol != "ErrUnscoped" {
		t.Fatalf("blast reports symbol %q", blast.Symbol)
	}
	defined := false
	for _, d := range blast.Definitions {
		if strings.HasSuffix(d.Path, "compose.go") && d.Line > 0 {
			defined = true
		}
	}
	if !defined {
		t.Errorf("definitions = %+v, want the declaration in compose.go", blast.Definitions)
	}
	uses := 0
	for _, ref := range blast.Dependents {
		if !ref.Defines {
			uses++
		}
	}
	if uses == 0 {
		t.Errorf("dependents = %+v, want at least the compose caller", blast.Dependents)
	}
	if blast.Omitted < 0 {
		t.Errorf("omitted = %d", blast.Omitted)
	}
}

// kernelScope is the kernel package this binding ships inside, named relative to
// the checkout: the nearest ancestor holding a `build.zig`. The extracted repo
// keeps that at the root and the monorepo it was split out of nests it under
// `libs/kernels/irregex`, so a scope spelling either layout literally searches
// nothing at all in the other — and an empty scope reads as "no matches" rather
// than as a broken test.
func kernelScope(t *testing.T, repo string) string {
	t.Helper()
	return relTo(t, repo, ancestorWith(t, "build.zig"))
}

// bindingScope is this binding's own directory, where the blast target is declared.
func bindingScope(t *testing.T, repo string) string {
	t.Helper()
	return relTo(t, repo, filepath.Dir(cwd(t))) // .../bindings/go/compose → .../bindings/go
}

// ancestorWith climbs from the working directory to the nearest dir holding marker.
func ancestorWith(t *testing.T, marker string) string {
	t.Helper()
	dir := cwd(t)
	for range 16 {
		if _, err := os.Stat(filepath.Join(dir, marker)); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Fatalf("no ancestor of %s holds %s", cwd(t), marker)
	return ""
}

func relTo(t *testing.T, base, dir string) string {
	t.Helper()
	rel, err := filepath.Rel(base, dir)
	if err != nil {
		t.Fatalf("rel %s from %s: %v", dir, base, err)
	}
	return rel
}

func cwd(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	return dir
}

// checkout is the repository root, so a blast test can name a symbol this binding
// itself declares instead of a fixture the answer was fabricated from.
func checkout(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	for range 16 {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Fatal("not inside a checkout")
	return ""
}

// ptr is the address of a literal, for the optional knobs that read "absent" as
// nil. Go 1.26 spells this `new(0.6)`; keeping the helper keeps this module's
// floor at the version its production code actually needs, so a consumer on an
// older toolchain is not locked out by a convenience in a test.
func ptr[T any](v T) *T { return &v }
