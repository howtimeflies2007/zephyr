# CLAUDE.md — `subsys/bluetooth/controller/ll_sw/`

The software Link Layer implementation. Loaded when reading files here. Inherits from `subsys/bluetooth/controller/CLAUDE.md`, `subsys/bluetooth/CLAUDE.md`, and root.

## What lives here (verified at pinned SHA `c2dc4ea`)

```
ll_sw/
├── ull.c                                ← ULL core, dispatcher entry
├── ull_internal.h                       ← ULL types shared across roles
├── ull_adv.c, ull_adv_aux.c, ull_adv_sync.c, ull_adv_iso.c
├── ull_scan.c, ull_scan_aux.c
├── ull_sync.c, ull_sync_iso.c
├── ull_central.c, ull_peripheral.c
├── ull_conn.c                           ← Connection event ULL side
├── ull_conn_iso.c                       ← (Phase 5 scope)
├── ull_central_iso.c, ull_peripheral_iso.c  ← (Phase 5 scope)
├── ull_iso.c                            ← (Phase 5 scope)
├── ull_filter.c, ull_chan.c, ull_df.c
├── ull_sched.c                          ← Pre-emption / role conflict resolution
├── ull_tx_queue.c, ull_tx_queue.h
├── ull_llcp.c, ull_llcp.h               ← LLCP entry
├── ull_llcp_cc.c, ull_llcp_chmu.c, ull_llcp_common.c
├── ull_llcp_conn_upd.c, ull_llcp_enc.c
├── ull_llcp_local.c, ull_llcp_past.c
├── ull_llcp_pdu.c, ull_llcp_phy.c
├── ull_llcp_remote.c, ull_llcp_features.h
├── lll.h, lll_*.h                       ← GENERIC LLL contract headers (top-level)
├── lll_chan.c, lll_chan.h               ← Generic channel selection
├── lll_common.c                         ← Generic LLL helpers
├── ll_addr.c, ll_feat.c, ll_settings.c  ← LL public API helpers
├── ll_tx_pwr.c, ll_test.h
├── pdu.h, pdu_df.h                      ← PDU type defs
├── isoal.c, isoal.h                     ← ISO Adaptation Layer (Phase 5 scope)
├── nordic/                              ← Nordic vendor impl (see nordic/CLAUDE.md)
│   ├── lll/                             ← Nordic LLL .c implementations
│   ├── hal/                             ← Nordic HAL (radio, timer, ECB, CCM, ...)
│   └── hci/                             ← Nordic HCI vendor extensions
├── openisa/                             ← NXP RV32M1 vendor impl (out of primary scope)
└── shell/                               ← Bluetooth controller shell commands
```

**Note**: There is NO `lll/` subdirectory at top level. The generic LLL
contract is the set of `lll_*.h` files at the top of `ll_sw/` itself,
mixed in with `ull_*.c`. The only `lll/` subdirectory is `nordic/lll/`
(vendor implementation). Don't go looking for a `lll/` subdir — you
won't find it at this SHA.

## ULL ↔ LLL boundary (the critical concept)

**ULL** (Upper Link Layer) — `ull*.c` at this level. Runs in:
- Thread context (most init paths, settings, registration)
- Mayfly context (most steady-state work, scheduled at LL event boundaries)

**LLL** (Lower Link Layer) — generic contract in `lll_*.h` here; concrete impl in `nordic/lll/lll_*.c`. Runs in:
- Radio ISR context (PHY-tight)
- SWI context (mayfly-adjacent post-processing)

**Mayfly is the bridge**. Inter-context handoffs use `mayfly_*()` calls from `subsys/bluetooth/controller/util/mayfly.c`. See `util/CLAUDE.md`.

## Generic LLL contract (in this directory's top level)

The generic LLL contract is a set of `lll_*.h` headers and a few `.c` helpers (`lll_chan.c`, `lll_common.c`) sitting at the top level of `ll_sw/`.

### Headers defining the contract

