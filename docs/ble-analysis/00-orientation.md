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

## Open questions

1. **No west workspace**: `west list` failed because the repo was not checked out via `west init`. Later tasks that need to know which Zephyr module versions (hal_nordic, mbedtls, trusted-firmware-m, etc.) are paired with this SHA will need either a `.west/` workspace or a manually recorded `west.yml` manifest snapshot. The manifest lives at `west.yml` in the repo root — it should be read in a future task if module versions become relevant to BLE analysis.

2. **No Zephyr SDK**: Build-time checks (e.g., verifying that a Kconfig combination actually compiles) cannot be performed on this host. Any behavioral claim that requires a build artifact must be flagged as "not build-verified."
