# `blast` — composed verbs

Exact match narrows a candidate set; compression reasons inside it. The two
scores stay in separate fields — a composed answer never fuses them.

Depends on `irregex` (substrate) and `relate` (corpus helpers). Does not make
gist or relate verbs importable through `blast`.

| Module | Concern |
|---|---|
| `verbs.py` | `provenance` — quotation re-verified against live bytes |
| `radius.py` | `blast` — live blast radius of a symbol |

```bash
cd bindings/python && uv sync --group dev && uv run pytest
```
