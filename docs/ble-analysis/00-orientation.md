# Zephyr BLE Analysis — Orientation

Revision: c2dc4ea037a6c1c0dce37d44949b066face27bea

---

## Pinned revision & toolchain

**Date pinned:** 2026-05-30

### Repository revision

| Field | Value |
|-------|-------|
| Full SHA | `c2dc4ea037a6c1c0dce37d44949b066face27bea` |
| `git describe --tags` | `v4.4.0-3-gc2dc4ea037a` |
| Interpretation | Tag `v4.4.0` plus 3 additional commits; abbreviated SHA `c2dc4ea037a` |

All phase analyses in this document set are anchored to this exact SHA. If the working tree moves forward, re-run Task 0.1 before citing any new findings.

### west workspace

Command run: `west list -f '{name} {revision}'`

Output:
```
FATAL ERROR: no west workspace found from
"/Users/zhaohonglin/Documents/ClaudeCodeProjects/work/zephyr";
"west list" requires one.
Things to try:
  - Change directory to somewhere inside a west workspace and retry.
  - Set ZEPHYR_BASE to a zephyr repository path in a west workspace.
  - Run "west init" to set up a workspace here.
  - Run "west init -h" for additional information.
```

The repo root is a bare Zephyr checkout, **not** a west workspace (no `.west/` directory, no sibling modules). `west list` is therefore unavailable. West is installed (see version below) but was not used to check out this tree.

### Toolchain versions

| Tool | Command | Output |
|------|---------|--------|
| west | `west --version` | `West version: v1.5.0` |
| cmake | `cmake --version` | `cmake version 4.2.2` |
| zephyr-sdk | `echo $ZEPHYR_SDK_INSTALL_DIR`; search under `~/zephyr-sdk*`, `/opt/zephyr-sdk*`, `~/opt/zephyr-sdk*`; `find` for `sdk_version` | Not found — `$ZEPHYR_SDK_INSTALL_DIR` is unset; no SDK directory located on this host |

The absence of the Zephyr SDK means no on-host compilation is possible in this environment. All analysis in this document set is **static** (source reading, Kconfig tracing, documentation review) rather than build-and-run.

---

## Build modes

Zephyr's BLE stack is split into a **Host** (above HCI) and a **Controller** (the Link Layer, below HCI), with the standardized HCI protocol as the seam between them (`doc/connectivity/bluetooth/bluetooth-arch.rst:25-37`, `doc/connectivity/bluetooth/bluetooth-arch.rst:43-51`). Because the two halves talk over a defined interface, they can be built into one image or into two separate images on different chips (`doc/connectivity/bluetooth/bluetooth-arch.rst:58-82`). The arch doc enumerates three Bluetooth build types — Controller-only, Host-only, and Combined (`doc/connectivity/bluetooth/bluetooth-arch.rst:84-142`). A key subtlety: per the doc, **Host-only and Combined share the same Kconfig set** (`CONFIG_BT=y`, `CONFIG_BT_HCI=y`); they are distinguished by *devicetree* — which `zephyr,bt-hci` node is chosen — not by Kconfig (`doc/connectivity/bluetooth/bluetooth-arch.rst:115-142`).

| Mode | Defining Kconfig (minimum set) | Halves present (Host / Controller) | Exemplar sample (path) | Key prj.conf deltas (file:line) |
|------|--------------------------------|-------------------------------------|------------------------|----------------------------------|
| **Combined** | `CONFIG_BT=y` (→ implies `CONFIG_BT_HCI=y`); in-tree controller pulled in via `CONFIG_BT_LL_SW_SPLIT` (which `select`s `HAS_BT_CTLR`), gated on the LL devicetree node | Host **and** Controller (same image) | `samples/bluetooth/peripheral/` | `CONFIG_BT=y` (`samples/bluetooth/peripheral/prj.conf:4`); host features e.g. `CONFIG_BT_PERIPHERAL=y` (`:7`), `CONFIG_BT_SMP=y` (`:6`). No `CONFIG_BT_HCI_RAW` and no transport-driver config → controller is local. |
| **Host-only** | `CONFIG_BT=y` (→ `CONFIG_BT_HCI=y`), **same as Combined**; differs by DT: an external-controller HCI transport node is chosen and the local LL node is disabled (so `HAS_BT_CTLR` is *not* selected) | Host only (external controller chip) | `samples/bluetooth/peripheral/` built for `native_sim` (uses `CONFIG_BT_USERCHAN`) | Same app deltas as Combined (`samples/bluetooth/peripheral/prj.conf:4`); the host-only-ness comes from `CONFIG_BT_USERCHAN=y`, which is `BOARD_NATIVE_SIM`-gated and DT-driven (`drivers/bluetooth/hci/Kconfig:154-158`), not from prj.conf. |
| **Controller-only** | `CONFIG_BT=y`, `CONFIG_BT_HCI=y`, `CONFIG_BT_HCI_RAW=y` (+ in-tree controller via the LL DT node) | Controller only (host runs elsewhere, e.g. Linux BlueZ) | `samples/bluetooth/hci_uart/` | `CONFIG_BT=y` (`samples/bluetooth/hci_uart/prj.conf:10`), `CONFIG_BT_HCI_RAW=y` (`:11`), `CONFIG_BT_HCI_RAW_H4=y` (`:12`), `CONFIG_BT_HCI_RAW_H4_ENABLE=y` (`:13`) |

