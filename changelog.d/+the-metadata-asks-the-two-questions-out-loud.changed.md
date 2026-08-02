This package answers two questions and the metadata described neither of them.
"Importable Python API for blast composed search verbs" tells a reader nothing:
"composed verbs" is how the thing is built, not what it is for, and a person
looking for this is searching "blast radius", "impact analysis", "what breaks if
I change this", or - for the other half - "provenance", "code attribution".

Both vocabularies are in the keywords now, the summary asks the questions in
plain words, and the README h1 does the same instead of being the bare word
`blast`. The repository description also stopped claiming it ships the `irregex`
binary; it has shipped `blast` since the rename gave `irregex` back to the
engine package, and the description had not caught up.

The Python binding's README was twelve lines of contributor notes and would have
been the whole PyPI page. It is a real one now, with worked examples for both
verbs. Two details it gets right that the old prose did not: `twins` and
`ripple` are flat attributes on `Blast`, not nested under a `tangential` field -
that nesting is the JSON shape, not the Python one - and `paths` /
`exact_paths` are worth showing, because the split between "the whole edit set"
and "only files that provably name the symbol" is the thing a program calls this
for.
