# Retained line input

```ts
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const input = createReadStream("answers.txt", { highWaterMark: 1 });
const lines = createInterface({ input });
lines.question("first? ", first => {
  lines.question("second? ", second => {
    console.log(first, second);
    lines.close();
    input.close();
  });
});
```

Question registration does not read a descriptor or call its callback. The
existing Node event loop advances the selected Readable owner. A native request
duplicates the descriptor, holds its bytes through completion, and publishes
pending, data, EOF or error without blocking the event-loop thread. Polling
never changes the process-wide descriptor flags. Closing an interface cancels
its question, not its caller-owned input or output streams.

Line input preserves split UTF-8, CR/LF delimiters, blank lines and final
unterminated text. Adjacent questions in callbacks consume following lines from
the same physical chunk. Simulated input through `write` remains independent
of prompt output. A temporarily empty read is not an empty answer. Callback
reentry and failure retain other pending interfaces and already accepted lines.
Native String is the public carrier; no implicit public JsString is introduced.

Each native read is limited to 1 MiB; live requests are limited to 256 and their
combined storage to 64 MiB. The parser bounds each line at 16 MiB, retained text
at 64 MiB and complete lines at 1,048,576. Exceeding a bound raises an error,
never truncates input. Cancellation releases delivery ownership immediately;
an OS read already running may retain its bounded storage until completion.
Regular files use libuv's file workers. Pipes, terminals and other non-regular
descriptors use a separate pool of at most 32 waiting native threads, each with
a 256 KiB stack. Idle questions therefore cannot occupy the global libuv file
workers and starve unrelated file IO. The descriptor's exact native metadata
chooses this mechanism; no global worker setting or descriptor flag is changed.

History controls retain their independent declared meanings for terminal input.
This contract does not assert support for undeclared terminal key editing,
arbitrary user stream subclasses, or promise-based readline overloads.

Native ownership, parser, runtime, exact provider and compiled Pudding proofs
are authored in the current coding batch. They have not yet been executed.
