# blast — Python binding

Importable face of the blast composed-search product. See
[`blast/README.md`](blast/README.md) for the package layout.

```bash
uv sync --group dev
uv run pytest
```

Depends on `irregex` and `relate` (path sources for local checkouts; PyPI for
published wheels). Behavioral tests also pull `gist` as a dev oracle.
