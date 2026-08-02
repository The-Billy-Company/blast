The repository had a license, a NOTICE, and five CI jobs, and nothing that told
a contributor how to work in it. It now carries the paper trail a public
project is supposed to have.

[`CONTRIBUTING.md`](CONTRIBUTING.md) is the practical half, and it leads with
the thing that actually stops people: this package has the only two-level path
graph in the ecosystem, so it needs four checkouts beside each other, not one.
It says what each toolchain is pinned by, why a bare `zig build` proves
something `check` and `test` do not, and why a composed test that cannot resolve
a binary skips itself into a green run - which is why CI greps its own output
for a skip and fails on one. It also states the constraints a change is held to:
current bytes are the whole point, exact and statistical evidence never fuse
into one number, and the ward contract stays at two hops of reach.

[`SECURITY.md`](SECURITY.md) names the threat model. The corpus is the attacker,
as everywhere - but these two verbs are used to *decide* things, so the
vulnerabilities here are shaped differently: a phrase that survives the bytes
that justified it, a radius that hides a real dependent behind a complete-looking
answer, a compression twin presenting itself as an exact dependent. It says what
is not one, too: a blast radius is corpus-wide by nature, and costing what a
corpus costs is arithmetic.

[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) is Contributor Covenant 3.0, with
reports going to a maintainer address rather than a committee that does not
exist. Of the four repositories this is the one where the crediting clause is
not boilerplate: a tool that attributes other people's writing for a living has
no business being careless about attributing other people's work.

The dotfiles are small and load-bearing. `.editorconfig` restates what each
formatter already emits, so an editor save and `zig fmt --check` cannot
disagree. `.gitattributes` normalizes line endings - this face re-finds a phrase
in a file's current bytes, and a CRLF checkout would change the bytes it
verifies against - marks resolver output as generated, binds the hunk-header
drivers, and deliberately declines `export-ignore`, which would invalidate every
url+hash pin that already exists. `.mailmap` collapses two author spellings into
one person.

On GitHub: `CODEOWNERS` routes review, Dependabot watches the one ecosystem it
can actually resolve here, a pull-request template asks whether the change still
reads current bytes, and the issue forms send kinship questions to relate,
pattern questions to irregex, and daemon questions to gist before anyone spends
an afternoon in the wrong repository.
