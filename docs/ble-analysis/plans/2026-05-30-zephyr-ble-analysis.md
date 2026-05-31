# Zephyr BLE Subsystem — Systematic Analysis Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended for parallel phases) or `superpowers:executing-plans` to execute this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking. This is an **analysis plan**, not an implementation plan: deliverables are documents and diagrams, not code; "verification" means a peer-reviewable artifact exists at the specified path and answers the stated question.

> **Announcement:** I'm using the `writing-plans` skill (adapted for code analysis) to create this plan.

---

## Scope

Produce a systematic, reviewable understanding of Zephyr's BLE subsystem (`subsys/bluetooth/`) sufficient for: (a) onboarding a senior embedded engineer in <1 week, (b) reasoning about behavior under spec edge cases without reading code from scratch, (c) identifying integration points for custom controllers or host modifications.

## Out of scope (separate plans if needed)

- BR/EDR Classic Bluetooth (`subsys/bluetooth/host/classic/`)
- Bluetooth Mesh profile (`subsys/bluetooth/host/mesh/`)
- LE Audio top-layer profiles (`subsys/bluetooth/host/audio/`) — LL-level ISO is in scope
- Vendor-specific Link Layers other than `nordic/` (e.g. `openisa/`) — covered as reference only

## Assumptions

- Reader is fluent in C and embedded concepts (ISR, DMA, scheduling).
- Reader has working familiarity with Bluetooth Core Spec terminology (LL, ACL, ATT, GATT, L2CAP, SMP). Spec citations use the form `[Core 6.0, Vol 6, Part B, §4.5]`.
- Working zephyr checkout at `./zephyr/` with `west` available. Reference revision pinned in `00-orientation.md` (Task 0.1) so all artifacts cite the same SHA.

## Save location

```
docs/ble-analysis/
├── 00-orientation.md
├── plans/
│   └── 2026-05-30-zephyr-ble-analysis.md   ← this plan
├── phase-1-hci/
├── phase-2-controller/
├── phase-3-host/
├── phase-4-gap/
└── phase-5-iso/
```

User preferences for path location override this default.

---

## Artifact map (what each phase produces)

| Phase | Artifact | Type | Single responsibility |
|---|---|---|---|
| 0 | `00-orientation.md` | doc | Pin revision, build modes, glossary, references |
| 1 | `phase-1-hci/boundary.md` | doc | Wire-level HCI dispatch, both directions |
| 1 | `phase-1-hci/cmd-event-flow.mmd` | mermaid | Sequence diagram: cmd → ACK → event |
| 1 | `phase-1-hci/transport-drivers.md` | doc | UART/SPI/IPC/userchan driver model |
| 2 | `phase-2-controller/lll-ull-split.md` | doc | Context boundary, mayfly, memory pools |
| 2 | `phase-2-controller/scheduler.md` | doc | Ticker, role conflicts, prio resolution |
| 2 | `phase-2-controller/state-conn.mmd` | mermaid | Controller-side connection state machine |
| 2 | `phase-2-controller/vendor-hal.md` | doc | What Nordic LLL provides vs. what is generic |
| 3 | `phase-3-host/conn-lifecycle.md` | doc | `bt_conn` creation→teardown |
| 3 | `phase-3-host/l2cap-att-gatt.md` | doc | Layered packet flow, MTU/MPS, fragmentation |
| 3 | `phase-3-host/smp-keys.md` | doc | Pairing flows, key storage, RPA |
| 3 | `phase-3-host/buffers-threads.md` | doc | net_buf pools, RX thread, workqueues |
| 4 | `phase-4-gap/roles-kconfig.md` | doc | Peripheral/Central/Broadcaster/Observer source map |
| 4 | `phase-4-gap/adv-scan-init.mmd` | mermaid | Cross-layer sequence diagrams |
| 5 | `phase-5-iso/iso-pipeline.md` | doc | ISO HCI → ISOAL → CIS/BIS controller path |
| ∞ | `glossary.md` | doc | Accumulated terms — appended to in every phase |

---

## Execution rules (apply to every task)

