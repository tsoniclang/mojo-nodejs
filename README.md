# mojo-nodejs

Native Mojo implementations and provider metadata for Tsonic's explicit
Node.js capability. Installing this package does not activate the JavaScript
source surface: paths, process values, and filesystem text use native Mojo
`String`, while binary data uses `Buffer`.

The package is pinned to the same Mojo toolchain as `@tsonic/mojo-runtime`.
Its TypeScript provider layer is composed by `@tsonic/target-mojo`; the Mojo
modules in `mojo/tsonic_node` contain only target-native runtime behavior.

The certified provider foundation currently covers:

- `node:buffer`: the native `Buffer` carrier;
- `node:fs`: existence, stat/lstat, binary and UTF-8 reads, binary and text
  writes, copy, rename, symlink, realpath, unlink, and `Stats` kind queries;
- `node:path`: normalize, absolute-path tests, dirname, extname, basename, and
  relative paths;
- `node:os`: platform, architecture, hostname, temporary directory, and home
  directory; and
- `node:process`: current directory, directory changes, and exit.

Provider identities and overloads are exact closed data. Missing operations do
not fall back to runtime name lookup.
