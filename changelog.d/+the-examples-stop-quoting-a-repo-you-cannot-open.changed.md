The docs and the compose contract stopped citing the private monorepo this was
split out of. `blast.blast("WalletService")` was the first line of the Python
package docstring and the example in `contract/compose.toml` narrowed on the
same name; neither resolves for anyone who does not already have that tree, and
a blast radius example is worthless if the reader cannot picture the symbol. It
is `SessionStore` now, which asks the same question of the same machinery.

The provenance note no longer quotes the internal package path it was cut from -
the commit is the part that can actually be checked - and the scope section warns
about sweeping `vendor/`/`upstream/` rather than `.etc`, which was another
convention that did not survive the move out.
