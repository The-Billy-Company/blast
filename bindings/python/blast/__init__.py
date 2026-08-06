"""blast — composed verbs over exact match and compression.

Both engines on one question: `blast` (what moves if this symbol changes) and
`provenance` (where a pasted snippet came from, re-verified against live bytes).

    import blast

    radius = blast.blast("AcmeStore")
    print(radius.paths)
"""

from __future__ import annotations

from irgx.runtime import shell as engine
from irgx.runtime.errors import (
    GistError,
    GistNotFoundError,
    RowDecodeError,
    SchemaDriftError,
    SearchFailedError,
)

from .radius import Blast, Dependency, Mention, Reference, Ripple, Site, blast
from .verbs import Attribution, provenance

__all__ = [
    "Attribution",
    "Blast",
    "Dependency",
    "GistError",
    "GistNotFoundError",
    "Mention",
    "Reference",
    "Ripple",
    "RowDecodeError",
    "SchemaDriftError",
    "SearchFailedError",
    "Site",
    "binary",
    "blast",
    "engine",
    "provenance",
]


def binary() -> str:
    """Absolute path to the resolved `blast` binary."""
    return engine.blast_binary()
