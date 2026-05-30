# CLAUDE.md — `subsys/bluetooth/`

Scope: anything under this directory is part of Zephyr's BLE subsystem. This file is loaded whenever a session reads files under `subsys/bluetooth/`. The root `CLAUDE.md` is loaded first; this file adds subsystem-specific facts. Do not duplicate root content.

## What lives here

```
subsys/bluetooth/
├── host/         ─ Bluetooth Host (above HCI). See host/CLAUDE.md
├── controller/   ─ Bluetooth Controller (below HCI). See controller/CLAUDE.md
├── common/       ─ Helpers shared by host AND controller (logging, addr, RPA)
├── crypto/       ─ Shared crypto: AES-CMAC, CCM, ECDH P-256
├── services/     ─ GATT service implementations (HRS, BAS, CTS, ...) — HOST-side only
├── mesh/         ─ Bluetooth Mesh — OUT OF SCOPE for Phase 1
├── audio/        ─ LE Audio top-layer profiles — OUT OF SCOPE for Phase 1
├── Kconfig       ─ Top-level BT Kconfig tree; sources Kconfig.<feature> children
└── CMakeLists.txt
```

## Cross-half facts

- **`common/`** is the only place where host and controller call into the same code. Anything in `common/` must be safe to call from either side; do not assume host-only state (e.g. `bt_dev`).
- **`crypto/`** is shared but its consumers are split: host uses it for SMP key derivation, controller uses it for LL encryption (CCM) and PHY-update procedures. The same function may be called from very different contexts.
- **`services/`** are host-side only despite the neutral directory name. Each service has its own Kconfig (e.g. `CONFIG_BT_BAS`) and is essentially a thin GATT registration layer.

## Kconfig anatomy

- `CONFIG_BT` is the master gate. Off → no BLE at all.
- `CONFIG_BT_HCI` was historically the "use HCI" switch; on modern Zephyr
  it's almost always implied by `CONFIG_BT`. Check `Kconfig` at the pinned
  SHA — the gating may have evolved.
- **There is NO user-settable `CONFIG_BT_CTLR` symbol.** The controller is
  brought in via a devicetree → Kconfig chain (see below). `BT_CTLR_*`
  symbols you DO see in prj.conf are *controller feature toggles*
  (e.g. `BT_CTLR_PHY_2M`, `BT_CTLR_ADV_EXT`); they all `depend on
  HAS_BT_CTLR` and are independent of bringing the controller in.
- Host features are enabled à la carte: `CONFIG_BT_CONN`, `CONFIG_BT_SMP`,
  `CONFIG_BT_GATT_*`, etc.
- The **build mode** the analysis assumes (combined) is determined by
  devicetree, not Kconfig. See "Build mode detection" below.

### Controller enablement chain (verified at pinned SHA)

    Application/board DTS:
      chosen { zephyr,bt-hci = <&some_node>; };
      &some_node {
          compatible = "zephyr,bt-hci-ll-sw-split";
          status = "okay";
      };
                              │
                              ▼
    Kconfig (auto-generated from DT):
      DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED = y
                              │
                              ▼
    subsys/bluetooth/controller/Kconfig:143
      config BT_LL_SW_SPLIT
          default y
          depends on DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED   ◀ THE gate
          select HAS_BT_CTLR
                              │
                              ▼
    subsys/bluetooth/controller/Kconfig:140
      config HAS_BT_CTLR
          bool                                                  ◀ virtual,
                                                                  no prompt,
                                                                  only ever
                                                                  select'd
                              │
                              ▼
          controller/ source tree compiled in

Vendor LLs (nRF Audio LL, Espressif controller, etc.) follow the same
pattern: a vendor-specific Kconfig `select HAS_BT_CTLR` gated on a
vendor-specific DT compatible.

## Logging convention

Every `.c` file registers its own log module:

```c
#include <zephyr/logging/log.h>
LOG_MODULE_REGISTER(bt_<short_name>, CONFIG_BT_<NAME>_LOG_LEVEL);
```

When tracing a function, the `LOG_MODULE_REGISTER` line tells you which Kconfig log-level knob controls visibility. Useful for cross-referencing what's actually instrumented.

## `_internal.h` files — universal pattern

Files named `*_internal.h` exist in both `host/` and `controller/`. **They are NEVER public API.** Cross-file usage within the same directory only. If you find a public header (`include/zephyr/bluetooth/...`) that pulls in `_internal.h`, that's a bug — flag it as an Open question.

## Build mode detection (analysis rule)

Combined vs host-only vs controller-only is NOT determined by Kconfig in
prj.conf alone. The discriminator is the application's devicetree
`zephyr,bt-hci` chosen node:

| Chosen node's `compatible` | Build mode | Controller? | Host? |
|---|---|---|---|
| `zephyr,bt-hci-ll-sw-split` (or vendor local LL) | combined | yes (local) | yes |
| `zephyr,bt-hci-uart` / `-spi` / `-ipc` / `-userchan` / etc. | host-only | no (external chip / other core) | yes |
| n/a — app is the controller wrapper, host runs elsewhere | controller-only | yes | no |

For controller-only builds, the app is usually one of
`samples/bluetooth/hci_*` and uses `CONFIG_BT_HCI_RAW=y`; the chosen
still points at a local LL.

**Analysis consequences**:

1. When an artifact references a sample, cite both the sample's
   `prj.conf` AND its effective DTS (board file + any overlay) to
   unambiguously identify the build mode.
2. For Phase 1 (canonical mode: combined), pick samples whose effective
   DTS resolves `zephyr,bt-hci` chosen to a local LL compatible.
3. In combined mode, `drivers/bluetooth/hci/` source files are NOT in
   the call path — the controller's own `controller/hci/hci_driver.c`
   registers as the `bt_hci_driver` instead. Phase 1 Task 1.5 surveys
   `drivers/bluetooth/hci/` for completeness but Task 1.4's diagram does
   not traverse it.

## Phase 1 reminders (also in root CLAUDE.md)

- READ-ONLY in this directory tree. Never edit source.
- Every claim cites `file:line` and (if conditional) the gating `CONFIG_BT_*`.
- Combined build mode is the canonical mode for tracing.
- Out-of-scope subdirectories (`mesh/`, `audio/`) are not read except for naming reference.

## Where to look for entry points

| Question | Start here |
|---|---|
| How does data leave the host? | `host/hci_core.c` → `bt_hci_cmd_send_sync`, `bt_send` |
| How does data enter the controller? | `controller/hci/hci_driver.c` |
| What pool is this buffer from? | `rg 'NET_BUF_POOL' subsys/bluetooth/` |
| Where is feature X gated? | `rg 'CONFIG_BT_<X>' subsys/bluetooth/Kconfig*` |

## Open question template

If you encounter ambiguity while reading code in this subsystem, frame the question with: build mode + Kconfig set + spec section it relates to. Vague open questions get answered with vague guesses; specific ones get answered with code.
