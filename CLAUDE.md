# CLAUDE.md — Zephyr RTOS (BLE Analysis Focus)

This file orients Claude Code to the Zephyr RTOS repository for the purpose of **systematic analysis of the Bluetooth Low Energy (BLE) subsystem**. It is factual, not instructional. Update it when conventions or layout change — stale context is worse than no context.

## What this repo is

Zephyr is a scalable, open-source RTOS targeting many architectures (Arm Cortex-M, RISC-V, x86, Xtensa, ARC, etc.). It uses **Kconfig** for build-time configuration, **Devicetree** for hardware description, and **CMake/west** as the build/meta-tool. This analysis effort treats the BLE subsystem as the primary subject; all other subsystems (kernel, drivers, networking, etc.) are out of scope unless directly invoked by BLE code.

## Primary analysis target

`subsys/bluetooth/` is the root of the BLE stack. The stack is split across two clean architectural halves connected by HCI:

```
Application
   │
   ▼
┌───────────────────────────────┐
│ subsys/bluetooth/host/        │   Host: GAP, GATT, ATT, SMP, L2CAP, Mesh, Audio, Classic
└───────────────────────────────┘
                │
                ▼  HCI (Host Controller Interface) — the standardized boundary
                │
┌───────────────────────────────┐
│ subsys/bluetooth/controller/  │   Controller: Link Layer (LL), HCI driver
└───────────────────────────────┘
                │
                ▼
       Radio HW / vendor IP
```

Both halves can be built independently. The HCI boundary is the single most important architectural seam in this codebase — almost every cross-layer question reduces to "which side of HCI is this on?"

## Build modes (you MUST identify which one applies before reasoning about call flow)

- **Combined**: Host + Controller in one image. Common on nRF5x / nRF Connect SDK targets.
- **Host-only**: `CONFIG_BT_HCI=y` plus an external controller chip; uses an HCI transport driver (UART/SPI/USB) under `drivers/bluetooth/hci/`.
- **Controller-only**: Zephyr exposes itself as a standard HCI controller over UART/SPI/USB; the host runs elsewhere (e.g. Linux BlueZ). The bridge application lives under `samples/bluetooth/hci_*`.

The same source file can behave differently depending on mode — always check the relevant Kconfigs before drawing conclusions.

## Directory map (BLE-relevant only)

```
subsys/bluetooth/
├── host/                    # Bluetooth Host stack
│   ├── hci_core.{c,h}       # HCI command/event dispatch — top of host stack
│   ├── conn.c, conn_internal.h  # Connection lifecycle (LE + BR/EDR)
│   ├── l2cap.c, l2cap_internal.h
│   ├── att.c, gatt.c        # ATT protocol + GATT layer
│   ├── smp.c, keys.c        # Security Manager + key storage
│   ├── adv.c, scan.c, id.c  # Advertising, scanning, identity (GAP)
│   ├── iso.c, audio/        # LE Audio / Isochronous
│   ├── mesh/                # Bluetooth Mesh profile
│   ├── classic/             # BR/EDR (limited support)
│   └── settings.c           # Persistent storage hook
│
├── controller/              # Bluetooth Controller (Link Layer)
│   ├── hci/                 # HCI handler on controller side
│   │   ├── hci.c            # HCI command/event encoding
│   │   └── hci_driver.c     # HCI transport binding to host
│   ├── ll_sw/               # Software Link Layer (the in-tree LL)
│   │   ├── ull_*.c          # Upper Link Layer (thread context, mayfly-scheduled)
│   │   ├── lll/             # Lower Link Layer (ISR context, radio-tight)
│   │   ├── nordic/          # Vendor-specific LLL: Nordic nRF
│   │   ├── openisa/         # Vendor-specific LLL: NXP RV32M1
│   │   └── isoal.c          # ISO Adaptation Layer
│   ├── ll/                  # Generic LL API surface
│   └── util/                # mem, mayfly, dbuf — controller-internal infra
│
├── common/                  # Logging, RPA, helpers shared by host + controller
├── crypto/                  # AES-CMAC, ECDH (used by SMP + LL)
└── services/                # GATT service helpers

include/zephyr/bluetooth/    # Public API headers (bt_*, conn, gatt, l2cap, hci_types, ...)
drivers/bluetooth/hci/       # HCI transport drivers (uart, spi, ipc, userchan, ...)
doc/connectivity/bluetooth/  # Official architecture docs — start here for any concept
samples/bluetooth/           # Reference apps; useful as call-graph entry points
tests/bluetooth/             # Unit tests + BabbleSim (bsim) integration tests
```

## Critical concepts to keep straight