**Combined.** The master gate is `CONFIG_BT` (`subsys/bluetooth/Kconfig:7`). Enabling it activates the `BT_STACK_SELECTION` choice whose `default` is `BT_HCI` (`subsys/bluetooth/Kconfig:18-24`), so `CONFIG_BT=y` implies `CONFIG_BT_HCI=y` without an explicit line — which is why the peripheral sample lists only `CONFIG_BT=y` (`samples/bluetooth/peripheral/prj.conf:4`). The in-tree software controller is pulled in by `CONFIG_BT_LL_SW_SPLIT` (`subsys/bluetooth/controller/Kconfig:143`), which `select`s the virtual `HAS_BT_CTLR` flag (`subsys/bluetooth/controller/Kconfig:140`, selected at `:147`) and defaults `y` only when the LL devicetree node is enabled (`depends on DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED`, `subsys/bluetooth/controller/Kconfig:146`). Thus "combined" is the natural result of a generic BLE app on a board whose DTS enables the local LL controller.

**Host-only.** Kconfig-wise this is *indistinguishable* from Combined (`CONFIG_BT=y` → `CONFIG_BT_HCI=y`); the arch doc is explicit that the difference is devicetree — the local controller's DT node is disabled and a transport driver's `zephyr,bt-hci` node is chosen instead (`doc/connectivity/bluetooth/bluetooth-arch.rst:115-126`). Because the local LL node is then absent, `CONFIG_BT_LL_SW_SPLIT` does not default on and `HAS_BT_CTLR` is not selected, so `controller/` is not built. A concrete single-sample exemplar is the ordinary `samples/bluetooth/peripheral/` app built for `native_sim`, where `CONFIG_BT_USERCHAN=y` (`drivers/bluetooth/hci/Kconfig:154`) provides an external-controller HCI transport to the Linux host's adapter (`drivers/bluetooth/hci/Kconfig:158-165`); the same prj.conf serves both Combined and Host-only, matching the doc's statement that every non-controller-only sample can be built either way (`doc/connectivity/bluetooth/bluetooth-arch.rst:128-129`).

**Controller-only.** This is the one mode with a distinguishing Kconfig symbol: `CONFIG_BT_HCI_RAW` (`subsys/bluetooth/Kconfig:45`), which exposes the controller to a bridge application over a raw HCI transport (`doc/connectivity/bluetooth/bluetooth-arch.rst:95-113`). The `hci_uart` sample enables it together with the H:4 transport variants `CONFIG_BT_HCI_RAW_H4` (`subsys/bluetooth/Kconfig:51`) and `CONFIG_BT_HCI_RAW_H4_ENABLE` (`subsys/bluetooth/Kconfig:57`, which depends on `BT_HCI_RAW_H4`), seen at `samples/bluetooth/hci_uart/prj.conf:11-13`. The Host is not built; the in-tree controller still needs its DT node enabled to be present (`doc/connectivity/bluetooth/bluetooth-arch.rst:112-113`), and the external host (Zephyr or BlueZ) speaks HCI over the wire.

---

## Open questions

1. **No west workspace**: `west list` failed because the repo was not checked out via `west init`. Later tasks that need to know which Zephyr module versions (hal_nordic, mbedtls, trusted-firmware-m, etc.) are paired with this SHA will need either a `.west/` workspace or a manually recorded `west.yml` manifest snapshot. The manifest lives at `west.yml` in the repo root — it should be read in a future task if module versions become relevant to BLE analysis.

2. **No Zephyr SDK**: Build-time checks (e.g., verifying that a Kconfig combination actually compiles) cannot be performed on this host. Any behavioral claim that requires a build artifact must be flagged as "not build-verified."

3. **No prj.conf-only Host-only exemplar**: Per `doc/connectivity/bluetooth/bluetooth-arch.rst:115-142`, Host-only and Combined share an identical Kconfig set (`CONFIG_BT=y` → `CONFIG_BT_HCI=y`) and are separated purely by devicetree (which `zephyr,bt-hci` node is chosen, and whether the local LL node is disabled). No `samples/bluetooth/*` directory has a `prj.conf` that *by itself* forces Host-only; the chosen exemplar (`samples/bluetooth/peripheral/` on `native_sim`, relying on `CONFIG_BT_USERCHAN`) depends on board-level DT and a `BOARD_NATIVE_SIM` gate (`drivers/bluetooth/hci/Kconfig:154-158`). To assert Host-only definitively, a board/DTS overlay (or the generated `.config` + devicetree) at build time must be inspected — not build-verified in this environment (see open question 2).

4. **Combined vs Host-only requires DT inspection, not just Kconfig**: Because `HAS_BT_CTLR` is selected transitively through `CONFIG_BT_LL_SW_SPLIT`, which is `default y` only under `DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED` (`subsys/bluetooth/controller/Kconfig:143-147`), determining whether a given build is Combined or Host-only cannot be done from `prj.conf` alone; it needs the board's devicetree (whether the local LL node is `okay`). Any per-board mode classification in later tasks must read the resolved devicetree, not just Kconfig.
