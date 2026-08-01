CI, four jobs: the Zig engine on Linux and macOS, the Python binding across
3.12 to 3.14, the Go module, and the Rust crate. Four rather than one because a
clippy nit and an engine regression are different news.

The interesting part is the checkout. blast composes two engines it does not
contain, and one of those composes a third, so a bare clone cannot even
configure: this package wants `../irregex` and `../relate`, relate then wants an
`../irregex` and `../gist` of its own, and the build installs gist's header
beside ours. `actions/checkout` refuses to write outside the workspace, so the
workflow checks blast itself into a subdirectory and puts the other three
packages beside it; every relative path resolves at both levels then, because
that flat layout is the one each repo already assumes and the one a laptop
already has. relate is not a public repository, so its checkout reads a token
secret; the two public packages fetch without one.

The Python and Go jobs both build the engines before they run anything, since
every composed test is guarded on a resolvable binary and would otherwise skip
its way to a green tick over nothing.