1. **Pin the revision.** Every artifact starts with `Revision: <SHA>` matching the SHA in `00-orientation.md`. If the working tree has changed, abort and re-pin.
2. **Cite file:line** for every code claim: `subsys/bluetooth/host/conn.c:1247`.
3. **Cite Kconfig** for every conditional behavior: `under CONFIG_BT_PERIPHERAL=y`.
4. **Cite spec sections** for every protocol claim: `[Core 6.0, Vol 6, Part B, §4.5.6]`.
5. **No paraphrased spec text** longer than 15 words — cite section, summarize in your own words.
6. **Frame unknowns explicitly.** A `## Open questions` section at the end of every artifact is required (may be empty).
7. **Commit after every task** with message `analysis(phase-N): <task-id> <short title>`.
8. **No code edits** anywhere under `subsys/bluetooth/` or `include/zephyr/bluetooth/`. Read-only.

---

## Phase 0 — Orientation (sequential, ~2h total)

**Goal:** Establish a single source of truth that all later phases reference.

### Task 0.1 — Pin revision and toolchain
- [x] Run `git -C zephyr rev-parse HEAD` → record SHA, tag (if any), `west list -f '{name} {revision}'` output
- [x] Record host toolchain: `zephyr-sdk --version`, `west --version`, `cmake --version`
- [x] Deliverable: header block at top of `docs/ble-analysis/00-orientation.md`
- [x] Verification: SHA is present and `git cat-file -e <SHA>` succeeds
- **Dependencies:** none

### Task 0.2 — Build-mode enumeration
- [x] Read `doc/connectivity/bluetooth/bluetooth-arch.rst`
- [x] Identify the three build modes (combined / host-only / controller-only) and the Kconfig minimum set that defines each
- [x] For each mode, find one sample under `samples/bluetooth/` that exemplifies it; list its `prj.conf` deltas vs. defaults
- [x] Deliverable: `## Build modes` section in `00-orientation.md` with a table
- [x] Verification: each row of the table has (a) Kconfig set, (b) one sample path, (c) which Zephyr halves are present
- **Dependencies:** 0.1

### Task 0.3 — Reference index
- [x] Catalogue authoritative references: every `.rst` under `doc/connectivity/bluetooth/`, plus relevant Core Spec volumes
- [x] Deliverable: `## References` section in `00-orientation.md`
- [x] Verification: every `.rst` under `doc/connectivity/bluetooth/` (excluding `_includes/`) is either listed or explicitly noted as out of scope
- **Dependencies:** 0.1

### Task 0.4 — Seed glossary
- [x] Extract glossary terms from `doc/connectivity/bluetooth/bluetooth-le-host.rst` (it already has a glossary section)
- [x] Deliverable: `docs/ble-analysis/glossary.md` with at least: ACL, ATT, ATT MTU, GATT, L2CAP, MPS, MTU, PDU, SDU, HCI, LL, LLL, ULL, mayfly, net_buf, RPA, IRK, LTK
- [x] Verification: each term has a 1-sentence definition + source citation (spec section or file path)
- **Dependencies:** 0.3

### 🔍 Review checkpoint after Phase 0
Human review of `00-orientation.md` before proceeding. If the build-mode table is wrong, every downstream artifact will be wrong.

---

## Phase 1 — HCI Boundary (mostly sequential, ~6h)

**Goal:** Map the single most important architectural seam. After this phase, any "how does X get from app to air?" question has a clear handoff point.

### Task 1.1 — HCI command/event taxonomy
- [x] Read `include/zephyr/bluetooth/hci_types.h`
- [x] Produce a categorized list of command groups (Link Control, LE Controller, Vendor) and event types; cite OpCode Group Field values
- [x] Deliverable: `phase-1-hci/boundary.md` § "HCI surface"
- [x] Verification: at least 5 LE Controller commands and 5 LE events are listed with file:line + spec section
- **Dependencies:** 0.4

### Task 1.2 — Host-side dispatch (commands out, events in)
- [x] Read `subsys/bluetooth/host/hci_core.c`, `subsys/bluetooth/host/hci_core.h`
- [x] Trace: who calls `bt_hci_cmd_send_sync()`? Where does the RX thread dequeue events? Which function dispatches `hci_event` → per-event handler? How are LE meta events split off?
- [x] Deliverable: `phase-1-hci/boundary.md` § "Host side"
- [x] Verification: includes a function-call list of length ≥ 6 going from `bt_*` API → HCI driver, with file:line for each hop
- **Dependencies:** 1.1

