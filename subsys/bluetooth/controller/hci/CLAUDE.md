# CLAUDE.md — `subsys/bluetooth/controller/hci/`

The controller's HCI handler. **This directory is the controller-side mirror of `subsys/bluetooth/host/hci_core.c`.** Loaded when reading files here. Inherits from `controller/CLAUDE.md`, `subsys/bluetooth/CLAUDE.md`, and root.

## Role at the HCI boundary

```
                    ┌─────────────────┐
                    │  Host           │
                    │  hci_core.c     │
                    └────────┬────────┘
                             │ net_buf (combined)
                             │ or transport (controller-only)
                             ▼
                    ┌─────────────────┐
                    │  THIS DIRECTORY │
                    │  hci.c          │  ← command decode / event encode
                    │  hci_driver.c   │  ← transport / buffer I/O
                    └────────┬────────┘
                             │ ll_*() calls
                             ▼
                    ┌─────────────────┐
                    │  LL (ull_*.c)   │
                    └─────────────────┘
```

This is the **controller-side HCI seam**. Both Task 1.3 and the controller half of Task 1.6 live here.

## Files

| File | Responsibility |
|---|---|
| `hci.c` | HCI command decoding (switch on OGF/OCF), event encoding (build `bt_hci_evt_*`) |
| `hci_driver.c` | Transport binding: RX buffer dispatch into hci.c, TX of events to host |
| `hci_internal.h` | Shared types between hci.c and hci_driver.c |
| `hci_user_ext.c` *(if present)* | Vendor-specific HCI extensions |
| `nordic_pa_lna.c` *(if present)* | Optional Nordic FEM control via HCI |

## The two execution modes this directory handles

| Mode | How it works |
|---|---|
| **Combined** | `hci_driver.c` is wired directly to the host's `bt_dev.drv` via the `bt_hci_driver_api` ops. Commands/events pass as `net_buf` with no transport framing — the controller is just an in-process callee. |
| **Controller-only** | Same `hci_driver.c` code, but its TX path goes to an external transport (UART/SPI/USB). A wrapper application under `samples/bluetooth/hci_*` runs alongside, doing transport-side framing (H4 typically). |

In both cases, `hci.c` doesn't care about transport — it works on `net_buf` and dispatches to `ll_*()`. The transport detail is contained in `hci_driver.c` plus the wrapper sample (controller-only) or the host's transport driver (combined).

## Command dispatch pattern

`hci.c` typically has a structure like:

```c
static int <ogf>_cmd_handle(struct net_buf *cmd, ...) {
    switch (ocf) {
        case BT_OCF(...):
            return cmd_<name>(cmd, evt);
        ...
    }
}
```

Each `cmd_<name>` function:
1. Validates parameters (returns `BT_HCI_ERR_INVALID_PARAM` on failure).
2. Calls one or more `ll_*()` functions to perform the operation.
3. Builds a Command Complete or Command Status event.

**For Phase 1 Task 1.3, this is where the controller-side trace ends** — at the `ll_*()` call. Going into `ll_sw/ull_*.c` is Phase 2 territory.

## Event generation pattern

Outbound events use helpers like `hci_evt_create`, `meta_evt`, or direct `bt_buf_get_evt` + manual encode. Two flavors:

1. **Synchronous response** to a command — built inside the cmd handler, returned to dispatcher, sent before unblocking the host's `bt_hci_cmd_send_sync`.
2. **Asynchronous event** — built in response to an LL event (e.g. radio interrupt → ULL handler → mayfly to thread context → `hci_*_evt()` helper → push to host buffer queue).

LE Meta events (event 0x3E) share a single dispatcher; subevent codes distinguish them.

## ISO data and ACL data paths

ISO data (`hci_iso_*` functions) and ACL data (`hci_acl_*`) have their own paths through `hci.c` that bypass the command/event decode logic — they're data, not control. Phase 1 Task 1.6 maps these explicitly.

## Common analysis pitfalls in this directory

1. **`hci.c` is generated-feeling but hand-written.** The OGF/OCF dispatch tables look mechanical; resist the urge to skim — vendor-specific commands and conditional Kconfig gating hide there.
2. **`bt_buf_get_evt` and friends live in host code path even in combined build.** Combined-build buffer allocations from this directory often draw from host-side pools — Task 1.6 needs to capture this cross-half pool usage.
3. **`hci_driver.c` registers as a `bt_hci_driver`.** In combined builds, this registration is what makes `subsys/bluetooth/host/` see the controller as just another HCI driver — same API as a UART driver. **This is the literal point where Task 1.4's diagram converges.**
4. **`hci_internal.h` does cross-file type leaks.** Don't generalize types declared here to be public — they're handler-internal.

## Phase 1 deliverables anchored here

- Task 1.3's `## Controller side` section of `boundary.md` is sourced from this directory.
- Task 1.4's reconciliation must terminate the controller-side trace at the `bt_hci_driver_api`-equivalent registration in `hci_driver.c` (the function pointers populated here are the same ones the host calls via `bt_dev.drv->send`).
- Task 1.6 covers buffer pool allocation in `hci_driver.c` (e.g. event/ACL out pools used by combined builds).
