# Readable Data And Encoding

```typescript
import { createReadStream } from "node:fs";

const input = createReadStream("message.txt", { highWaterMark: 1 });
input.setEncoding("utf8");
const chunk = input.read(2);
if (typeof chunk === "string") {
  console.log(chunk);
}
```

The stream owns one buffering state shared by its aliases. Without a decoder,
reads return native `Buffer` objects and retain zero-copy subviews where possible.
Selecting an encoding converts retained bytes and incrementally decodes future
input. UTF-8, UTF-16LE, ASCII, Latin-1, hex, base64 and base64url use the same
encoding policy as Buffer. Incomplete encoded units survive physical reads; EOF
flushes them once. Changing encoding preserves already-decoded text, installs a
new decoder and discards the old decoder's incomplete bytes, as Node does.

The declared read result is `Buffer | string | null`, because calling through an
alias cannot prove that a decoder is absent. `null` is absence of available data,
not `undefined`; `readableEnded` reports completed consumption. `bytesRead` counts
physical bytes independently of read lengths. Decoded sizes count UTF-16 units.

Strings at the public boundary remain native Mojo String. UTF-8 invalid bytes
use Buffer's replacement decoding. A UTF-16 result with an unpaired surrogate,
or a read size that bisects a surrogate pair, cannot be represented natively and
raises precisely. A rejected split does not consume the queued character, so
the caller can retry with a representable size. No implicit JsString is exposed.

Text buffering retains immutable backing chunks and cursor offsets. Repeated
small reads copy only their returned text, not the entire remaining queue.
File read encoding is also selectable through `ReadStreamOptions.encoding`.
Unknown encodings reject before opening files or changing an existing stream.

This describes the written implementation contract, not a certification claim.
Native/source/Pudding proofs are authored and run only after the full coding
phase. Event flow, user stream subclasses and object-mode support have separate
contracts and are not implied by decoded reads.
