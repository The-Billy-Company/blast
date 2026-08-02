`blast blast Corpus` was the way in. Now it is `blast Corpus`, and the old spelling keeps working because the verb never went anywhere.

Every row in the report also says what kind of reference it is: `[use]` for a call site, `[def]` for a redeclaration, `[str]` for the name inside a string literal, and a `gen` suffix on any of them when the file is generated. That is the difference between a file to edit and a file to regenerate, and it used to be the reader's job to infer it from the path.

Dependents are ranked instead of listed in corpus order, so `--budget` trims codegen off the tail rather than whichever hand-written caller happened to sort last.