### Task 1.3 — Controller-side dispatch (commands in, events out)
- [ ] Read `subsys/bluetooth/controller/hci/hci.c`, `subsys/bluetooth/controller/hci/hci_driver.c`
- [ ] Trace mirror image: how a HCI command is decoded, dispatched to LL handler, and how events are generated and pushed back to the transport
- [ ] Deliverable: `phase-1-hci/boundary.md` § "Controller side"
- [ ] Verification: includes a function-call list mirroring 1.2 in the opposite direction
- **Dependencies:** 1.1

### Task 1.4 — Cross-half sequence diagram
- [ ] Pick `HCI_LE_Set_Advertising_Enable` as the canonical example
- [ ] Produce a mermaid sequence diagram showing: app → host API → host HCI → transport → controller HCI → LL → ACK event back
- [ ] Deliverable: `phase-1-hci/cmd-event-flow.mmd`
- [ ] Verification: every arrow has a file:line label; diagram renders without errors via `mmdc -i cmd-event-flow.mmd -o /tmp/x.svg`
- **Dependencies:** 1.2, 1.3

### Task 1.5 — Transport driver inventory
- [ ] Read `drivers/bluetooth/hci/` directory listing + `Kconfig`
- [ ] For UART, SPI, IPC, userchan, virtual: identify (a) Kconfig symbol, (b) the H4/HCI framing it implements, (c) where it plugs into the host (`bt_hci_driver` struct registration)
- [ ] Deliverable: `phase-1-hci/transport-drivers.md`
- [ ] Verification: table with one row per transport, with Kconfig + file path + framing reference + registration call site
- **Dependencies:** 1.2

### Task 1.6 — Buffer flow at the boundary
- [ ] Identify the `net_buf` pools used for HCI commands, command-complete events, ACL data, ISO data — names, sizes, locations
- [ ] Document the fragmentation rules (HCI ACL fragments vs. L2CAP PDUs)
- [ ] Deliverable: `phase-1-hci/boundary.md` § "Buffers"
- [ ] Verification: each pool has Kconfig sizing knob cited and lives in either `hci_core.c` or controller hci module
- **Dependencies:** 1.2, 1.3

### 🔍 Review checkpoint after Phase 1
Human review of all `phase-1-hci/*` artifacts. The HCI boundary is referenced by every later phase; mistakes here propagate.

---

## Phase 2 — Controller (parallel-safe within phase, ~10h)

**Goal:** Understand the split Link Layer: LLL (ISR-context, radio-tight) ⇄ ULL (thread-context, scheduling) ⇄ HCI. Tasks 2.1–2.4 can be dispatched to parallel subagents; 2.5 depends on all of them.

### Task 2.1 — LLL/ULL boundary
- [ ] Read `subsys/bluetooth/controller/ll_sw/ull.c`, `ull_internal.h`, and at least one `lll_*.c` (e.g. `lll/lll_conn.c`)
- [ ] Document: (a) how ULL submits work to LLL (mayfly), (b) how LLL signals completion back, (c) what may NEVER be called from LLL context (logging, blocking, allocations)
- [ ] Deliverable: `phase-2-controller/lll-ull-split.md`
- [ ] Verification: lists at least 3 mayfly handoff sites with file:line and explains the memory ownership at each
- **Dependencies:** 1.3

### Task 2.2 — Scheduling (ticker + roles)
- [ ] Read `subsys/bluetooth/controller/ll_sw/ticker/ticker.c`, `ticker.h`
- [ ] Read role registration in `ull_adv.c`, `ull_scan.c`, `ull_conn.c`
- [ ] Document: (a) ticker abstraction, (b) how role events are scheduled and pre-empted, (c) priority + collision resolution
- [ ] Deliverable: `phase-2-controller/scheduler.md`
- [ ] Verification: includes a worked example of two overlapping roles (e.g. scanning + connection event) with resolution
- **Dependencies:** 1.3 (independent of 2.1)

### Task 2.3 — Connection state machine (controller side)
- [ ] Read `subsys/bluetooth/controller/ll_sw/ull_conn.c`, `lll/lll_conn.c`, plus the LLCP module under `ll_sw/`
- [ ] Map states: idle → initiating → connecting → connected → terminating, plus LLCP sub-states (encryption setup, PHY update, etc.)
- [ ] Deliverable: `phase-2-controller/state-conn.mmd` (mermaid stateDiagram-v2) + 1-page commentary
- [ ] Verification: each state transition cites the LL procedure from `[Core 6.0, Vol 6, Part B, §5.1]` and the corresponding source function
- **Dependencies:** 1.3 (independent of 2.1, 2.2)

