The Install section only knew how to build the CLI from source, which was the
whole story right up until the three bindings shipped. It now names each one
where it is actually served: `blast-search` on PyPI and crates.io, the module
path on the Go proxy, and the identifier you type in each - still `blast`,
because the `-search` suffix is a registry fact rather than an API one.

The Go README was wrong in a way that only bites after you follow it. It gave
`go get github.com/The-Billy-Company/blast/bindings/go`, which is correct, and
then never said that the module root holds no package: the one importable path
is `bindings/go/compose`. Fetch succeeded, import failed.

The Rust README had no install snippet at all and still pointed at the substrate
by relative path rather than as [`irgx`](https://crates.io/crates/irgx). All
three also say what none of them said before: the binding drives the `blast`
binary rather than reimplementing it, so the CLI is a prerequisite, and a
missing one raises `GistNotFoundError` rather than returning nothing.
