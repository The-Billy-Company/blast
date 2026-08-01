`blast` is its own package: the composed face extracted from a private
monorepo package path (formerly `libs/kernels/irregex`) at ce430bbaab. It
ships the `blast` binary (`blast` / `provenance`) over the `irregex`,
`relate`, and `gist` packages; the composed engines live in relate's compose
tier, and the package name frees `irregex` for the library.
