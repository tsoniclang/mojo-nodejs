# mojo-nodejs

Native Mojo implementations and provider metadata for Tsonic's explicit
Node.js capability. Installing this package does not activate the JavaScript
source surface: paths, process values, and filesystem text use native Mojo
`String`, while binary data uses `Buffer`.

The package is pinned to the same Mojo toolchain as `@tsonic/mojo-runtime`.
Its TypeScript provider layer is composed by `@tsonic/target-mojo`; the Mojo
modules in `mojo/tsonic_node` contain only target-native runtime behavior.

The provider exposes these canonical module families:

- `node:assert`, `node:buffer`, `node:child_process`, and `node:crypto`;
- `node:fs`, `node:fs/promises`, `node:path`, `node:os`, and `node:process`;
- `node:dns`, `node:dns/promises`, `node:http`, `node:https`, `node:net`, and `node:tls`;
- `node:events`, `node:readline`, `node:stream`, and `node:timers`;
- `node:url`, `node:util`, `node:worker_threads`, and `node:zlib`.

Module presence does not imply the complete Node API. In particular, the
filesystem watch/stream factory families, modern URL objects, process memory
queries and additional APIs present in the C# capability are not yet at parity.

Hash and HMAC use the existing pinned OpenSSL dependency, with shared native
handle ownership, incremental updates and exact finalization behavior. String
and Buffer keys/data, encoded or binary digests, `randomBytes` and `randomUUID`
have explicit provider contracts. Random bytes come from OpenSSL's secure random
generator, not a language PRNG. `process.stdin` consumes the same Readable contract
as `node:stream`; `process.version` identifies this runtime as `tsonic-mojo`.

Provider identities and overloads are exact closed data. Missing operations do
not fall back to runtime name lookup.
