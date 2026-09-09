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
worker executable-dispatch contract, complete stream/event integration and
additional network/path options are still being completed. The architecture
parity branch contains unverified implementation work, not a new certification.

Hash and HMAC use the existing pinned OpenSSL dependency, with shared native
handle ownership, incremental updates and exact finalization behavior. String
and Buffer keys/data, encoded or binary digests, `randomBytes` and `randomUUID`
have explicit provider contracts. Random bytes come from OpenSSL's secure random
generator, not a language PRNG. `process.stdin` consumes the same Readable contract
as `node:stream`; `process.version` identifies this runtime as `tsonic-mojo`.

Provider identities and overloads are exact closed data. Missing operations do
not fall back to runtime name lookup.

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
