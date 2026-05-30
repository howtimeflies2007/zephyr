# Phase 1 Prompt Templates — Zephyr BLE Analysis

Copy-pasteable prompts for running Phase 1 (HCI Boundary) of the analysis plan in Claude Code. Same structure as `phase-0-prompts.md` — Master, per-task fallbacks, review, transition, recovery.

> **Why Phase 1 is the most important phase.** Every later phase references the HCI boundary. A wrong call-chain here propagates silently into Phase 2/3 because the dependent phases will read your wrong artifact and trust it. Spend the review time.

---

## Pre-flight checklist (before opening Claude Code)

```bash
cd /path/to/zephyr

# Phase 0 must be complete and reviewed
git log --oneline --grep='analysis(phase-0)' | wc -l    # should be 4
ls docs/ble-analysis/00-orientation.md                  # must exist
ls docs/ble-analysis/glossary.md                        # must exist

# SHA pin from Phase 0 still valid?
PINNED=$(grep '^Revision:' docs/ble-analysis/00-orientation.md | awk '{print $2}')
git cat-file -e $PINNED && echo "SHA OK" || echo "SHA INVALID — re-pin"
[ "$(git rev-parse HEAD)" = "$PINNED" ] || echo "WARN: HEAD has moved past pinned SHA"

# Mermaid renderer needed in Task 1.4
which mmdc || npm i -g @mermaid-js/mermaid-cli

# Working tree clean
git status --short                                       # should be empty
```

If `git status` is dirty, commit or stash before starting. Phase 1 commits aggressively; mixing in unrelated changes makes rollback painful.

Then:

```bash
claude
```

```
/memory                              # confirm CLAUDE.md loaded
/model sonnet                        # Sonnet is enough for tracing; switch to Opus for 1.4 synthesis
```

---

## Master prompt — run all of Phase 1 in one session (recommended)

```
I want to execute Phase 1 of the Zephyr BLE analysis plan
(HCI Boundary).

Plan location: docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
Inputs (read in full before starting Task 1.1):
  - CLAUDE.md
  - docs/ble-analysis/00-orientation.md
  - docs/ble-analysis/glossary.md

Phase 1 dependency graph:
    1.1 ─┬─→ 1.2 ─┬─→ 1.4
         │        ├─→ 1.5
         │        └─→ 1.6
         └─→ 1.3 ─┴─→ 1.4
                   └─→ 1.6

Execution order using superpowers:subagent-driven-development:
  Step 1: Run 1.1 in one subagent. Wait for commit.
  Step 2: Run 1.2 and 1.3 in parallel (two subagents).
          Each gets 1.1's artifact as input. Wait for both commits.
  Step 3: Run 1.4 in one subagent. Switch to Opus for this step —
          it's the first cross-half synthesis and the diagram has to
          actually render.
  Step 4: Run 1.5 and 1.6 in parallel (two subagents).
          Wait for both commits.

For every task, all hard constraints from Phase 0 apply:
  - READ-ONLY for everything under subsys/bluetooth/,
    include/zephyr/bluetooth/, and drivers/bluetooth/.
  - SHA in every new artifact matches 00-orientation.md.
  - file:line citation for every code claim.
  - Kconfig symbol citation for every conditional behavior.
  - Spec section citation for every protocol claim.
  - No quoted spec text longer than 15 words.
  - `## Open questions` section required in every artifact (may be empty).
  - Commit after each task: `analysis(phase-1): 1.X <short title>`.
  - Check off `- [x]` in the plan after each task commits.