### Task 2.4 — Vendor HAL surface (Nordic as reference)
- [ ] Read `subsys/bluetooth/controller/ll_sw/nordic/hal/` headers
- [ ] Enumerate what the LLL needs from the vendor: radio, timer, RNG, ECB/CCM, swi/PPI
- [ ] Deliverable: `phase-2-controller/vendor-hal.md` — table of "generic LLL needs X → Nordic provides via file:line"
- [ ] Verification: at least the radio, timer, and crypto interfaces are documented
- **Dependencies:** 1.3 (independent of 2.1, 2.2, 2.3)

### Task 2.5 — Controller integration narrative
- [ ] Synthesize 2.1–2.4 into a single end-to-end story: "what happens in the controller from `HCI_LE_Create_Connection` to the first encrypted ATT packet on air"
- [ ] Deliverable: `phase-2-controller/integration-narrative.md`
- [ ] Verification: narrative references at least one artifact from each of 2.1, 2.2, 2.3, 2.4
- **Dependencies:** 2.1, 2.2, 2.3, 2.4

### 🔍 Review checkpoint after Phase 2
Human review of integration narrative. If the narrative does not match expected behavior, the underlying artifacts are wrong somewhere.

---

## Phase 3 — Host (parallel-safe within phase, ~10h)

**Goal:** Understand connection lifecycle, layered packet flow (L2CAP/ATT/GATT), security, and the threading model. Tasks 3.1–3.4 can run in parallel.

### Task 3.1 — `bt_conn` lifecycle
- [ ] Read `subsys/bluetooth/host/conn.c`, `conn_internal.h`
- [ ] Trace: allocation (`bt_conn_new`), refcounting, state transitions, teardown
- [ ] Deliverable: `phase-3-host/conn-lifecycle.md` + a stateDiagram-v2 of `bt_conn_state`
- [ ] Verification: every refcount call (`bt_conn_ref` / `bt_conn_unref`) site is categorized as "owner" vs "borrower"
- **Dependencies:** Phase 1 complete

### Task 3.2 — L2CAP → ATT → GATT layering
- [ ] Read `l2cap.c`, `att.c`, `gatt.c` (host-side)
- [ ] Document: (a) channel demux (fixed CID 0x0004 ATT, 0x0005 signaling, dynamic CIDs for COC), (b) ATT MTU exchange, (c) GATT operation dispatch
- [ ] Deliverable: `phase-3-host/l2cap-att-gatt.md` with one packet-flow diagram per direction
- [ ] Verification: includes fragmentation example showing how a large ATT response is split across L2CAP+HCI ACL fragments
- **Dependencies:** Phase 1 complete (independent of 3.1)

### Task 3.3 — SMP and key storage
- [ ] Read `smp.c`, `keys.c`, `id.c`
- [ ] Document: (a) pairing method selection (LE Legacy vs LE Secure Connections), (b) key derivation, (c) where keys persist (`settings` subsystem), (d) RPA generation/resolution
- [ ] Deliverable: `phase-3-host/smp-keys.md`
- [ ] Verification: pairing sequence diagram included for both LESC and Legacy; key types (LTK, IRK, CSRK) each have a storage location cited
- **Dependencies:** Phase 1 complete (independent of 3.1, 3.2)

### Task 3.4 — Threads, workqueues, buffers
- [ ] Identify all threads spawned by the host (RX thread, TX thread if any) — search for `K_THREAD_DEFINE` and `k_thread_create` under `subsys/bluetooth/host/`
- [ ] Identify all workqueues used and what posts to them
- [ ] Enumerate all `NET_BUF_POOL_*` definitions in host
- [ ] Deliverable: `phase-3-host/buffers-threads.md`
- [ ] Verification: a table of (thread/wq, who feeds it, what context it runs in, what rules apply)
- **Dependencies:** Phase 1 complete (independent of 3.1, 3.2, 3.3)

### 🔍 Review checkpoint after Phase 3
Human review. Per-module CLAUDE.md files should be drafted now for `subsys/bluetooth/host/` based on 3.1–3.4 findings.

---

## Phase 4 — GAP (cross-cutting, sequential, ~4h)

