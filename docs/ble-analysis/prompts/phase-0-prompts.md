# Phase 0 Prompt Templates — Zephyr BLE Analysis

Copy-pasteable prompts for running Phase 0 of the analysis plan in Claude Code. Templates are stable — only the four `{{PLACEHOLDERS}}` need filling each run.

---

## Pre-flight checklist (before opening Claude Code)

Run these in a normal shell, not in Claude Code:

```bash
cd /path/to/zephyr
git status                                  # working tree clean?
git rev-parse HEAD                          # note this SHA — you'll cite it
ls CLAUDE.md                                # root CLAUDE.md exists?
ls docs/ble-analysis/plans/                 # plan file exists?
ls .claude/settings.json                    # permissions configured?
which mmdc || npm i -g @mermaid-js/mermaid-cli   # mermaid renderer needed in Task 1.4+
```

If any of those fail, fix before starting. Especially: a dirty working tree means the SHA pin in Task 0.1 will be meaningless.

Then:

```bash
claude
```

In the session, before sending the first prompt:

```
/memory
```

Confirm `CLAUDE.md` appears in the loaded files list. If it doesn't, you're not in the right directory — quit and re-`cd`.

```
/model opus
```

Phase 0 is short but sets foundations every later phase depends on. Use the strongest model here; switch to Sonnet for bulk work in Phases 1–3.

---

## Master prompt — run all of Phase 0 in one session (recommended)

Paste this as the first message. It runs all four Phase 0 tasks sequentially, with commits between each, and stops at the review checkpoint.

```
I want to execute Phase 0 of the Zephyr BLE analysis plan.

Plan location: docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
Root context: CLAUDE.md (already loaded)

Before starting, read both files in full. Then execute Tasks 0.1
through 0.4 sequentially using superpowers:subagent-driven-development
(one subagent per task — each subagent gets only the relevant task
definition, the plan's "Execution rules" section, and read access to
the repo).

For every task:
1. Produce the deliverable at the exact path specified in the plan.
2. Include the `Revision: <SHA>` header (Task 0.1 establishes the
   canonical SHA; 0.2–0.4 must use the same one).
3. Satisfy the "Verification" criterion listed in the plan before
   marking the task done.
4. After each task: `git add` the new file(s) and commit with message
   `analysis(phase-0): 0.X <short title>`.
5. After each task: edit the plan file to check off `- [x]` for that
   task's bullets.

Hard constraints:
- READ-ONLY for everything under subsys/bluetooth/ and
  include/zephyr/bluetooth/. Never edit source.
- No paraphrasing of Bluetooth Core Spec text beyond 15 words —
  cite section number and summarize in your own words.
- Every code claim cites file:line. Every conditional behavior cites
  the gating Kconfig symbol.
- If you encounter ambiguity, add a bullet under the artifact's
  `## Open questions` section instead of guessing.

After Task 0.4 commits successfully, STOP. Do not start Phase 1.
Print a summary of the four artifacts produced and ask me to review
before continuing.
```

That single prompt should produce four committed artifacts (`00-orientation.md` updated three times, `glossary.md` created) in roughly 20–40 minutes wallclock.

---

## Individual task prompts (granular control)

Use these when running tasks one at a time — debugging, redoing a task, or running Phase 0 across multiple sessions.

### Task 0.1 — Pin revision

```
Execute Task 0.1 from docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md.

Specifically:
1. Run `git rev-parse HEAD`, `git describe --always --tags`, and
   `west list -f '{name} {revision} {path}'`. Capture all output.
2. Capture `zephyr-sdk --version` (if available), `west --version`,
   `cmake --version`.
3. Create docs/ble-analysis/00-orientation.md with a top-level
   header block containing all the above, plus today's date and
   the Bluetooth Core Spec version this analysis targets
   (v6.0 unless I tell you otherwise — confirm with me if unsure).
4. Verify: `git cat-file -e <SHA>` succeeds against the recorded SHA.
5. Commit: `analysis(phase-0): 0.1 pin revision and toolchain`.
```

### Task 0.2 — Build-mode enumeration

```
Execute Task 0.2 from the plan. Prerequisites: Task 0.1 complete,
00-orientation.md exists with pinned SHA.