- **LLL vs ULL (controller split-LL architecture)**: ULL runs in thread / mayfly context and owns scheduling; LLL runs in radio-ISR context and owns the air interface. Crossing this boundary is via mayfly + memory pools, not direct calls. Vendor directories (`nordic/`, `openisa/`) only contain LLL — the ULL is generic.
- **HCI is bidirectional and asymmetric**: commands + ACL/ISO data flow host→controller; events + ACL/ISO data flow controller→host. `hci_core.c` (host) and `hci.c` + `hci_driver.c` (controller) are mirror images.
- **GAP is not a single file**: GAP roles (Peripheral / Central / Broadcaster / Observer) are spread across `adv.c`, `scan.c`, `conn.c`, `id.c`, gated by `CONFIG_BT_PERIPHERAL` / `CONFIG_BT_CENTRAL` / `CONFIG_BT_BROADCASTER` / `CONFIG_BT_OBSERVER`.
- **`*_internal.h` vs public headers**: `subsys/bluetooth/host/*_internal.h` is host-internal; never cited as API. Public surface lives only in `include/zephyr/bluetooth/`.
- **Kconfig is structural, not optional**: a function may have three implementations selected by Kconfig. Always grep for `#if defined(CONFIG_...)` guards before claiming "the code does X."

## Conventions used by this codebase

- C99, kernel-style naming. Public BLE symbols are `bt_*`; internal host symbols often `bt_<module>_*`; controller symbols are `ll_*`, `ull_*`, `lll_*`.
- Memory: dedicated pools (`net_buf`, `mem_*`) — no malloc on the hot path. ISO/ACL buffers come from typed pools defined in `hci_core.c` / controller side.
- Threading: host runs in a dedicated `BT RX` thread + workqueues; controller upper layer runs on mayfly; LLL runs in radio ISR. Anything that crosses these contexts uses lock-free FIFOs or mayfly handoffs.
- Logging: `LOG_MODULE_REGISTER(bt_<name>, CONFIG_BT_<NAME>_LOG_LEVEL)` per file.
- Tests: `tests/bluetooth/bsim/` runs against BabbleSim (PHY simulator) — single most useful resource for validating any behavioral claim about the controller.

## Authoritative references (prefer over inference)

- `doc/connectivity/bluetooth/bluetooth-arch.rst` — overall stack architecture
- `doc/connectivity/bluetooth/bluetooth-le-host.rst` — host internals + glossary
- `doc/connectivity/bluetooth/bluetooth-ctlr-arch.rst` — controller (LLL/ULL) architecture
- `subsys/bluetooth/controller/Kconfig*` — every controller feature flag, often with rationale
- Bluetooth Core Specification v6.x (external) — ground truth for protocol semantics; cite section numbers (e.g. `[Core 6.0, Vol 6, Part B, §4.5]`) when explaining LL behavior

## Analysis hygiene (rules for this codebase)

1. **Identify the build mode** before tracing any call path. The same symbol may resolve to a stub, a real implementation, or a HCI passthrough depending on Kconfig.
2. **Locate the HCI boundary** for any cross-layer question. If a flow crosses HCI, document both halves separately; do not collapse them.
3. **Distinguish LLL from ULL** for any controller question. ISR-context code has different rules (no blocking, no logging, no allocations) than ULL code.
4. **Cite Kconfig guards** explicitly. "This is called when X" is incomplete without "...if `CONFIG_BT_FOO=y`".
5. **Prefer reading `bsim` tests** over reading samples when validating behavior — samples show API usage, bsim tests exercise protocol corner cases.
6. **Vendor LLL is not generic LLL**. When reading `ll_sw/nordic/` or `ll_sw/openisa/`, label findings as vendor-specific; do not generalize to "the controller."
7. **Spec citations beat code intuition**. If code and spec seem to disagree, the spec wins as documentation of intent; flag the discrepancy.
8. **Out of scope**: BR/EDR (`host/classic/`), Mesh (`host/mesh/`), and Audio (`host/audio/`) are large enough to be separate analyses. Do not pull them in unless the current task explicitly asks.

## Per-module CLAUDE.md files (planned)

To be added as analysis proceeds — one per major boundary:
- `subsys/bluetooth/host/CLAUDE.md` — host-internal conventions, thread model, buffer pools
- `subsys/bluetooth/controller/CLAUDE.md` — split-LL architecture, mayfly, scheduling
- `subsys/bluetooth/controller/ll_sw/lll/CLAUDE.md` — ISR-context rules
- `tests/bluetooth/bsim/CLAUDE.md` — how to read/run bsim tests as protocol oracles

## What this file is NOT

- Not a tutorial. Assumes Bluetooth Core Spec familiarity (LE link layer, GAP, GATT, ATT, SMP, L2CAP).
- Not a task list. Plans live in `plans/` or in chat; this file describes the terrain.
- Not exhaustive. It is the orientation a senior BLE engineer would give a new hire in the first hour.