Phase-1-specific rules (read carefully):

  R1. CANONICAL BUILD MODE: All tracing uses the COMBINED build mode
      (CONFIG_BT_HCI=y, CONFIG_BT_CTLR=y, both halves in one image).
      This is the only mode where you can follow a call from app to
      air in a single binary. If a function differs between combined
      and host-only, document both — but trace combined first.

  R2. NO HOP SKIPPING: When tracing a call chain, every function in
      the path gets a file:line citation. "Then it eventually reaches
      X" is not acceptable. If a hop goes through a function pointer
      (e.g. bt_dev.drv->send), find the concrete assignment site and
      cite it.

  R3. MARK SIDES EXPLICITLY: Every function in a chain is labeled
      [HOST], [HCI-XPORT], or [CTLR]. The whole point of this phase
      is to make the HCI seam visible — collapsing it back together
      defeats the purpose.

  R4. USE ripgrep: Default to `rg` over grep/find for code searches.
      It respects .gitignore, is faster, and prints file:line in the
      format we need to cite.

  R5. CANONICAL EXAMPLE for Task 1.4: HCI_LE_Set_Advertising_Enable
      (OGF=0x08, OCF=0x000A). Use exactly this command — don't
      substitute. Phase 4 will reuse this example for the extended
      advertising sequence diagram and consistency matters.

Stop at the Phase 1 review checkpoint after all six tasks commit.
Print a summary: artifact paths, total commits, any `## Open questions`
that surfaced. Do not start Phase 2.
```

Expect roughly 1.5–3 hours wallclock. Phase 1 is denser than Phase 0 because each task involves actual code tracing, not just doc summarization.

---

## Individual task prompts

### Task 1.1 — HCI command/event taxonomy

```
Execute Task 1.1 from docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md.
Phase 0 artifacts are inputs (00-orientation.md, glossary.md).

Specifically:
1. Read include/zephyr/bluetooth/hci_types.h in full.
2. Categorize by OGF (OpCode Group Field):
     - Link Control Commands (OGF 0x01)
     - Controller & Baseband Commands (OGF 0x03)
     - Informational Parameters (OGF 0x04)
     - Status Parameters (OGF 0x05)
     - LE Controller Commands (OGF 0x08)
     - Vendor Specific (OGF 0x3F)
3. List event types (note the LE Meta Event 0x3E + subevents pattern).
4. Create docs/ble-analysis/phase-1-hci/boundary.md with the standard
   `Revision:` header.
5. Add `## HCI surface` section: for each OGF group, list
   at least the most common commands with OCF + spec section.
   For events, list at least 5 LE Meta subevents.
6. Verify: at least 5 LE Controller commands (e.g. Set Advertising
   Parameters, Create Connection, Read Local Supported Features) and
   5 LE Meta events (Connection Complete, Advertising Report, etc.)
   are listed with file:line in hci_types.h AND spec section.
7. Commit: `analysis(phase-1): 1.1 HCI command/event taxonomy`.

Do not trace any code paths in this task — that's 1.2 and 1.3.
This is pure surface enumeration.
```

### Task 1.2 — Host-side dispatch

```
Execute Task 1.2 from the plan. Prerequisite: 1.1 complete; boundary.md
exists with the HCI surface section.

Specifically:
1. Read these files in full (in this order):
     subsys/bluetooth/host/hci_core.h
     subsys/bluetooth/host/hci_core.c
   Use `rg` to follow references if you need additional files.
2. Trace COMMANDS OUT (host → controller):
     - Pick the canonical example HCI_LE_Set_Advertising_Enable.
     - Start from bt_le_adv_start() in adv.c, follow every hop:
       adv.c → hci_core.c → bt_hci_cmd_send_sync → tx thread →
       HCI driver send. Each hop = file:line + label [HOST]
       transitioning to [HCI-XPORT] at the driver boundary.
3. Trace EVENTS IN (controller → host):
     - Locate the RX thread: search for K_THREAD_DEFINE or
       k_thread_create in hci_core.c.
     - Trace from buffer arrival → hci_event() dispatch → per-event
       handler. Include LE Meta event split-off.
4. Append a `## Host side` section to boundary.md with:
     - "Commands out" subsection: ordered call list ≥6 hops,
       each `file.c:LLLL <function>  // [side]`.
     - "Events in" subsection: same format, opposite direction.
     - "Thread model" subsection: name of the BT RX thread, its
       priority, what queues feed it.
5. Verify: every hop is a real function (not "eventually" or
   "somehow"). Function pointer hops show concrete assignment site.
6. Commit: `analysis(phase-1): 1.2 host-side HCI dispatch`.

