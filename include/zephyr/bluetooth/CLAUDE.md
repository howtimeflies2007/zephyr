# CLAUDE.md — `include/zephyr/bluetooth/`

Public API headers for the BLE subsystem. **Read-only and stable surface.** Loaded when reading files here. Inherits from root `CLAUDE.md`.

## What this directory is

The application-facing API for Zephyr's BLE stack. Everything here is intended to be stable for users of Zephyr — function signatures, types, struct layouts, callback shapes.

**Critical distinction:**

| Location | Purpose | API surface? |
|---|---|---|
| `include/zephyr/bluetooth/*.h` | Public API | YES — stable |
| `subsys/bluetooth/host/*.h` | Host-internal | NO |
| `subsys/bluetooth/host/*_internal.h` | Host-internal, explicit | NO |
| `subsys/bluetooth/controller/**/*.h` | Controller-internal | NO |

If a Phase 1 artifact claims "the application calls X", X must live under this directory. If it lives under `subsys/`, the claim is wrong — the application is calling something else that calls X.

## Files most relevant to Phase 1

| File | What it defines | Why Phase 1 cares |
|---|---|---|
| `hci_types.h` | Bluetooth Core Spec types: OGFs, OCFs, event codes, struct layouts | **Task 1.1's sole input** |
| `hci.h` | HCI helper macros (`BT_HCI_OP_*`, opcode packing) | Cited alongside hci_types.h |
| `bluetooth.h` | `bt_enable`, `bt_disable`, init callbacks | Entry-point side of host trace |
| `conn.h` | `bt_conn` opaque handle, connection callbacks | Connection-establish trace |
| `addr.h` | `bt_addr_t`, `bt_addr_le_t`, addr type constants | Used everywhere |
| `uuid.h` | UUID types | Used by adv data / GATT |
| `gap.h` *(if present at SHA)* | GAP constants (event types, roles) | Phase 4 mainly, but referenced in Phase 1 examples |

Outside Phase 1 scope but in this directory:
- `gatt.h`, `att.h`, `l2cap.h`, `iso.h` — Phase 3
- `mesh.h`, `mesh/*.h` — out of scope
- `audio/*.h` — out of scope for Phase 1; LL-level ISO is in scope (`iso.h`)
- `crypto.h` — Phase 3 (SMP-adjacent)

## `hci_types.h` — Phase 1's anchor

This file is the closest thing Zephyr has to a Bluetooth Core Spec mirror in C. Phase 1 Task 1.1 builds its taxonomy from this file alone.

Useful internal structure:
- **Opcode definitions**: `BT_HCI_OP_*` macros pack OGF/OCF. Search by prefix.
- **Struct layouts**: `struct bt_hci_cmd_*` for commands, `struct bt_hci_evt_*` for events, `struct bt_hci_rp_*` for return parameters.
- **LE Meta subevent codes**: `BT_HCI_EVT_LE_*` for the 0x3E meta event family.
- **Packed structs**: protocol-touching structs are `__packed` for wire layout. Field order matches the spec exactly.

When citing a command or event in a Phase 1 artifact:
- File: `include/zephyr/bluetooth/hci_types.h`
- Line: where the opcode macro or struct is defined
- Spec section: e.g. `[Core 6.0, Vol 4, Part E, §7.8.9]` for HCI_LE_Set_Advertising_Enable

## API stability conventions

Some symbols here are explicitly **experimental** — they may be marked with `@experimental` doxygen tags or guarded by `CONFIG_BT_*_EXPERIMENTAL`. Treat these as in-flux: their presence in a public header does NOT imply stable contract. Flag any experimental usage in Phase 1 artifacts.

Function-pointer typedefs for callbacks live here too. The struct types that contain them (e.g. `bt_conn_cb`, `bt_le_scan_cb`) define the user-facing callback shapes.

## Common analysis pitfalls in this directory

1. **`__packed` does not mean "matches the wire byte-for-byte on every CPU".** On platforms with strict alignment, `__packed` access goes through byte-by-byte loads. The struct *layout* matches the spec; runtime access is compiler-magic'd.
2. **Some types have both opaque and concrete forms.** `bt_conn` is opaque in the public header (`typedef struct bt_conn bt_conn;`); the actual struct definition lives in `subsys/bluetooth/host/conn_internal.h`. Application code only ever sees pointers.
3. **Header inclusion order matters for some files.** A few rely on `<zephyr/sys/util.h>` or similar being already pulled in. Don't try to `#include` these in isolation as standalone files when verifying claims — read them in-context.
4. **Versioned API changes happen.** Across Zephyr LTS releases, `bt_hci_driver` evolved into `bt_hci_driver_api`; `bt_buf_get_evt` consolidated with `bt_buf_get_rx`. The pinned SHA fixes the version; do not generalize across versions in an artifact.

## Phase 1 reminders

- **READ-ONLY.** This is the strictest read-only directory in the analysis — even more than `subsys/bluetooth/`. These headers are user-facing API and a stray edit could break every Zephyr application.
- **Use as ground truth for protocol structures.** When a Phase 1 artifact needs to describe a packet layout, cite the `__packed` struct here rather than re-stating the spec.
- **Don't trace into here.** Headers don't have call chains; they have declarations. Tracing tasks (1.2, 1.3) cite this directory when defining the *interface boundary*, not as a hop in the trace.

## Phase 1 deliverables anchored here

- Task 1.1's entire taxonomy (commands by OGF, events including LE Meta subevents) is built from `hci_types.h`.
- Task 1.2 and 1.3 cite `hci_types.h` for any HCI struct/opcode they reference along the trace.
- Task 1.4's diagram captions can use canonical spec terminology (`HCI_LE_Set_Advertising_Enable`) sourced from this directory.
