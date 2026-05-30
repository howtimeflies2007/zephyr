# CLAUDE.md — `subsys/bluetooth/host/`

The Bluetooth Host stack (above HCI). Loaded when reading files under this directory. Inherits from `subsys/bluetooth/CLAUDE.md` and root `CLAUDE.md`.

## Layered view (top to bottom)

```
Application API   (include/zephyr/bluetooth/*.h)
       │
       ▼
GAP roles         adv.c, scan.c, conn.c (init/peripheral), id.c
GATT              gatt.c, services/
ATT               att.c
SMP               smp.c, keys.c
L2CAP             l2cap.c, l2cap_br.c (classic), iso.c
       │
       ▼
HCI dispatch      hci_core.c, hci_core.h           ← top of HCI boundary
       │
       ▼ (out of this directory)
       drivers/bluetooth/hci/* OR controller/hci/*
```

## Key files for Phase 1 (HCI Boundary)

| File | What it does | Why it matters for Phase 1 |
|---|---|---|
| `hci_core.c` | HCI command dispatch, event handling, RX thread, TX queue | Task 1.2 entry point |
| `hci_core.h` | `bt_dev` struct, internal HCI API | Defines what HCI driver provides |
| `conn.c` | `bt_conn` lifecycle, connection-bound TX | Buffer-flow source (Task 1.6) |
| `adv.c` | Advertising state machine | Canonical example `bt_le_adv_start` starts here |
| `id.c` | Identity / address management | Touches HCI for RPA generation |

## Threading model

Host runs in cooperative-priority threads + workqueues. **Anything tagged [HOST] in analysis must clarify which thread.**

| Thread / WQ | What it does | Defined in |
|---|---|---|
| BT RX thread | Drains incoming buffers from controller, dispatches events | `hci_core.c` — `K_THREAD_DEFINE` or `k_thread_create` |
| TX thread (where present) | Drains outgoing command queue | `hci_core.c` |
| System workqueue | Settings flushes, callbacks | shared with rest of Zephyr |
| Per-conn TX queue | ACL data buffered per `bt_conn` | `conn.c` |

When citing a function, identify which thread it runs in. A function callable from multiple threads (often callback dispatch) gets labeled with all of them.

## net_buf pool conventions

Pools defined here (names vary slightly by SHA — verify):

| Pool | Sizing Kconfig | Direction |
|---|---|---|
| `hci_cmd_pool` | `CONFIG_BT_BUF_CMD_TX_COUNT` × `CONFIG_BT_BUF_CMD_TX_SIZE` | Host → Controller (commands) |
| `hci_rx_pool` | `CONFIG_BT_BUF_EVT_RX_COUNT/SIZE` | Controller → Host (events) |
| `acl_in_pool` | `CONFIG_BT_BUF_ACL_RX_COUNT/SIZE` | Controller → Host (data) |
| `acl_tx_pool` | `CONFIG_BT_L2CAP_TX_BUF_COUNT/MTU` | Host → Controller (data) |
| `frag_pool`, `discardable_pool` | various | Specialized |

Each pool's allocator/freer should be a thread-confined operation. Cross-thread frees use `net_buf_unref` which is safe but worth flagging.

## `bt_conn` refcounting (universal rule)

- `bt_conn_ref` / `bt_conn_unref` pairs must balance per execution path.
- Adding a conn to a tracking list = `bt_conn_ref` (now list owns one ref).
- Removing from list = `bt_conn_unref`.
- Callbacks typically **borrow** a ref already held by the caller — do not ref/unref in a callback unless you explicitly extend the lifetime.
- When tracing connection-related code, label each `bt_conn_ref` site with whose lifetime it extends.

## Naming conventions

| Prefix | Meaning |
|---|---|
| `bt_*` | Public API — defined in `include/zephyr/bluetooth/*.h`, callable from app |
| `bt_<module>_*` | Internal-but-cross-file (e.g. `bt_gatt_notify`) |
| `<module>_*` (static) | File-local only |
| `*_internal.h` | Directory-local types/decls, NOT public API |

When a function lives in a `_internal.h`, it is **not** part of the API surface — never cite it as "the application calls X" in a Phase 1 artifact.

## Settings (persistence) integration

`settings.c` bridges host state (keys, IDs, CCC values) to the Zephyr `settings` subsystem. Phase 1 doesn't need to dive here, but:
- `BT_SETTINGS` Kconfig gates persistence
- Key storage is the most security-sensitive surface; touched in Phase 3 (SMP), not Phase 1

## Common analysis pitfalls in this directory

1. **`bt_dev` is a singleton global.** Reads from `hci_core.c` look like "magic" until you realize most state hangs off `bt_dev`. Search for its definition first.
2. **`hci_event` dispatch is table-driven.** Don't trace the dispatcher itself; follow the table to the handler for your event of interest.
3. **LE Meta events have their own sub-dispatch.** Most events you care about (Connection Complete, Adv Report) are subevents of event 0x3E, dispatched via a second-level table.
4. **Combined-build optimizations.** In combined builds some HCI handoffs collapse into direct queue inserts (no transport-driver indirection). Note when you see this — it's correct but easy to mistake for a missing hop.

## Phase 1 deliverables anchored here

- Task 1.2's `## Host side` section of `boundary.md` is sourced from this directory.
- Task 1.6's host-side buffer enumeration is sourced from this directory.
- Task 1.4 needs the host's final pre-HCI hop to match the controller's first post-HCI hop — that point is the `bt_hci_driver` send/recv pair, defined here via `bt_dev.drv`.