**Goal:** GAP is not a single file. This phase explicitly maps the role-spread across host and controller.

### Task 4.1 — Role source-map
- [ ] For each of {Peripheral, Central, Broadcaster, Observer}: identify (a) Kconfig symbol, (b) host files that implement the role, (c) controller files involved
- [ ] Deliverable: `phase-4-gap/roles-kconfig.md` — one section per role
- [ ] Verification: each section names ≥ 3 files and ≥ 2 spec sections
- **Dependencies:** Phase 2 and Phase 3 complete

### Task 4.2 — End-to-end sequence diagrams
- [ ] Produce three mermaid sequence diagrams: (a) extended advertising start, (b) periodic advertising sync, (c) connection establishment from central side
- [ ] Each diagram spans app → host → HCI → controller → LL
- [ ] Deliverable: `phase-4-gap/adv-scan-init.mmd`
- [ ] Verification: each diagram references file:line for every cross-layer hop and renders cleanly via `mmdc`
- **Dependencies:** 4.1

### 🔍 Review checkpoint after Phase 4
Major review. At this point the BLE subsystem should be navigable end-to-end. Decide whether Phase 5 is needed.

---

## Phase 5 — ISO Pipeline (optional, sequential, ~6h)

**Goal:** ISO is the newest addition and the trickiest to grasp. Skip if not relevant to current work.

### Task 5.1 — ISO HCI surface
- [ ] Read ISO-related parts of `hci_types.h`, `iso.c` (host), `ull_iso.c` (controller)
- [ ] Deliverable: `phase-5-iso/iso-pipeline.md` § "HCI surface"
- [ ] Verification: lists CIS Setup, CIS Established, BIG Create, BIG Sync flows with command/event pairs
- **Dependencies:** Phase 4 complete

### Task 5.2 — ISOAL
- [ ] Read `subsys/bluetooth/controller/ll_sw/isoal.c` + spec `[Core 6.0, Vol 6, Part G]`
- [ ] Document framed vs unframed segmentation/reassembly
- [ ] Deliverable: `phase-5-iso/iso-pipeline.md` § "ISOAL"
- [ ] Verification: one diagram for TX (SDU→PDU) and one for RX (PDU→SDU)
- **Dependencies:** 5.1

---

## Execution order (visual)

```
Phase 0 (sequential)
  └→ Phase 1 (mostly sequential)
        └→ Phase 2 (2.1‖2.2‖2.3‖2.4 → 2.5)   ─┐
        └→ Phase 3 (3.1‖3.2‖3.3‖3.4)         ─┴→ Phase 4 (sequential)
                                                    └→ Phase 5 (optional)
```

`‖` = parallel-safe (dispatch via `superpowers:subagent-driven-development`, one subagent per task).

## Estimated total effort

| Phase | Tasks | Effort (focused) | Parallelizable |
|---|---|---|---|
| 0 | 4 | ~2h | no |
| 1 | 6 | ~6h | partial (1.5, 1.6 in parallel) |
| 2 | 5 | ~10h | yes (2.1–2.4) |
| 3 | 4 | ~10h | yes (all four) |
| 4 | 2 | ~4h | no |
| 5 | 2 | ~6h | no |
| **Total** | **23** | **~38h** | ~22h wallclock with parallelism |

## Verification before completion

Before declaring the analysis complete, the `superpowers:verification-before-completion` skill applies:

- [ ] Every artifact in the artifact map exists at its specified path
- [ ] Every artifact has `Revision: <SHA>` header matching `00-orientation.md`
- [ ] All mermaid diagrams render without errors (`find docs/ble-analysis -name '*.mmd' -exec mmdc -i {} -o /tmp/check.svg \;`)
- [ ] All file:line citations resolve at the pinned SHA (`scripts/check-citations.sh`, to be written if absent)
- [ ] `glossary.md` has been appended to in every phase
- [ ] Each artifact's `## Open questions` section has been triaged — either answered, deferred to a follow-up plan, or marked "known unknown"

## What this plan deliberately does NOT do

- Does not modify any code (analysis only)
- Does not benchmark or profile (performance work is a separate plan)
- Does not validate against running hardware (could be a follow-up using `tests/bluetooth/bsim/`)
- Does not cover security audit depth (a separate plan, possibly using a `trail-of-bits`-style audit skill)
