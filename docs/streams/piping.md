# Cooperative Pipe Ownership

```ts
const input = createReadStream("input.txt");
const first = createWriteStream("first.txt");
const second = createWriteStream("second.txt");
input.pipe(first);
input.pipe(second);
```

Both destinations receive each accepted source chunk. Pipe returns the exact
destination before transfer, and the Node event loop advances the retained
source. A read without data is not EOF. User pause and destination backpressure
are independent; an accepted write is never retried merely because it returned
false. EOF ends ordinary destinations once. Early source close does not
fabricate successful EOF; the standard-output producers explicitly retain
their independent do-not-end policy.

One source has a finite destination list, with exact closed Writable or
ServerResponse carriers. It does not select methods by name or reflect over
objects. Source aliases share IO progress, queued chunks and pipe membership.
Each polling turn advances at most one chunk per source. A failed owner is
detached and reports its error without discarding unrelated pending owners.
When no owner progresses, the loop waits for a native read completion or its
next timer deadline rather than sleeping unconditionally between file chunks.
The completion generation is captured before polling, so a completion just
before the wait cannot become a lost wakeup. Native waiting invokes no source
callback. Throughput and timer fairness remain final-verification gates.

This replaces the synchronous pipe loop completely. Tests inspect byte counts
and output after event-loop completion, not immediately after registering a
pipe. Native/source/Pudding proofs are written but remain unexecuted until the
end of the coding phase. General stream events and user-defined stream
subclasses are separate contracts, not implied by these two declared sinks.
