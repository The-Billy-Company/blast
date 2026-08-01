//! Builder smoke — no binary required.
//!
//! Proves the composed request lowers into an argv the subprocess tier can
//! spell, and that scope refusal is a typed error rather than a silent sweep.

use blast::{context, provenance};

#[test]
fn provenance_needs_no_scope() {
    // Construction must not require a binary; answering may.
    let _ = provenance("pasted snippet");
}

#[test]
fn context_without_scope_is_unrepresentable() {
    let Err(err) = context("task text").pattern("TODO").rows() else {
        panic!("context without roots must refuse");
    };
    let msg = err.to_string();
    assert!(
        msg.contains("scope") || msg.contains("everywhere") || msg.contains("Unrepresentable"),
        "unexpected refusal: {msg}"
    );
}
