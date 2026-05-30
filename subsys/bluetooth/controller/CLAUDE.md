# CLAUDE.md — `subsys/bluetooth/controller/`

The Bluetooth Controller stack (below HCI). Loaded when reading files under this directory. Inherits from `subsys/bluetooth/CLAUDE.md` and root `CLAUDE.md`.

## Top-down layout

```
controller/
├── hci/         ─ HCI handler: commands in, events out. See hci/CLAUDE.md
├── ll/          ─ Public LL API surface (ll_*() functions called from HCI handler)
├── ll_sw/       ─ Software Link Layer implementation
│   ├── ull_*.c  ─ Upper Link Layer (thread + mayfly context)
│   ├── lll/     ─ Generic LLL contract (headers, types)
│   ├── nordic/  ─ Vendor LLL: Nordic nRF radio
│   │   ├── lll/ ─ Nordic LLL implementation
│   │   └── hal/ ─ Nordic radio, timer, ECB, CCM HALs
│   ├── openisa/ ─ Vendor LLL: NXP RV32M1 (covered as reference only)
│   ├── ticker/  ─ Time-event scheduler
│   └── isoal.c  ─ ISO Adaptation Layer
└── util/        ─ Controller-internal infra: mem, mayfly, dbuf, mfifo
```

## The split-LL concept (most important thing in this directory)

The controller is split into two execution-context tiers connected by lock-free message passing:

```
   ┌─────────────────────────────────────────────┐
   │ HCI handler (controller/hci/)               │  ← thread context
   └─────────────────┬───────────────────────────┘
                     │ ll_*() calls
                     ▼
   ┌─────────────────────────────────────────────┐
   │ ULL — Upper Link Layer (ull_*.c)            │  ← thread + mayfly context
   │   - role management, LLCP, scheduling logic │
   └────────────────┬────────────┬───────────────┘
                    │ mayfly     ▲ mayfly
                    ▼            │
   ┌─────────────────────────────────────────────┐
   │ LLL — Lower Link Layer (lll/, nordic/lll/)  │  ← RADIO ISR context
   │   - on-air protocol, PHY-timed events       │
   └─────────────────┬───────────────────────────┘
                     │ vendor HAL
                     ▼
              Radio / Timer / CCM / RNG
```

| Tier | Context | Allowed operations |
|---|---|---|
| Thread | Normal preemptible / cooperative | Anything (blocking, allocations, logging) |
| Mayfly | Scheduled via SWI / fast-context | No blocking; pool allocs only; minimal logging |
| LLL / ISR | Radio IRQ | **NO blocking, NO allocations, minimal logging**, tight latency budget |

**This boundary is the entire reason the controller looks complex.** Phase 1 only touches the HCI handler (still thread context). Phase 2 is where the LLL/ULL split becomes load-bearing.

## Mayfly — the LLL ⇄ ULL postman

`util/mayfly.c` is a lock-free message-passing primitive. Used because radio ISR cannot block on a queue and cannot allocate. Senders prepare a `struct mayfly` (pre-allocated, statically-bound to the source context), enqueue it; receivers drain on their tick.

Mayfly callbacks themselves are short and bounded — they're effectively "deferred function calls" between contexts.

## Ticker — the radio event scheduler

`ll_sw/ticker/ticker.c` is a preemptive time-event scheduler. Roles (adv, scan, conn) register tickers; ticker fires them at scheduled times via SWI. Pre-emption logic resolves overlapping events by priority.

In Phase 1 you don't need to understand ticker internals — just know that **the controller is event-driven and time-sliced** under the hood. A function being "called" may actually mean "scheduled to fire at a specific BLE event boundary."

## Naming conventions

| Prefix | Layer | Context |
|---|---|---|
| `ll_*` | Public LL API (called from HCI handler) | Thread |
| `ull_*` | ULL internal | Thread / mayfly |
| `lll_*` | LLL internal | ISR (radio) |
| `radio_*`, `hal_*` | Vendor HAL | ISR / direct hardware |
| `ticker_*` | Scheduler | SWI / thread |
| `mayfly_*` | Message-passing | All contexts |

For Phase 1 (HCI dispatch only), almost every cited function should be `ll_*` or `ull_*`. If you find yourself citing `lll_*`, you've gone too deep — that's Phase 2.

## Vendor LLL boundary

- **Generic LLL contract**: `ll_sw/lll/lll.h`, `lll_*.h` — what every vendor LLL must provide.
- **Nordic implementation**: `ll_sw/nordic/lll/lll_*.c` — uses nRF radio peripheral, RTC, TIMER, ECB, CCM.
- **OpenISA implementation**: `ll_sw/openisa/` — NXP RV32M1. Out of scope for primary analysis; reference only.

**Critical rule**: claims about "the LLL" without qualification should refer only to the generic contract. Anything specific to register access, IRQ numbers, or peripheral quirks is vendor-specific — label it as such (`[LLL-NORDIC]`).

## Memory model in the controller

Controller does not use the kernel heap for hot paths. Pools:
- `util/mem.c` — generic pool allocator
- `util/mfifo.h` — multi-reader/writer FIFO (lock-free for SPSC, locked for MPMC)
- `util/dbuf.c` — double-buffered radio packets

Buffer flow at the HCI handler (Phase 1, Task 1.6 cares about this):
- Incoming HCI commands arrive as `net_buf` from `subsys/bluetooth/host/` (combined build) or from a transport driver (controller-only).
- Outgoing HCI events allocated from controller-side pools, pushed to host (combined) or to transport tx queue (controller-only).

## Phase 1 reminders specific to controller

- Phase 1 stops at the **HCI handler** boundary. Task 1.3 traces commands as far as the first `ll_*()` call. Going deeper is Phase 2.
- ISR-context functions (`lll_*`) are off-limits for Phase 1 tracing — note them as "delegated to Phase 2" if you encounter them.
- Build mode for tracing: combined. Controller-only builds add a transport-side dispatch loop in `hci/hci_driver.c` (or its `samples/bluetooth/hci_*` wrapper) — note that path's existence but don't trace it.

## Common analysis pitfalls in this directory

1. **`ull_*` files are huge.** Don't try to read them top-to-bottom. Search for the specific LL procedure (`ll_adv_enable`, `ll_create_connection`) — entry points are small.
2. **Function pointer indirection via vendor HAL.** Generic ULL calls `radio_*()` which is defined per-vendor. Cite the vendor concrete impl, label as `[CTLR-VENDOR]`.
3. **Spec procedures map to multiple files.** A single LLCP procedure (e.g. encryption start) spans `ull_conn.c` (state) + `lll/lll_conn.c` (on-air) + LLCP-specific files. Phase 1 doesn't go here, but flag the spread.
4. **`split` vs legacy controller.** Modern Zephyr uses the "split" LL (CONFIG_BT_LL_SW_SPLIT=y). Earlier non-split LL exists in older revisions. Verify which one you're at via the pinned SHA's Kconfig defaults.
