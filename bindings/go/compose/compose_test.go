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
// engine's own source because pricing a query needs a corpus with a lexicon — a
// three-file fixture has too few phrases for a composed pack to price at all.
func TestContextPicksOnlyMatchingFiles(t *testing.T) {
	repo := checkout(t)
	const pattern = "compose"
	scope := engineScope(t, repo)
	// Both halves of this test have to be able to fail, and one of them silently
	// stopped being able to. Containment is only an assertion while the pattern
	// also matches files the scope excludes; when it matches nothing outside,
	// "every pick was in scope" is true of any answer whatsoever. That is not a
	// hypothetical — this scope was a nested directory in the tree this package
	// was extracted from and became the whole repository, so the check went quiet
	// without going red. Prove the trap is still armed before trusting it.
	if outside := matching(t, repo, pattern) - matching(t, filepath.Join(repo, scope), pattern); outside == 0 {
		t.Fatalf("%q matches nothing outside %s: scope containment cannot fail here", pattern, scope)
	}
	picks, err := Over(scope).In(repo).
		Context(t.Context(), analytic.Compose{
			Text:     "what does the compose verb do and how does it narrow",
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

// engineScope is the composed face's own Zig source, named relative to the
// checkout. It is deliberately a fixed subdirectory rather than "wherever
// `build.zig` lives": that spelling resolved to a nested package in the tree this
// was extracted from and to the repository root here, and a scope equal to the
// root is not a scope — it excludes nothing, so nothing can be caught escaping it.
func engineScope(t *testing.T, repo string) string {
	t.Helper()
	src := filepath.Join(repo, "src")
	if _, err := os.Stat(src); err != nil {
		t.Fatalf("no engine source at %s: %v", src, err)
	}
	return relTo(t, repo, src)
}

// matching counts files under root whose bytes contain pattern. Deliberately a
// plain walk rather than a call into the search engine: it is used to prove the
// assertion above is falsifiable, and evidence about a tool should not be
// gathered with that tool.
func matching(t *testing.T, root, pattern string) int {
	t.Helper()
	n := 0
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir():
			if name := d.Name(); name == ".git" || name == "zig-out" || strings.HasSuffix(name, "zig-cache") {
				return filepath.SkipDir
			}
			return nil
		}
		body, err := os.ReadFile(path)
		if err == nil && strings.Contains(string(body), pattern) {
			n++
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk %s: %v", root, err)
	}
	return n
}

// bindingScope is this binding's own directory, where the blast target is declared.
func bindingScope(t *testing.T, repo string) string {
	t.Helper()
	return relTo(t, repo, filepath.Dir(cwd(t))) // .../bindings/go/compose → .../bindings/go
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