| Header | Defines |
|---|---|
| `lll.h` | Top-level types: `struct lll_hdr`, `struct lll_prepare_param`, prepare/done hooks |
| `lll_adv.h`, `lll_adv_aux.h`, `lll_adv_sync.h`, `lll_adv_iso.h` | Advertising LLL contracts |
| `lll_scan.h`, `lll_scan_aux.h` | Scanning |
| `lll_sync.h`, `lll_sync_iso.h` | Periodic sync (rx side) |
| `lll_central.h`, `lll_central_iso.h`, `lll_peripheral.h`, `lll_peripheral_iso.h` | Role-specific contracts |
| `lll_conn.h`, `lll_conn_iso.h` | Connection event contract |
| `lll_chan.h` | Channel selection algorithm (CSA #1, #2) |
| `lll_clock.h` | Clock domain helpers |
| `lll_filter.h` | FAL / RL accept list |
| `lll_sched.h` | LLL scheduling primitives |
| `lll_iso_tx.h`, `lll_df.h` | ISO Tx (Phase 5), Direction Finding |

### Generic `.c` files

| File | What it does |
|---|---|
| `lll_chan.c` | Channel selection algorithm (vendor-neutral) |
| `lll_common.c` | Shared LLL helpers across roles |

Vendor implementations of all role-specific `lll_*` contracts live in `nordic/lll/lll_*.c` (and `openisa/lll/lll_*.c`). Headers here declare prototypes; vendor `.c` files supply bodies.

### ISR-context rules (NON-NEGOTIABLE for LLL code)

Any code participating in the LLL — inline helpers from `lll_*.h` here OR vendor `lll/lll_*.c` files — runs in ISR context. These rules apply to all LLL code:

| Forbidden in LLL | Why |
|---|---|
| `k_malloc`, `k_free` | Allocator is not ISR-safe |
| `k_mutex_lock`, blocking `k_sem_take` | Blocking from ISR is undefined |
| `k_sleep`, long `k_busy_wait` | Burns radio timing budget |
| `printk`, `LOG_INF`/`LOG_DBG` (typically) | Slow, may pre-empt timing |
| Filesystem ops (`settings_save`, `fs_*`) | Slow + blocking |
| Recursive calls into ULL | Cross-context discipline broken |

**Allowed in LLL** (lock-free or pool-based):
- `net_buf_alloc(&pool, K_NO_WAIT)` from pool sized for LLL use
- `mayfly_enqueue()` — canonical way to escape ISR back to ULL
- `radio_*()`, `hal_*()`, `pdu_*()` direct calls
- `irq_disable`/`irq_enable` for short critical sections
- Logging IF gated by `CONFIG_BT_CTLR_LOG_INTERFACE` at low verbosity only

### ULL → LLL mayfly handshake

```
ULL thread/mayfly side:                LLL ISR side:
──────────────────────                 ──────────────
ull_<role>_setup()
  └─ assemble lll_<role> struct
  └─ ticker_start(...)   ──ticker──►   radio_isr_*()  fires at scheduled tick
                                         │
                                         ▼
                                       lll_<role>_prepare()  (vendor impl)
                                         │ executes radio event
                                         ▼
                                       lll_done() / mayfly_enqueue(&done_mfy)
                                                                    │
                                                                    ▼ SWI fires
                                                          ull_done callback runs
                                                          (back in mayfly context)
```

Exact site names vary by role. Task 2.1's job is to nail them down with file:line.

### Vendor relationship pattern

Generic header here (declares):
```c
// ll_sw/lll_conn.h
int lll_conn_prepare(struct lll_prepare_param *prepare_param);
```

Nordic implementation (defines):
```c
// ll_sw/nordic/lll/lll_conn.c
int lll_conn_prepare(struct lll_prepare_param *prepare_param)
{
    // nRF-specific radio setup + state machine
}
```

**Phase 2 R2 rule**: when claiming "the LLL does X", verify whether the contract (top-level `lll_*.h`) declares X as a hook, OR the vendor impl does X internally:
- If declared in generic header → tag `[LLL-CONTRACT]`
- If only in `nordic/lll/lll_*.c` or `nordic/hal/` → tag `[LLL-NORDIC]`

## Files most relevant to Phase 2 tasks

| Task | File(s) | What to look for |
|---|---|---|
| 2.1 (LLL/ULL split) | `ull.c`, `ull_internal.h`, `lll_common.c`, `nordic/lll/lll.c` | Where ULL submits work to LLL, where LLL returns. Both generic dispatcher (`lll_common.c`) and Nordic dispatcher (`nordic/lll/lll.c`) involved. |
| 2.2 (scheduler) | `ull_adv.c`, `ull_scan.c`, `ull_conn.c`, `ull_sched.c`, `ticker/ticker.c` | Role ticker registration sites; pre-emption logic in `ull_sched.c` |
| 2.3 (state machine) | `ull_conn.c`, `ull_llcp.c`, `ull_llcp_*.c` (especially `ull_llcp_enc.c`, `ull_llcp_conn_upd.c`, `ull_llcp_phy.c`), `nordic/lll/lll_conn.c` | Connection states + LLCP transitions |
| 2.4 (vendor HAL) | `nordic/hal/`, `nordic/lll/lll_radio.c` (if present), generic `lll_*.h` contract here | What vendor provides to generic LLL |

## Naming conventions (specific to ll_sw)

| Prefix | Layer | Typical context |
|---|---|---|
| `ll_*()` | Public LL API (called from `controller/hci/hci.c`) | Thread |
| `ull_*()` | ULL internal | Thread / mayfly |
| `ull_<role>_*()` | Role-specific ULL | Mayfly mostly |
| `ull_llcp_*()` | LLCP procedures | Mayfly |
| `lll_*()` | LLL contract + dispatcher (impl varies by vendor) | ISR / SWI |
| `radio_*()`, `hal_*()` | Vendor HAL (Nordic) | ISR / direct hardware |
| `ticker_*()` | Scheduler (in `ticker/` subdir) | SWI (with thread-side helpers) |
| `mayfly_*()` | Cross-context message (in `util/` directory) | All |
| `pdu_*()`, `*_pdu_*` | PDU helpers | Caller's context |

## Connection lifecycle (read before Task 2.3)

States and owning files. Phase 2 Task 2.3's job is to nail these down precisely:

| State | Owning files | Spec ref (sketch) |
|---|---|---|
| Idle | (no `bt_conn` allocated) | — |
| Initiating | `ull_central.c`, `nordic/lll/lll_scan.c` | [Core 6.x, Vol 6, Part B, §4.5.2] |
| Connecting (anchor pending) | `ull_conn.c`, `nordic/lll/lll_conn.c` | [§4.5.2] |
| Connected | `ull_conn.c`, `nordic/lll/lll_conn.c` | [§4.5.6] |
| LLCP active (encryption / phy / interval update / ...) | `ull_llcp_*.c` (one file per procedure) | [§5.1.x] |
| Terminating | `ull_conn.c` | [§4.5.12] |

LLCP procedures each have a dedicated `ull_llcp_<proc>.c` file. **LL connection state** (overall conn) and **LLCP state machine** (procedure running inside a connection) are layered — don't conflate them.

## Common analysis pitfalls

1. **`ull_*.c` files are huge.** `ull_conn.c` alone is thousands of lines. Don't read top-to-bottom. Search for specific functions (e.g. `ll_create_connection`, `ull_conn_setup`) and follow from there.

2. **Function pointer indirection to vendor LLL.** ULL calls `lll_*()` from the generic contract; resolution at link-time goes to `nordic/lll/lll_*.c`. Cite the vendor concrete impl in artifacts, tag `[LLL-NORDIC]`.

3. **LLCP procedures span multiple files.** A single encryption-start touches `ull_llcp_enc.c` (state), `nordic/lll/lll_conn.c` (on-air), `nordic/hal/nrf5/ccm.c` (CCM peripheral setup). For Phase 2, identify procedure entry and exit; don't trace every byte of state.

4. **`split` vs legacy controller.** Modern Zephyr uses `BT_LL_SW_SPLIT=y` (ULL + LLL). At pinned SHA `c2dc4ea`, this is the default — already verified in Phase 0.

5. **Periodic adv / scan / sync spans multiple files.** `ull_adv_sync.c` (TX-side ULL) + `ull_sync.c` (RX-side ULL) + `nordic/lll/lll_sync.c` (RX-side LLL). Adv side = transmit; sync side = receive.

6. **`ull_sched.c` is where role conflicts resolve.** When two roles want overlapping radio time (e.g. scanning + connection event), the pre-emption logic lives here, not in `ticker.c` (which just fires the timers). Task 2.2's "worked example" anchor.

7. **`ull_llcp.c` (newer code) vs older LLCP code.** The codebase may have multiple generations of LLCP machinery. `ull_llcp_*.c` files are the newer state-machine-driven implementation. Verify which generation is active at pinned SHA.

## Strict scope for Phase 2

- **In scope**: `ull_*.c` (excluding iso), `lll_*.h` and `lll_*.c` at top level, `nordic/`, `ticker/` (separate subdir under `controller/`), `pdu_*.h`
- **Out of scope (Phase 5)**: `isoal.c`, `ull_iso*.c`, `ull_conn_iso.c`, `ull_adv_iso.c`, `ull_sync_iso.c`, `ull_central_iso.c`, `ull_peripheral_iso.c`, anything `*_iso_*`
- **Out of scope entirely**: `openisa/` (reference only — cite as comparison if needed but don't deep-dive), `shell/`

## Phase 2 deliverables anchored here

- **Task 2.1** (`lll-ull-split.md`) sourced primarily from `ull.c`, `ull_internal.h`, `lll_common.c`, plus `util/mayfly.c` and `nordic/lll/lll.c` for the vendor dispatch side.
- **Task 2.2** (`scheduler.md`) sourced from `ull_adv.c`, `ull_scan.c`, `ull_conn.c` (role registration), `ull_sched.c` (pre-emption), and `controller/ticker/ticker.c`.
- **Task 2.3** (`state-conn.mmd` + commentary) sourced from `ull_conn.c` (overall states) and `ull_llcp_*.c` (LLCP sub-states), paired with `nordic/lll/lll_conn.c` for on-air behavior.
- **Task 2.4** (`vendor-hal.md`) primarily reads `nordic/hal/` (radio, timer, ECB, CCM, mayfly-SWI) and `nordic/lll/lll_*.c`; uses generic `lll_*.h` here as "what the contract needs".
- **Task 2.5** (`integration-narrative.md`) "HCI_LE_Create_Connection → first encrypted ATT packet on air" traverses this directory most heavily.
