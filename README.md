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

Module presence does not imply the complete Node API. Worker executable dispatch,
the declared stream/event lifecycle, standard filesystem options, socket listen
options and independent TLS controls have provider and native execution proofs.
Arbitrary stream subclasses and undeclared operations are not implied.

The pinned native compiler still fails the asynchronous file-content and
directory-copy executables during compilation. A retained async source filter
also requires an owning coroutine capture contract that the compiler does not
currently provide. Those positive tests remain enabled; the complete bank is
not all-green. Synchronous copy has independent native options, permissions,
symlink, filter and timestamp proofs, so an async compiler failure cannot hide
its results. Timestamp copying follows Node's rounded Stats Date values while
the numeric Stats millisecond fields retain their fractional precision.

Hash and HMAC use the existing pinned OpenSSL dependency, with shared native
handle ownership, incremental updates and exact finalization behavior. String
and Buffer keys/data, encoded or binary digests, `randomBytes` and `randomUUID`
have explicit provider contracts. Random bytes come from OpenSSL's secure random
generator, not a language PRNG. `process.stdin` consumes the same Readable contract
as `node:stream`; `process.version` identifies this runtime as `tsonic-mojo`.

Provider identities and overloads are exact closed data. Missing operations do
not fall back to runtime name lookup.

Buffer's provider type explicitly supplies its retained closed-value factory.
Assigning a Buffer to `unknown` preserves live bytes and Buffer identity; no
conversion to a JSON object occurs at assignment. Its `toJSON` presentation is
selected only by JSON serialization. Structured clone instead produces the
standard unsigned-byte view without the Buffer brand, while preserving shared
backing between related cloned views. This source/runtime slice has executed
provider and native proofs; it is separate from the async compiler failures.

Provider construction is nested under `nodejs/src/provider/model/`: source
types, native carriers, lifecycle definitions, declarations, and call/property
relations have separate owners. `model.ts` is the stable explicit export surface.
Feature records live beneath `provider/modules/`; native implementations live
in their corresponding `mojo/tsonic_node/` domains. Shared callback scheduling
belongs to `internal/callback_queue.mojo`, not to a feature's semantic model.

Native headers and vendored licenses are explicit runtime-manifest assets;
published projects do not require the original package source directory.

## Compression contracts

One native codec lifecycle serves convenience calls and incremental transforms.
Zlib and Brotli have distinct option records. Brotli uses its native numeric
`params` keys, exported through `constants`; it has no invented `quality` field.

```typescript
import { Buffer } from "node:buffer";
import { gzipSync, gunzipSync, createGzip } from "node:zlib";

const compressed = gzipSync(Buffer.from("payload"), { level: 1 });
const inspected = gunzipSync(compressed, { info: true });
const text = inspected.buffer.toString();
const consumedBytes = inspected.engine.bytesWritten;

const stream = createGzip();
stream.write("first");
stream.flush();
const firstChunk = stream.read();
stream.end("second");
const lastChunk = stream.read();
```

Literal `info: true` selects the engine/result record; `info: false` or an omitted
flag selects Buffer. An options variable with a runtime boolean returns their
union rather than pretending its result is always Buffer. `bytesWritten` counts
input consumed by the codec, including decompression's treatment of unused tails.
Flush/reset/parameter changes operate on retained native state. Outputs and
pending data have explicit finite limits; exceeding them raises an error.

## Path patterns

`path.matchesGlob(path, pattern)` and the explicit `posix`/`win32` dialects
share one lexical matcher. They do not read the filesystem. Input remains
native `String`; braces, character classes, extended patterns and whole-segment
`**` have separate grammar handling rather than wildcard text replacement.

```typescript
import path from "node:path";

path.matchesGlob("posts/2026/entry.md", "posts/**/*.{md,html}");
path.win32.matchesGlob("C:\\posts\\entry.md", "c:/posts/*.md");
```

Literal components compare directly. Pattern components use the existing
ECMAScript regex primitive, while globstars match component positions with
bounded state storage. A pattern exceeding 65,536 UTF-16 units, 65,536 brace
alternatives, 128 nesting levels or the 16 MiB generated-source budget rejects
explicitly. Matching is also capped at 16,777,216 component states across all
alternatives. These are resource errors, not false match results. Native,
source, differential and Pudding proofs exercise this contract.

DNS and compression callbacks receive `null` on success. Failed operations have
absent results, reflected in their source declarations. For example:

```typescript
import { gzip } from "node:zlib";

gzip(Buffer.from("payload"), (error, result) => {
  if (result !== undefined) {
    const bytes = result.length;
  }
});
```

Callbacks remain queued. If a callback throws, later queued completions are
retained ahead of callbacks enqueued during that invocation. This does not claim
that a native synchronous operation executes on a worker thread.
