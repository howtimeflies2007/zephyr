# CLAUDE.md — `subsys/bluetooth/controller/util/`

Controller-internal infrastructure: lock-free messaging (mayfly), multi-context FIFOs, and double-buffering. Inherits from `controller/CLAUDE.md` and ancestors.

> This directory is **the glue between contexts**. Phase 2 Task 2.1's
> mayfly handoff sites all bottom out here. Get this right and split-LL
> becomes legible; get it wrong and ULL/LLL look like spaghetti.

## What lives here

```
util/
├── mayfly.c, mayfly.h          ← Cross-context message passing
├── mem.c, mem.h                ← Per-pool fixed-size allocator (alternative to net_buf)
├── memq.c, memq.h              ← Singly-linked memory queues
├── mfifo.h                     ← Multi-FIFO macros (typed, lock-free SPSC)
├── dbuf.c, dbuf.h              ← Double-buffer primitive
└── util.c, util.h              ← Misc helpers
```

## Mayfly (the most important file in this directory)

`mayfly.c` implements **deferred function calls between contexts** with a fixed memory footprint and lock-free semantics. It is what makes split-LL possible.

### Core operations

| Function | What it does | Context |
|---|---|---|
| `mayfly_init(...)` | One-time setup per machine | Init only |
| `mayfly_enqueue(callee_id, caller_id, prio, mfy)` | Queue a function to run in target context | Any |
| `mayfly_run(callee_id)` | Drain queued mayflies for this context | The target context |
| `mayfly_is_enabled(...)` | Check if a context is up | Any |

### The `struct mayfly`

```c
struct mayfly {
    memq_link_t *_link;     // memq linkage
    void *param;             // user data passed to fp
    void (*fp)(void *);      // function to invoke in target context
};
```

**Mayfly structs are statically allocated** by the caller. Same struct cannot be re-enqueued until the previous invocation completes. This is why you see `static struct mayfly` declarations sprinkled in ULL code — one per "kind of handoff".

### Caller / callee IDs

Mayfly distinguishes contexts by ID:

| ID (typical) | What it represents | Vendor mapping |
|---|---|---|
| `MAYFLY_CALL_ID_0` | Lowest-prio thread context | Often the controller's worker thread |
| `MAYFLY_CALL_ID_1` | Mid-prio (SWI / ULL_LOW) | A lower-prio EGU SWI on Nordic |
| `MAYFLY_CALL_ID_2` | High-prio SWI / ULL_HIGH | A higher-prio EGU SWI on Nordic |
| `MAYFLY_CALL_ID_PROGRAM` | LLL ISR context | Radio IRQ |

(Exact constants and counts at pinned SHA must be verified — these names are illustrative of the pattern.)

### Priority and pre-emption

Within a target context, mayflies have priorities (`MAYFLY_PRIO_*`). Higher priority drains first. Across contexts, the **target context's interrupt priority** determines whether enqueuing pre-empts the current context.

A typical "ISR → mayfly → ULL high-prio SWI → ULL low-prio SWI → thread" cascade is the canonical pattern for "do as little as possible in radio ISR, defer everything else".

## Multi-FIFO (`mfifo.h`)

Macro-defined typed lock-free FIFOs (single-producer / single-consumer most common). Used for inter-context data passing where mayfly is too coarse (mayfly delivers a function call; mfifo delivers a payload).

Pattern:
```c
MFIFO_DEFINE(prep, sizeof(struct mfy_prepare), 8);   // 8 slots
// producer:
struct mfy_prepare *p = MFIFO_ENQUEUE_GET(prep, &idx);
// ...fill *p...
MFIFO_ENQUEUE(prep, idx);
// consumer:
struct mfy_prepare *p = MFIFO_DEQUEUE_GET(prep);
// ...consume *p...
MFIFO_DEQUEUE(prep);
```

The `_GET / not-yet-released / final` two-phase pattern allows the producer to fill the slot WITHOUT lock — the consumer waits on the explicit second-phase commit.

## Memory queue (`memq.c`)

Singly-linked list of `memq_link_t` nodes. Used for variable-sized work queues (unlike mfifo which is fixed slots). Less efficient than mfifo for hot paths but more flexible.

## Double-buffer (`dbuf.c`)

Generic "current / next" buffer pair. Used for things like the connection's tx/rx buffer where one side is being prepared by ULL while LLL ISR consumes the other.

## Per-context rules (recap from controller/CLAUDE.md)

When citing functions from this directory in artifacts, note context:

| Function | Safe in ISR? | Safe in mayfly/SWI? | Safe in thread? |
|---|---|---|---|
| `mayfly_enqueue` | YES (designed for it) | YES | YES |
| `MFIFO_ENQUEUE` | YES | YES | YES |
| `MFIFO_DEQUEUE` | YES | YES | YES |
| `mem_*` allocator | NO (uses k_mem) | Sometimes | YES |
| `memq_peek/enqueue` | YES (lock-free) | YES | YES |

When in doubt: lock-free queue ops (mayfly, mfifo, memq) are designed for cross-context use; allocators are not.

## How this directory connects Phase 2's pieces

```
[Task 2.1]                          [Task 2.4]
 ULL ─┐                              ┌─ Vendor HAL
      │                              │    (Nordic EGU / SWI)
      ▼                              ▼
   mayfly_enqueue ──────────► mayfly_run
   (this dir)                  (this dir)
      │                              │
      ▼                              ▼
   [Task 2.2 — ticker]      [Task 2.3 — LLL ISR
    fires roles at slot      runs procedures]
    boundaries via mayfly
```

The four parallel tasks all reach into this directory. **Task 2.5's synthesis** uses mayfly as the unifying narrative thread.

## Common pitfalls

1. **Don't confuse `mayfly` (call-deferral) with `net_buf` (data buffer)**. They're orthogonal. A function called via mayfly may operate on net_buf data, but the two systems are separate.

2. **Same mayfly struct re-enqueued before completion = corruption**. ULL code uses arrays of mayfly structs indexed by role/connection to avoid this. When tracing, identify the array and the indexing scheme.

3. **`mfifo` macros generate static variables** with names like `_mfifo_<name>_n`, `_mfifo_<name>_first`, etc. These are visible to grep but hidden in source. Don't think they're missing.

4. **Memory pools here are NOT `net_buf` pools**. `mem.c` provides simpler fixed-size pools without the buffer chaining + metadata of net_buf. Used where net_buf overhead is too much (LLL paths).

## Phase 2 deliverables anchored here

- **Task 2.1** (LLL/ULL split) must cite at least 3 `mayfly_enqueue` sites from this directory's perspective — typically:
  - ULL → LLL: ticker fires → ULL prepares mayfly → enqueues to LLL ISR id
  - LLL → ULL: LLL done → enqueues mayfly to ULL_HIGH/LOW SWI
  - LLL → thread: LLL done → enqueues mayfly to thread for ull_done callback
- **Task 2.2** uses ticker's mayfly bindings to show how role events fire
- **Task 2.5** narrative — every cross-tier handoff in the integration story goes through this directory