Specifically:
1. Read doc/connectivity/bluetooth/bluetooth-arch.rst in full.
2. Identify the three build modes (combined / host-only /
   controller-only).
3. For each mode, find one sample under samples/bluetooth/ that
   exemplifies it. Read its prj.conf. Note which Kconfigs differ
   from the defaults documented in subsys/bluetooth/Kconfig.
4. Append a `## Build modes` section to 00-orientation.md with a
   table: mode | minimum Kconfig set | example sample (path) |
   halves present (host/controller/both).
5. Verify: every row has all four columns filled with concrete
   values (not "TBD").
6. Commit: `analysis(phase-0): 0.2 build-mode enumeration`.

If you cannot confidently identify the Kconfig minimum for any
mode, add it as an `## Open questions` bullet rather than guessing.
```

### Task 0.3 — Reference index

```
Execute Task 0.3 from the plan. Prerequisites: 0.1 and 0.2 complete.

Specifically:
1. `find doc/connectivity/bluetooth -name '*.rst' -not -path '*/_includes/*'`
   to enumerate every BLE doc file.
2. For each: read the title and first paragraph. Categorize as
   in-scope (relevant to this analysis) or out-of-scope (BR/EDR,
   Mesh top-layer, Audio profiles).
3. Append a `## References` section to 00-orientation.md with:
   (a) internal docs table (path | title | scope),
   (b) external references: Bluetooth Core Spec volumes most-cited
       by this analysis (Vol 1 Architecture, Vol 3 Part F/G ATT/GATT,
       Vol 6 Part B Link Layer, Vol 6 Part G ISOAL).
4. Verify: every .rst in the find output is either in the table or
   in the out-of-scope list — none silently omitted.
5. Commit: `analysis(phase-0): 0.3 reference index`.
```

### Task 0.4 — Seed glossary

```
Execute Task 0.4 from the plan. Prerequisites: 0.1, 0.2, 0.3 complete.

Specifically:
1. Read the glossary section of
   doc/connectivity/bluetooth/bluetooth-le-host.rst.
2. Create docs/ble-analysis/glossary.md with a `Revision:` header
   matching 00-orientation.md.
3. Define each of these terms in 1–2 sentences with source citation
   (spec section or file path):
   ACL, ATT, ATT MTU, GATT, L2CAP, MPS, MTU, PDU, SDU, HCI, LL, LLL,
   ULL, mayfly, net_buf, RPA, IRK, LTK, CSRK, SMP, COC, CIS, BIS,
   ISOAL, GAP.
4. Format: one term per `### TERM` heading, alphabetical. Each entry
   ends with `Source: <citation>`.
5. Verify: every term has a definition AND a source. No "TODO".
6. Commit: `analysis(phase-0): 0.4 seed glossary`.

For any term you cannot define from primary sources (the doc/ tree
or the spec section numbers I gave you in CLAUDE.md), add it under
`## Open questions` at the bottom of glossary.md rather than guessing
from training-data memory.
```

---

## Review checkpoint prompt (between Phase 0 and Phase 1)

Open a fresh session for this — review wants a clean perspective, not the same context that produced the artifacts.

```
You are reviewing the output of Phase 0 of the Zephyr BLE analysis.

Read these files in full:
- CLAUDE.md
- docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
  (only the "Phase 0" section and the "Execution rules" section)
- docs/ble-analysis/00-orientation.md
- docs/ble-analysis/glossary.md

Then evaluate, strictly:

1. SHA pinning: Does every artifact carry the same Revision SHA?
   Does `git cat-file -e <SHA>` succeed?
2. Build modes: For each row in the build-modes table, verify the
   sample path exists and its prj.conf actually contains the cited
   Kconfigs. Flag any row where this doesn't check out.
3. References: Does the count of .rst files in the table plus the
   out-of-scope list equal the actual count from
   `find doc/connectivity/bluetooth -name '*.rst'
    -not -path '*/_includes/*' | wc -l`?
4. Glossary: For each of the 25 required terms, is the source
   citation valid (spec section number well-formed, or file path
   that exists)?
5. Open questions: Are there any open-question bullets that block
   Phase 1 from starting? (Phase 1 needs build modes and HCI
   command terminology to be solid.)