CONSTRAINT: Combined build mode only. If a path differs in host-only
mode, add a `## Open questions` bullet noting "needs host-only
verification" — do not chase it in this task.
```

### Task 1.3 — Controller-side dispatch

```
Execute Task 1.3 from the plan. Prerequisite: 1.1 complete.
This is the MIRROR IMAGE of 1.2 — run in a separate subagent
(parallel to 1.2 is fine; they read different files).

Specifically:
1. Read these files:
     subsys/bluetooth/controller/hci/hci_driver.c
     subsys/bluetooth/controller/hci/hci.c
   Use `rg` to follow into ll_sw/ull_*.c only as needed for the
   first dispatch layer (don't go deep — that's Phase 2).
2. Trace COMMANDS IN (transport → controller LL):
     - Entry point: the bt_hci_driver send() implementation.
     - Decode → opcode dispatch → LL handler call.
     - For HCI_LE_Set_Advertising_Enable specifically, show the
       handoff into ll_adv_enable() or equivalent in ll_sw/.
3. Trace EVENTS OUT (controller LL → transport):
     - Locate the event generation site (often hci_evt_create or
       similar helpers in hci.c).
     - Trace push to host-bound queue → transport drain.
4. Append a `## Controller side` section to boundary.md
   (same file 1.2 wrote to — different section). Same format as 1.2.
   Label all hops [CTLR] transitioning to [HCI-XPORT] at the boundary.
5. Verify: the [HCI-XPORT] boundary in your section matches the
   [HCI-XPORT] boundary 1.2 cited from the host side — they should
   meet at the same struct (`bt_hci_driver`) and same function
   pointer set (send, recv).
6. Commit: `analysis(phase-1): 1.3 controller-side HCI dispatch`.

If 1.2 hasn't committed yet (parallel execution), write your
section to a separate file phase-1-hci/_controller-side.md and
note in the commit message that it needs merging into boundary.md.
```

### Task 1.4 — Cross-half sequence diagram (THE synthesis step)

```
Execute Task 1.4 from the plan. Prerequisites: 1.2 AND 1.3 committed.
Use Opus for this task — it's the first cross-half synthesis and
requires reconciling two independent traces.

Specifically:
1. Read both `## Host side` and `## Controller side` sections of
   docs/ble-analysis/phase-1-hci/boundary.md in full.
2. Verify the boundary handoff: the host's last hop before
   [HCI-XPORT] and the controller's first hop after [HCI-XPORT]
   must reference the same struct and field. If they don't, STOP
   and report — one of 1.2 or 1.3 is wrong.
3. Create docs/ble-analysis/phase-1-hci/cmd-event-flow.mmd as a
   mermaid sequenceDiagram. Use exactly four participants:
     participant App
     participant Host as Host (subsys/bluetooth/host)
     participant Xport as HCI Transport (drivers/bluetooth/hci)
     participant Ctlr as Controller (subsys/bluetooth/controller)
4. Show two flows in one diagram:
     - Top half: HCI_LE_Set_Advertising_Enable command,
       App → Host → Xport → Ctlr → ACK back as Command Complete.
     - Bottom half: spontaneous LE Advertising Report event,
       Ctlr → Xport → Host → App.
5. Every arrow gets a "Note over X: file.c:LLLL <function>"
   immediately below it. Every arrow has both the message name AND
   the file:line label.
6. Validate: run `mmdc -i docs/ble-analysis/phase-1-hci/cmd-event-flow.mmd
   -o /tmp/check.svg`. If it errors, fix the syntax. Do not commit a
   broken .mmd file.
7. Commit: `analysis(phase-1): 1.4 HCI cmd/event sequence diagram`.

If reconciliation in step 2 reveals a mismatch:
  - Do NOT silently fix it by changing one of the traces.
  - Report which trace appears wrong and why.
  - Stop. We'll re-run 1.2 or 1.3 in isolation.
```

### Task 1.5 — Transport driver inventory

```
Execute Task 1.5 from the plan. Prerequisite: 1.2 committed
(needs the bt_hci_driver registration site that 1.2 identified).

