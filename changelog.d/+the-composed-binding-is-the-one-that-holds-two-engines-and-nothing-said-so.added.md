The Python binding has an import contract: `bindings/python/binding.zone`,
governing `blast-search` the way `charter.zone` governs the Zig side.

Smallest contract in the family, and the only one whose dependency list is the
point: composition needs both engines by definition, so `irgx` and `relate` are
both load-bearing here in a way they are nowhere else, and `gist` appears only
in the tests - a verdict this package reaches by composing two engines, checked
against the tool that answers it directly.

Needs `zoning` 1.3.1, which is where the `python` dialect and root-anchored
contracts both arrive.