Output a checklist with PASS / FAIL / NEEDS WORK for each of the 5
above, with specific file:line references to anything that's wrong.
Do NOT fix anything yourself — just report. I'll decide what to redo.

Use Opus, take your time, be picky. The cost of letting a mistake
through here is propagated across Phases 1–5.
```

If review comes back clean, proceed to Phase 1. If anything fails, fix in a new session targeting only the failed task — don't try to patch in the review session itself.

---

## Phase 1 kickoff prompt (after Phase 0 review passes)

Open a fresh session. The Phase 0 artifacts are now load-bearing for everything that follows.

```
Phase 0 is complete and reviewed. Beginning Phase 1 (HCI Boundary).

Plan: docs/ble-analysis/plans/2026-05-30-zephyr-ble-analysis.md
Inputs (read in full before starting):
- CLAUDE.md
- docs/ble-analysis/00-orientation.md     (pinned SHA, build modes)
- docs/ble-analysis/glossary.md           (terminology)

Execute Tasks 1.1 through 1.6 using superpowers:subagent-driven-development.

Dependency graph for this phase:
  1.1 → 1.2 → 1.4
  1.1 → 1.3 → 1.4
  1.2 → 1.5, 1.6 (parallel-safe)
  1.3 → 1.6

Execution order:
  1. Run 1.1 (single subagent).
  2. Run 1.2 and 1.3 in parallel (two subagents).
  3. Run 1.4 (single subagent, depends on 1.2+1.3).
  4. Run 1.5 and 1.6 in parallel (two subagents).

Same hard constraints as Phase 0:
- READ-ONLY for source.
- SHA in every artifact matches 00-orientation.md.
- file:line + Kconfig + spec section for every claim.
- Commit after each task.
- `## Open questions` section required in every artifact.

Stop at the Phase 1 review checkpoint after all six tasks commit.
```

---

## Recovery prompts (when things go sideways)

### Claude started editing source files

Interrupt immediately (Esc), then:

```
You attempted to edit a file under subsys/bluetooth/. That violates
the plan's read-only rule. Roll back any uncommitted changes:

  git restore subsys/

Then re-read the "Execution rules" section of the plan and confirm
you understand the read-only constraint before continuing.
```

If it already committed an edit, abort the session and `git revert <SHA>` outside Claude Code.

### Claude is paraphrasing spec text closely

```
Stop. The text at <artifact-path:line-N> looks too close to the
Bluetooth Core Spec wording. The rule is: cite section number,
summarize in your own words, no quote longer than 15 words.

Rewrite that paragraph. If you can't summarize without quoting,
shorten to a one-sentence reference: "See [Core 6.0, Vol X, Part Y,
§Z] for the procedure."
```

### Context window is filling up mid-task

```
Save current progress: commit any complete work in progress with
message `analysis(phase-N): WIP <task-id>`. Then summarize in 5
bullet points what has been established so far and what remains
for this task. I'll open a fresh session to continue.
```

Then `/clear` and open a new session using the individual task prompt for that task plus the WIP summary as input.

### A task's verification fails

```
Task <N.M> verification did not pass: <specific failure>.
Do NOT proceed to the next task. Either:
  (a) fix the deliverable in this session and re-verify, or
  (b) if you cannot fix it confidently, leave the artifact as-is,
      add a detailed `## Open questions` entry describing what's
      wrong and what would be needed to fix it, and stop.
Either way, do not pretend the task passed.
```

---

## Notes on customization

- **If you want shorter sessions**: split the Master prompt — run Task 0.1+0.2 in one session, 0.3+0.4 in another. The plan's dependency graph allows this.
- **If you're on a tight token budget**: skip the Master prompt and use the four individual task prompts directly. Cuts ~30% of orientation overhead.
- **If you discover the plan is wrong**: don't have Claude edit the plan mid-execution. Stop the session, edit the plan manually (it's just markdown), commit the plan change as `plan: revise task X.Y` then restart.
- **For Phase 2 and 3** (the parallel ones): write a similar prompt file with the same structure. Master prompt + per-task fallbacks + review + recovery. The patterns above transfer directly.