Specifically:
1. List transport driver source files:
     ls drivers/bluetooth/hci/*.c
2. For each driver (typically h4, h5, ipc, userchan, spi, uart_async,
   virtual — list exactly what's present at the pinned SHA):
     - Kconfig symbol that enables it (rg in
       drivers/bluetooth/hci/Kconfig).
     - HCI framing it implements (H4? H5? IPC native? raw?).
     - Where it registers itself via DEVICE_DT_INST_DEFINE or the
       newer bt_hci_driver_api registration.
     - Sync vs async receive path.
3. Create docs/ble-analysis/phase-1-hci/transport-drivers.md with
   the standard `Revision:` header.
4. Add a single table with columns:
     Driver | Source | Kconfig | Framing | Registration site
5. Below the table, a short paragraph per driver describing its
   transport-specific quirks (e.g. h5 link supervision, ipc with
   nRF53 NETCORE, userchan for QEMU testing).
6. Verify: table row count matches `ls drivers/bluetooth/hci/*.c |
   grep -v -E '(test_|Kconfig|CMakeLists)' | wc -l`. No driver
   silently omitted.
7. Commit: `analysis(phase-1): 1.5 transport driver inventory`.
```

### Task 1.6 — Buffer flow at the boundary

```
Execute Task 1.6 from the plan. Prerequisites: 1.2 AND 1.3 committed.

Specifically:
1. Identify net_buf pools used at the HCI boundary on BOTH sides:
     - Host: `rg -n 'NET_BUF_POOL' subsys/bluetooth/host/`
     - Controller: `rg -n 'NET_BUF_POOL' subsys/bluetooth/controller/`
   Filter to HCI-relevant pools: command, event, ACL, ISO.
2. For each pool, capture:
     - Pool name (the C identifier).
     - Defining file:line.
     - Buffer count and size — usually macros, trace each macro back
       to its CONFIG_BT_BUF_* Kconfig.
     - Which thread/context allocates from it.
     - Which thread/context frees back to it.
3. Document HCI ACL fragmentation rules:
     - On TX (host side): how a large L2CAP PDU is sliced into
       HCI ACL fragments using PB flags. Cite the function that
       does the slicing.
     - On RX (host side): the reassembly site.
     - On TX/RX (controller side): mirror image, briefly.
4. Append a `## Buffers` section to boundary.md.
5. Verify: every pool entry has Kconfig sizing knob cited. The PB
   (Packet Boundary) flag values used during fragmentation are
   cited from [Core 6.0, Vol 4, Part E, §5.4.2].
6. Commit: `analysis(phase-1): 1.6 buffer flow at HCI boundary`.

Common pitfall: there are pools for "fragmented" outgoing buffers
that aren't the same as the main ACL pool. Look for variants like
`frag_pool`, `discardable_pool`. Don't omit them.
```

---

## Review checkpoint prompt (between Phase 1 and Phase 2)

Open a fresh session. Use Opus.

```
You are reviewing the output of Phase 1 of the Zephyr BLE analysis
(HCI Boundary). This review gates Phase 2.

Read in full:
- CLAUDE.md
- docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
  (Phase 1 section and Execution rules section only)
- docs/ble-analysis/00-orientation.md
- docs/ble-analysis/glossary.md
- docs/ble-analysis/phase-1-hci/boundary.md
- docs/ble-analysis/phase-1-hci/cmd-event-flow.mmd
- docs/ble-analysis/phase-1-hci/transport-drivers.md

Evaluate strictly. For each check, output PASS / FAIL / NEEDS WORK
with specific file:line evidence:

1. SHA consistency: every artifact carries the same Revision SHA
   that matches 00-orientation.md.

2. Citation reality check: sample 8 random file:line citations
   across the artifacts (mix of host and controller side). For each:
     a. Run `git show <SHA>:<path>` and verify the cited line exists.
     b. Verify the function name at that line matches the artifact's
        claim about what the function does.
   If any sample fails, this is FAIL — citations are unreliable.

3. Boundary integrity: in boundary.md, the host's last hop before
   leaving for transport AND the controller's first hop arriving
   from transport must reference the same struct member
   (bt_hci_driver field). Verify by reading the actual struct
   definition.

4. Sequence diagram correctness:
     a. Run `mmdc -i docs/ble-analysis/phase-1-hci/cmd-event-flow.mmd
        -o /tmp/x.svg`. Must succeed.
     b. Every arrow in the diagram has a corresponding file:line
        in boundary.md.
     c. The four participants match the convention
        (App / Host / Xport / Ctlr).

5. Transport driver completeness: count `.c` files in
   drivers/bluetooth/hci/ excluding tests, CMakeLists, Kconfig.
   Compare to row count in transport-drivers.md. Must match.

6. Buffer pool completeness: run
   `rg -c 'NET_BUF_POOL' subsys/bluetooth/host/ subsys/bluetooth/controller/`
   Verify the `## Buffers` section in boundary.md references at least
   the pools used in command, event, ACL TX, ACL RX paths.

7. Build mode discipline: search the artifacts for any claim about
   "host-only mode" or "controller-only mode" behavior. Each such
   claim must either be a confirmed observation or marked as an
   `## Open questions` bullet.

8. Open questions triage: list every `## Open questions` bullet
   across all Phase 1 artifacts. For each, mark:
     - BLOCKS Phase 2 (must resolve before continuing)
     - DEFER to later phase
     - KNOWN UNKNOWN, document and proceed

Do not fix anything. Report only. I'll decide what to redo.
```

If any check FAILs, fix in an isolated session targeting only the failed task, then re-run the review.

---

## Phase 2 kickoff prompt (after Phase 1 review passes)

Phase 2 is the heaviest phase in this plan — 10h of work spread across four parallel-safe tasks plus a synthesis. Use Sonnet for the four parallel tasks, switch to Opus for 2.5.

```
Phase 1 is complete and reviewed. Beginning Phase 2 (Controller).

Plan: docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
Inputs (every subagent reads these in full):
  - CLAUDE.md
  - docs/ble-analysis/00-orientation.md
  - docs/ble-analysis/glossary.md
  - docs/ble-analysis/phase-1-hci/boundary.md
    (specifically the "Controller side" and "Buffers" sections)

Phase 2 structure:
  Tasks 2.1, 2.2, 2.3, 2.4 are parallel-safe.
  Task 2.5 is synthesis — depends on all four.

Execution using superpowers:subagent-driven-development:
  Step 1: Dispatch 4 subagents IN PARALLEL, one per task (2.1–2.4).
          Each gets only its task definition + the inputs above.
          Each commits its artifact independently when done.
  Step 2: When all four commits land, dispatch Task 2.5 to a single
          subagent using Opus. It reads the four prior artifacts and
          produces the integration narrative.

Phase-2-specific rules:

  R1. CONTEXT LABELING IS NON-NEGOTIABLE: every controller function
      cited must be tagged with execution context — [THREAD],
      [MAYFLY], [ISR/LLL], or [SWI]. This is the entire point of
      this phase.

  R2. LLL ≠ vendor LLL. The generic LLL contract lives in
      ll_sw/lll/*.h. The Nordic implementation in ll_sw/nordic/lll/
      is one implementation of that contract. Don't conflate them.

  R3. Spec citations for LL procedures use [Core 6.0, Vol 6, Part B].
      Be precise: e.g. encryption start is §5.1.3.

  R4. Same hard constraints as Phase 1 apply (READ-ONLY, SHA
      consistency, file:line for every claim, etc.).

Stop at the Phase 2 review checkpoint after 2.5 commits.
```

---

## Recovery prompts (Phase-1-specific scenarios)

### Mermaid diagram won't render

```
The mermaid file at <path> fails to render with mmdc. Output:
<paste error>

Common causes in sequenceDiagram syntax:
- participant names with spaces require quoting or `as` alias
- "Note over X: text" requires colon, not just space
- Arrows must be one of: -> ->> --> -->> -x --x
- file:line labels with colons can confuse the parser — wrap in
  backticks or use a different separator inside notes.

Fix the syntax. Re-validate with mmdc before committing. Do not
ship a broken .mmd.
```

### Host trace and controller trace don't meet

Most common Phase 1 failure mode. Symptom: Task 1.4 reports the host's [HCI-XPORT] endpoint and controller's [HCI-XPORT] endpoint reference different things.

```
Task 1.4 reconciliation failed: host trace ends at <X> but
controller trace starts at <Y>. These don't match.

Likely causes:
(a) One of 1.2 or 1.3 traced the wrong build mode (e.g. one
    traced combined, the other host-only).
(b) A function pointer was followed to the wrong concrete
    implementation.
(c) The transport driver was not the same on both sides — e.g.
    host trace went via UART driver while controller trace
    assumed IPC.

Do NOT patch over the mismatch. Identify which of 1.2 or 1.3 is
wrong by:
  1. Locate the bt_hci_driver struct definition.
  2. Find where it's populated in the combined build (search for
     BT_HCI_DRIVER_REGISTER or equivalent).
  3. Confirm both sides actually meet at this struct's send/recv
     function pointers.

Report your findings. I'll decide whether to re-run 1.2 or 1.3.
```

### Function pointer goes somewhere unexpected

```
You cited a function pointer hop (<function> → <pointer>) but
didn't show where <pointer> is assigned. Search for:
  rg -n '\.<pointer_field>\s*=' subsys/ drivers/

In combined builds there is usually exactly one assignment site.
Cite it. If there are multiple, cite all of them and identify which
one is selected at the pinned SHA's default build configuration.
```

### Tracing went too deep into controller LL details

Phase 1 is about the HCI seam, not the LL. If 1.3 starts producing material that belongs in Phase 2:

```
Task 1.3 has expanded into LL internals (ull_*, lll_*) — that's
Phase 2 scope. Truncate the controller-side trace at the first
ll_*() or ull_*() entry point. Note in `## Open questions` that
"controller-internal dispatch beyond the LL entry point is covered
in Phase 2, Task 2.1." Do not delete content — move surplus material
into a notes/ subdirectory for Phase 2 to pick up.
```

### Subagents 1.2 and 1.3 wrote to the same file and conflict

If you ran 1.2 and 1.3 in parallel and they both tried to append to boundary.md:

```
Resolve the merge: 1.2 owns the `## Host side` section,
1.3 owns the `## Controller side` section. Reorder so host comes
first, controller second. Both share the file's `Revision:` header
and `## HCI surface` section (from 1.1).

If both wrote different versions of the shared header, prefer the
one with the SHA matching 00-orientation.md.
```

To avoid this in the future: instruct parallel subagents to write to scratch files (`_host-side.md`, `_controller-side.md`) and merge in a follow-up step. The Task 1.3 prompt above already does this as a fallback.

---

## Notes on Phase 1 specifics

- **Why Sonnet for most, Opus for 1.4 and review**: Tasks 1.1–1.3, 1.5, 1.6 are tracing and enumeration — Sonnet is fast and accurate. Task 1.4 reconciles two independent traces into a diagram that has to actually compile; Opus catches mismatches Sonnet sometimes papers over. Review is the highest-leverage checkpoint in the whole analysis — never cheap out here.

- **Why "combined build mode only" for tracing**: Host-only and controller-only modes introduce a real serial link (UART/SPI/IPC) at the HCI seam. In those modes the call chain is interrupted by the transport's async machinery, which makes the trace much harder to follow. Combined mode lets you see the whole path in one binary. Phase 1's purpose is conceptual: where IS the seam. Behavioral differences between modes are noted as Open questions and revisited later if relevant.

- **The mmdc validation is non-negotiable**: a broken .mmd in git is worse than no .mmd, because later phases trust that artifacts work. Don't accept "I'll fix the diagram syntax later" from a subagent.

- **Phase 1 is where Claude's tendency to "summarize" first hurts you**: code-tracing tasks have a long tail of small hops, and a subagent under context pressure will start collapsing hops into "the buffer eventually reaches X." The R2 ("no hop skipping") rule in the Master prompt is there because it WILL try this. Catch it in review.

- **Expect 1–2 redo cycles on Task 1.4**: it's the first task in the whole plan that synthesizes across two independent subagent outputs. If 1.2 or 1.3 were slightly wrong, 1.4 surfaces it. That's the design — better here than in Phase 4.
