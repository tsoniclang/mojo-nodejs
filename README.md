# mojo-nodejs

Native Mojo implementations and provider metadata for Tsonic's explicit
Node.js capability. Installing this package does not activate the JavaScript
source surface: paths, process values, and filesystem text use native Mojo
`String`, while binary data uses `Buffer`.

The package is pinned to the same Mojo toolchain as `@tsonic/mojo-runtime`.
Its TypeScript provider layer is composed by `@tsonic/target-mojo`; the Mojo
modules in `mojo/tsonic_node` contain only target-native runtime behavior.
