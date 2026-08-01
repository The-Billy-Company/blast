The Python binding declared `requires-python = ">=3.14,<3.15"`, which was the monorepo's pinned interpreter wearing the costume of a library requirement. It is now `>=3.12`, tracking the `irregex` substrate this package cannot import without, with no upper bound.

The lower bound locked out 3.12 and 3.13 for no reason the source supports; the binding imports and runs there. The upper bound was the worse half, because it fails in the future: `<3.15` turns the day CPython 3.15 ships into the day this package stops resolving.
