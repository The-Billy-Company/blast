The Python distribution is `blast-search`; the import is still `blast`. `blast`
on PyPI belongs to an unrelated author - a web music player - so the name was
never available to publish under, and, worse, a plain `pip install blast`
fetches that stranger's package into a tree that then imports `blast` and gets
whatever it contains. Splitting the two names closes that: `pip install
blast-search`, `import blast`, which is the same shape bs4, PIL, and cv2 already
ship, and the same split `gist-search` and `relate-search` made next door. Only
`[project].name` and the dependency spelling moved; the package directory, the
wheel's `packages` entry, and every `import blast` in the tree are untouched.

The repository also gets a release workflow, which is what forced the question.
It publishes one `py3-none-any` wheel plus a genuinely buildable sdist through
PyPI Trusted Publishing on a `v*` tag, and refuses to publish a tag that does
not name the declared version. Two gates run before anything leaves: the built
wheel must declare both `irregex` and `relate-search` as index-resolvable
requirements, because the `[tool.uv.sources]` paths that make a local checkout
work never reach core metadata and a wheel missing the sibling imports fine
right up until the first composed verb runs; and the artifact is installed on
the declared 3.12 floor from a directory that is not the project. That second
gate also enforces the ordering this face cannot avoid - the resolver goes to
the index for `relate-search`, so a blast release cannot land ahead of the
sibling it needs. The binary is not published: the Zig package is consumed
through a tag's tarball, and the CLI is built from source.
