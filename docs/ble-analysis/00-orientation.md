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

Three modes, distinguished by the application's `zephyr,bt-hci` chosen
node, not by Kconfig:

| Mode | DTS chosen → compatible | Min Kconfig | Example sample | Halves |
|---|---|---|---|---|
| **Combined** | `zephyr,bt-hci-ll-sw-split` (or vendor LL, e.g. Espressif's `espressif,esp32-bt-hci`) | `CONFIG_BT=y` | `samples/bluetooth/peripheral` | host + controller |
| **Host-only** | `zephyr,bt-hci-uart` / `-spi` / `-ipc` (e.g. nRF5340 app core) / `-userchan` | `CONFIG_BT=y` | nRF5340 app-core variants; boards with external chip | host only |
| **Controller-only** | local LL compatible, plus `CONFIG_BT_HCI_RAW=y` for the wrapper | `CONFIG_BT=y, CONFIG_BT_HCI_RAW=y` | `samples/bluetooth/hci_uart`, `hci_ipc` | controller only |

### Why no `CONFIG_BT_CTLR=y` row

Verified at pinned SHA: there is **no** Kconfig symbol named `BT_CTLR`
in the tree (only the namespace `BT_CTLR_*` for controller features).
Controller inclusion goes through:

    DTS chosen → DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED
              → BT_LL_SW_SPLIT=y  (subsys/bluetooth/controller/Kconfig:143)
              → HAS_BT_CTLR=y     (subsys/bluetooth/controller/Kconfig:140)
              → controller/ tree compiled

When this analysis says "combined build", it means an application
whose effective DTS resolves the `zephyr,bt-hci` chosen node to a
local LL compatible (`zephyr,bt-hci-ll-sw-split` is the canonical
example).

See `subsys/bluetooth/CLAUDE.md` § "Controller enablement chain" and
§ "Build mode detection (analysis rule)" for the full chain.

## References

This section catalogues the authoritative references for the BLE analysis: every Zephyr in-tree `.rst` under `doc/connectivity/bluetooth/`, the relevant Bluetooth Core Specification volumes/parts, and the canonical source-tree entry points. Scope is per the analysis plan: **in-scope** = host stack, controller (LLL/ULL), HCI, GAP, L2CAP/ATT/GATT/SMP, and LL-level ISO; **out-of-scope** = BR/EDR Classic, Mesh profile, and LE Audio top-layer profiles (note: *LL-level* ISO remains in scope even though the audio profiles above it do not).

### In-tree documentation (`doc/connectivity/bluetooth/`)

Coverage note: `find doc/connectivity/bluetooth -name '*.rst'` returns **103** files at the pinned revision. The task specifies excluding a `_includes/` subdirectory, but **no `_includes/` directory exists at this revision** (`find doc/connectivity/bluetooth -type d -name _includes` returns nothing; `0` `.rst` files therein). All 103 files are therefore listed below; this discrepancy is recorded in Open questions. Image/asset directories (`img/`, `api/audio/img/`, `api/mesh/images/`) contain no `.rst` and are not part of the count.

Descriptions for in-scope files are derived from each file's actual title and intro. Out-of-scope rows (Mesh, Classic, LE Audio profiles, plus general dev/tooling/qualification material) are tagged but still listed for completeness; their one-line descriptions are by topic, not by full file read.

#### Top-level pages

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/index.rst` | Bluetooth (landing) | in | Top toctree for the Bluetooth section; entry point linking arch, host, controller, API. |
| `doc/connectivity/bluetooth/features.rst` | Supported features | in | Feature matrix and supported Host/Controller build combinations; notes v5.3 compliance. |
| `doc/connectivity/bluetooth/bluetooth-arch.rst` | Stack Architecture | in | Overall stack architecture: the 3 LE layers (Host/Controller/Radio) and the HCI seam; build types. |
| `doc/connectivity/bluetooth/bluetooth-le-host.rst` | LE Host | in | Host internals: HCI driver, GAP roles, ATT/GATT/L2CAP/SMP layering, glossary. |
| `doc/connectivity/bluetooth/bluetooth-ctlr-arch.rst` | LE Controller | in | Controller (LLL/ULL split-LL) architecture: HCI, HAL, Ticker, LL_SW, util/mayfly. |
| `doc/connectivity/bluetooth/bluetooth-dev.rst` | Application Development | in | BLE app development: thread safety, hardware setup, build-and-debug options. |
| `doc/connectivity/bluetooth/bluetooth-shell.rst` | Shell | in | Overview of the Bluetooth shell application; toctree into per-feature shell docs. |
| `doc/connectivity/bluetooth/bluetooth-tools.rst` | Tools | in | Development aids: mobile apps, BlueZ, and other tooling for BLE development. |
| `doc/connectivity/bluetooth/bluetooth-qual.rst` | Qualification | out | Bluetooth SIG qualification / PTS / AutoPTS process and ICS files (process, not stack). |

#### Host shell pages (`shell/host/`)

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/shell/host/gap.rst` | GAP Shell | in | Main BLE shell: connection management, scanning, advertising, identities. |
| `doc/connectivity/bluetooth/shell/host/gatt.rst` | GATT Shell | in | GATT shell commands: service discovery, register/notify, client/server interaction. |
| `doc/connectivity/bluetooth/shell/host/iso.rst` | Isochronous Channels Shell | in | ISO shell commands (LL-level ISO is in scope; host-side CIS/BIS exercise surface). |
| `doc/connectivity/bluetooth/shell/host/l2cap.rst` | L2CAP Shell | in | L2CAP shell: register LE PSM, connect, send packets over a dynamic channel. |

#### API reference pages (`api/`)

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/api/index.rst` | API (landing) | in | Toctree aggregating all Bluetooth API reference pages (host, classic, mesh, audio). |
| `doc/connectivity/bluetooth/api/att.rst` | Attribute Protocol (ATT) | in | ATT API reference (doxygengroup `bt_att`). |
| `doc/connectivity/bluetooth/api/gap.rst` | Generic Access Profile (GAP) | in | GAP API reference (`bt_gap`, `bt_addr`, `bt_gap_defines`). |
| `doc/connectivity/bluetooth/api/gatt.rst` | Generic Attribute Profile (GATT) | in | GATT service database, client/server APIs; `CONFIG_BT_GATT_CLIENT` gating. |
| `doc/connectivity/bluetooth/api/l2cap.rst` | L2CAP | in | L2CAP connection-oriented channels, segmentation/reassembly, credit flow control. |
| `doc/connectivity/bluetooth/api/connection_mgmt.rst` | Connection Management | in | `bt_conn` abstraction: reference counting, connection info, lifecycle. |
| `doc/connectivity/bluetooth/api/controller.rst` | Bluetooth Controller | in | Controller API reference (doxygengroup `bt_ctrl`). |
| `doc/connectivity/bluetooth/api/crypto.rst` | Cryptography | in | Crypto API reference (doxygengroup `bt_crypto`); used by SMP and LL. |
| `doc/connectivity/bluetooth/api/data_buffer.rst` | Data Buffers | in | Buffer/pool API reference (doxygengroup `bt_buf`). |
| `doc/connectivity/bluetooth/api/hci_drivers.rst` | HCI Drivers | in | HCI transport driver API reference (doxygengroup `bt_hci_api`). |
| `doc/connectivity/bluetooth/api/hci_raw.rst` | HCI RAW channel | in | Raw HCI passthrough API exposing the controller to a remote host (controller-only mode). |
| `doc/connectivity/bluetooth/api/services.rst` | Bluetooth standard services | in | Standard GATT services API (BAS, CTS, etc.). |
| `doc/connectivity/bluetooth/api/uuid.rst` | UUIDs | in | UUID API reference (doxygengroup `bt_uuid`). |
| `doc/connectivity/bluetooth/api/mesh.rst` | Bluetooth Mesh Profile | out | Mesh profile landing page; multi-hop mesh networking (Mesh is a separate analysis). |

#### LE Audio documentation (`api/audio/`, `shell/audio/`) — out of scope

The LE Audio top-layer profiles (BAP, CAP, CSIP/coordinated sets, MCP/media, microphone/VCP/volume, TBS, TMAP, GMAP, PBP, CCP, broadcast assistant/scan delegator) are out of scope per the plan. The LL-level ISO transport beneath them is in scope and is covered via `shell/host/iso.rst` and the Core Spec ISO/ISOAL references below.

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/api/audio/bluetooth-le-audio-arch.rst` | LE Audio Stack | out | LE Audio overall architecture (profile-layer; ISO transport itself is tracked in scope). |
| `doc/connectivity/bluetooth/api/audio/audio.rst` | Bluetooth Audio | out | Core LE Audio API reference (`bt_audio`). |
| `doc/connectivity/bluetooth/api/audio/bap.rst` | BAP | out | Basic Audio Profile API. |
| `doc/connectivity/bluetooth/api/audio/cap.rst` | CAP | out | Common Audio Profile API. |
| `doc/connectivity/bluetooth/api/audio/coordinated_sets.rst` | Coordinated Sets (CSIP) | out | Coordinated Set Identification Profile API. |
| `doc/connectivity/bluetooth/api/audio/media.rst` | Media (MCP) | out | Media Control Profile API. |
| `doc/connectivity/bluetooth/api/audio/microphone.rst` | Microphone (MICP) | out | Microphone Control Profile API. |
| `doc/connectivity/bluetooth/api/audio/volume.rst` | Volume (VCP) | out | Volume Control Profile API. |
| `doc/connectivity/bluetooth/shell/audio/bap.rst` | BAP Shell | out | BAP shell commands. |
| `doc/connectivity/bluetooth/shell/audio/bap_broadcast_assistant.rst` | BAP Broadcast Assistant Shell | out | Broadcast Assistant shell commands. |
| `doc/connectivity/bluetooth/shell/audio/bap_scan_delegator.rst` | BAP Scan Delegator Shell | out | Scan Delegator shell commands. |
| `doc/connectivity/bluetooth/shell/audio/cap.rst` | CAP Shell | out | CAP shell commands. |
| `doc/connectivity/bluetooth/shell/audio/ccp.rst` | CCP Shell | out | Call Control Profile shell commands. |
| `doc/connectivity/bluetooth/shell/audio/csip.rst` | CSIP Shell | out | Coordinated Set Identification shell commands. |
| `doc/connectivity/bluetooth/shell/audio/gmap.rst` | GMAP Shell | out | Gaming Audio Profile shell commands. |
| `doc/connectivity/bluetooth/shell/audio/mcp.rst` | MCP Shell | out | Media Control Profile shell commands. |
| `doc/connectivity/bluetooth/shell/audio/pbp.rst` | PBP Shell | out | Public Broadcast Profile shell commands. |
| `doc/connectivity/bluetooth/shell/audio/tbs.rst` | TBS Shell | out | Telephone Bearer Service shell commands. |
| `doc/connectivity/bluetooth/shell/audio/tmap.rst` | TMAP Shell | out | Telephony and Media Audio Profile shell commands. |

#### BR/EDR Classic documentation (`api/classic/`, `shell/classic/`) — out of scope

BR/EDR Classic is out of scope per the plan (`host/classic/`).

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/api/classic/a2dp.rst` | A2DP | out | Advanced Audio Distribution Profile (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/avrcp.rst` | AVRCP | out | Audio/Video Remote Control Profile (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/bip.rst` | BIP | out | Basic Imaging Profile (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/goep.rst` | GOEP | out | Generic Object Exchange Profile (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/hfp.rst` | HFP | out | Hands-Free Profile (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/l2cap_br.rst` | L2CAP (BR/EDR) | out | BR/EDR L2CAP API (Classic transport, distinct from LE L2CAP). |
| `doc/connectivity/bluetooth/api/classic/rfcomm.rst` | RFCOMM | out | RFCOMM serial-port-emulation (Classic) API. |
| `doc/connectivity/bluetooth/api/classic/sdp.rst` | SDP | out | Service Discovery Protocol (Classic) API. |
| `doc/connectivity/bluetooth/shell/classic/a2dp.rst` | A2DP Shell | out | A2DP (Classic) shell commands. |
| `doc/connectivity/bluetooth/shell/classic/avrcp.rst` | AVRCP Shell | out | AVRCP (Classic) shell commands. |
| `doc/connectivity/bluetooth/shell/classic/goep.rst` | GOEP Shell | out | GOEP (Classic) shell commands. |
| `doc/connectivity/bluetooth/shell/classic/hfp.rst` | HFP Shell | out | HFP (Classic) shell commands. |
| `doc/connectivity/bluetooth/shell/classic/l2cap.rst` | L2CAP (Classic) Shell | out | BR/EDR L2CAP shell commands. |
| `doc/connectivity/bluetooth/shell/classic/rfcomm.rst` | RFCOMM Shell | out | RFCOMM (Classic) shell commands. |

#### Mesh documentation (`api/mesh/`) — out of scope

The Mesh profile is out of scope per the plan (`host/mesh/`). All **41** files under `doc/connectivity/bluetooth/api/mesh/` are out of scope; they are listed here for completeness but not individually described (each is a Mesh model/service/feature API page).

| Path | Scope |
|------|-------|
| `doc/connectivity/bluetooth/api/mesh/access.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/blob.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/blob_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/blob_flash.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/blob_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/brg_cfg.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/brg_cfg_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/brg_cfg_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/cdb_usage.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/cfg.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/cfg_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/cfg_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/core.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/dfd_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/dfu.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/dfu_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/dfu_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/health_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/health_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/heartbeat.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/lcd_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/lcd_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/models.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/msg.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/od_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/od_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/op_agg_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/op_agg_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/priv_beacon_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/priv_beacon_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/provisioning.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/proxy.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/rpr_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/rpr_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/sar_cfg.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/sar_cfg_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/sar_cfg_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/shell.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/srpl_cli.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/srpl_srv.rst` | out |
| `doc/connectivity/bluetooth/api/mesh/statistic.rst` | out |

#### Qualification automation (`autopts/`) — out of scope

| Path | Title/Topic | Scope | One-line description |
|------|-------------|-------|----------------------|
| `doc/connectivity/bluetooth/autopts/autopts-linux.rst` | AutoPTS on Linux | out | Setup tutorial for the AutoPTS qualification client on Linux (test tooling). |
| `doc/connectivity/bluetooth/autopts/autopts-win10.rst` | AutoPTS on Windows 10 | out | Setup tutorial for AutoPTS client/server on Windows 10 with nRF52 (test tooling). |

### Bluetooth Core Specification

Spec version assumption: **Core 6.x** (per the project `CLAUDE.md`; cite the precise minor version when a behavioral claim depends on it). Citation form: `[Core 6.0, Vol X, Part Y, §...]`. The topic → volume/part mapping the analysis will use:

| Topic | Core Spec location | Notes |
|-------|--------------------|-------|
| Link Layer (LE LL) | `[Core 6.0, Vol 6, Part B]` | LL states/roles, control procedures, air-interface PDUs. |
| Low Energy PHY / radio | `[Core 6.0, Vol 6, Part A]` | LE physical layer (verify Part letter against the cited edition). |
| LE Isochronous (ISO) | `[Core 6.0, Vol 6, Part B / Part G]` | CIS/BIS LL behavior in Vol 6 Part B; ISOAL in Vol 6 Part G (verify Part letter). |
| ISO Adaptation Layer (ISOAL) | `[Core 6.0, Vol 6, Part G]` | Framed/unframed SDU↔PDU mapping (verify Part letter). |
| HCI | `[Core 6.0, Vol 4, Part E]` | Host Controller Interface commands, events, ACL/ISO data. |
| L2CAP | `[Core 6.0, Vol 3, Part A]` | Logical Link Control and Adaptation Protocol. |
| GAP | `[Core 6.0, Vol 3, Part C]` | Generic Access Profile, roles, modes, procedures. |
| ATT | `[Core 6.0, Vol 3, Part F]` | Attribute Protocol. |
| GATT | `[Core 6.0, Vol 3, Part G]` | Generic Attribute Profile. |
| SMP / Security Manager | `[Core 6.0, Vol 3, Part H]` | Security Manager Protocol, pairing, key distribution. |

Cross-cutting cryptographic primitives (AES-CMAC, ECDH P-256) referenced by SMP and the LL are defined within the above parts (notably Vol 3 Part H and Vol 6 Part B/E); cite the specific section when used. Exact Part letters tagged "(verify ...)" should be confirmed against the precise Core 6.x edition before being relied upon in a finding.

### Key source-tree anchors

Canonical entry files for the two halves of the stack and their HCI seam (paths only; see per-phase analyses for line-level citations):

- Host top-of-stack / HCI command-event dispatch: `subsys/bluetooth/host/hci_core.c`
- Controller-side HCI command/event encoding: `subsys/bluetooth/controller/hci/hci.c`
- Controller software Link Layer (LLL/ULL split-LL implementation): `subsys/bluetooth/controller/ll_sw/`

---

## Open questions (triaged)

1. **No west workspace**: `west list` failed because the repo was not checked out via `west init`. Later tasks that need to know which Zephyr module versions (hal_nordic, mbedtls, trusted-firmware-m, etc.) are paired with this SHA will need either a `.west/` workspace or a manually recorded `west.yml` manifest snapshot. The manifest lives at `west.yml` in the repo root — it should be read in a future task if module versions become relevant to BLE analysis.

   **Status: DEFER.** Phase 1–4 are static code analysis only; west module versions become relevant only for runtime/bsim validation (Phase 5 onward). If/when a behavioral claim needs cross-module verification, snapshot `west.yml` at the pinned SHA at that time.

2. **No Zephyr SDK**: Build-time checks (e.g., verifying that a Kconfig combination actually compiles) cannot be performed on this host. Any behavioral claim that requires a build artifact must be flagged as "not build-verified."

   **Status: DEFER.** Same scope as Q1 — build-verified claims are not required for static analysis phases. Any artifact making a behavioral claim must explicitly flag it as "not build-verified."

3. **No prj.conf-only Host-only exemplar**: Per `doc/connectivity/bluetooth/bluetooth-arch.rst:115-142`, Host-only and Combined share an identical Kconfig set (`CONFIG_BT=y` → `CONFIG_BT_HCI=y`) and are separated purely by devicetree (which `zephyr,bt-hci` node is chosen, and whether the local LL node is disabled). No `samples/bluetooth/*` directory has a `prj.conf` that *by itself* forces Host-only; the chosen exemplar (`samples/bluetooth/peripheral/` on `native_sim`, relying on `CONFIG_BT_USERCHAN`) depends on board-level DT and a `BOARD_NATIVE_SIM` gate (`drivers/bluetooth/hci/Kconfig:154-158`). To assert Host-only definitively, a board/DTS overlay (or the generated `.config` + devicetree) at build time must be inspected — not build-verified in this environment (see open question 2).

   **Status: RESOLVED (by Q4's finding).** The premise of needing a "prj.conf-only Host-only exemplar" assumes Kconfig is the discriminator. Q4 establishes that the discriminator is the DTS `zephyr,bt-hci` chosen node, not prj.conf. Host-only is correctly identified by board DTS + overlay (no prj.conf-only exemplar should exist or be sought). See `subsys/bluetooth/CLAUDE.md` § "Build mode detection (analysis rule)".

4. **Combined vs Host-only requires DT inspection, not just Kconfig**: Because `HAS_BT_CTLR` is selected transitively through `CONFIG_BT_LL_SW_SPLIT`, which is `default y` only under `DT_HAS_ZEPHYR_BT_HCI_LL_SW_SPLIT_ENABLED` (`subsys/bluetooth/controller/Kconfig:143-147`), determining whether a given build is Combined or Host-only cannot be done from `prj.conf` alone; it needs the board's devicetree (whether the local LL node is `okay`). Any per-board mode classification in later tasks must read the resolved devicetree, not just Kconfig.

   **Status: RESOLVED.** Upgraded from open question to load-bearing analysis rule. See `subsys/bluetooth/CLAUDE.md` § "Build mode detection (analysis rule)" and § "Controller enablement chain". All Phase 1+ artifacts must cite DTS (board file + overlay) in addition to prj.conf when identifying a sample's build mode.

5. **No `_includes/` subdirectory at the pinned revision**: Task 0.3 instructed excluding `doc/connectivity/bluetooth/_includes/` from the reference catalogue, but that directory does not exist at SHA `c2dc4ea037a` (verified via `find doc/connectivity/bluetooth -type d -name _includes`, no results; `0` `.rst` files). All 103 `.rst` files were therefore catalogued with none excluded. If a later upstream revision introduces `_includes/` (e.g. for reusable RST snippets), the References table must be re-run and that subdirectory re-evaluated for exclusion.

   **Status: RESOLVED.** `_includes/` does not exist at pinned SHA (verified). All 103 `.rst` files catalogued. If a future upstream-sync introduces `_includes/`, References table must be re-evaluated — but that's a re-pin event, not a Phase 0 question.

6. **Core Spec Part letters not independently verified**: The topic→Vol/Part mapping in `## References` follows the conventional Core 6.x layout, but several entries (LE PHY Vol 6 Part A; ISO/ISOAL Vol 6 Part G) are tagged "(verify Part letter)" because the exact edition was not cross-checked against a spec copy in this environment. Confirm against the precise Core 6.x edition before relying on a Part letter in any finding.

   **Status: KNOWN UNKNOWN.** Terminology baseline is Core 5.4 (matches Zephyr's own docs); procedure-level citations in Phase 1+ will use Core 6.x section numbers with Part letters spot-verified against a spec copy at the time of citation. Tag any uncertain Part letter inline with `(Part letter to verify)`.