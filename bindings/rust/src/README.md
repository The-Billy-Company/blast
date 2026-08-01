---
doc_radar:
  sentinels:
    - description: "the four composed verbs (exact narrow, then compression)"
      file: bindings/rust/src/lib.rs
      contains: ["pub fn context", "pub fn family", "pub fn provenance", "pub fn blast"]
    - description: "context and family require an explicit scope"
      file: bindings/rust/src/verbs.rs
      contains: ["everywhere", "Unrepresentable"]
    - description: "compose verbs live in blast's contract"
      file: ../../contract/compose.toml
      contains: ["[compose.verbs]"]
---

# `src/` — blast composed verbs

| File | Job |
|---|---|
| `lib.rs` | `context` · `family` · `provenance` · `blast` |
| `verbs.rs` | shared `Composed` builder over `[analytic.params].compose` |

The verb roster is owned by `blast/contract/compose.toml`. Row schemas stay in
`irregex/contract/analytic.toml`.
