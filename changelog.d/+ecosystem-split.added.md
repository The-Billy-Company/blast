`blast` is its own package: the composed face extracted from
`billy/libs/kernels/irregex` at billy@ce430bbaab. It ships the `irregex`
binary (`blast` / `provenance`) over the `irregex`, `relate`, and `gist`
packages; the composed engines live in relate's compose tier, and the package
name frees `irregex` for the library.
