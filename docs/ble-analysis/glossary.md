# Zephyr BLE Analysis — Glossary

Revision: c2dc4ea037a6c1c0dce37d44949b066face27bea

> This glossary is the accumulating cross-phase term list: it is **appended to in every later phase** of the BLE analysis. Terms below are the Task 0.4 seed set.

Terms are in alphabetical order. Format: **TERM** — one-sentence definition (paraphrased). _Source:_ citation.

---

**ACL** — Asynchronous Connection-Less logical transport carrying connection data packets between host and controller and over the LE link. _Source:_ `[Core 6.0, Vol 4, Part E (HCI)]` for HCI ACL data path; LE link-layer ACL framing `[Core 6.0, Vol 6, Part B]` (verify §).

**ATT** — Attribute Protocol, the client/server protocol that exposes a peer's attributes (handle, type, value, permissions) and on which GATT is built. _Source:_ `[Core 6.0, Vol 3, Part F]` (verify §).

**ATT MTU** — The maximum size of an ATT protocol payload that a peer can receive on a connection, negotiated via the MTU Exchange procedure. _Source:_ `[Core 6.0, Vol 3, Part F]` (verify §); see also host code `subsys/bluetooth/host/att.c`.

**GATT** — Generic Attribute Profile, the most common BLE communication framework layered over ATT, organizing attributes into services and characteristics. _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:270`; `[Core 6.0, Vol 3, Part G]` (verify §).

**HCI** — Host Controller Interface, the standardized command/event/data boundary between the Bluetooth host and controller. _Source:_ `[Core 6.0, Vol 4, Part E (HCI)]`; host side `subsys/bluetooth/host/hci_core.c`.

**IRK** — Identity Resolving Key, the SMP key a device distributes so peers can resolve its Resolvable Private Addresses back to its identity. _Source:_ `[Core 6.0, Vol 3, Part H (Security Manager)]` (verify §); host key storage `subsys/bluetooth/host/keys.c`.

**L2CAP** — Logical Link Control and Adaptation Protocol, the common multiplexing layer for all data over a Bluetooth connection, surfaced to apps mainly via Connection-oriented Channels. _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:148`; `[Core 6.0, Vol 3, Part A]`.

**LL** — Link Layer, the controller-side state machine that manages the LE air interface (advertising, scanning, connections, control procedures). _Source:_ `[Core 6.0, Vol 6, Part B]` (verify §); in-tree LL at `subsys/bluetooth/controller/ll_sw/`.

**LLL** — Lower Link Layer, the vendor, radio-ISR-context half of Zephyr's split Link Layer that owns the air interface. _Source:_ `doc/connectivity/bluetooth/bluetooth-ctlr-arch.rst:136`; code under `subsys/bluetooth/controller/ll_sw/lll/`.

**LTK** — Long Term Key, the SMP-derived key used to encrypt an LE link and re-establish encryption on later reconnections. _Source:_ `[Core 6.0, Vol 3, Part H (Security Manager)]` (verify §); host key storage `subsys/bluetooth/host/keys.c`.

**mayfly** — A controller deferred-execution primitive that enqueues short jobs to run later in a lower-priority ISR context, used to bridge LLL and ULL. _Source:_ `subsys/bluetooth/controller/util/mayfly.h:8` (struct/IDs); concept noted in `doc/connectivity/bluetooth/bluetooth-ctlr-arch.rst:35`.

**MPS** — Maximum Payload Size, the largest L2CAP payload the L2CAP layer itself can accept in one PDU. _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:192`; `[Core 6.0, Vol 3, Part A]`.

**MTU** — Maximum Transmission Unit, the largest SDU the L2CAP upper layer is able to accept. _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:189`; `[Core 6.0, Vol 3, Part A]`.

**net_buf** — Zephyr's reference-counted network buffer object used throughout the BLE stack for pooled packet management without hot-path allocation. _Source:_ `include/zephyr/net_buf.h:24` (`@defgroup net_buf Network Buffer Library`).

**PDU** — Protocol Data Unit, a packet of L2CAP data that begins with the Basic L2CAP header (length + CID). _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:180`; `[Core 6.0, Vol 3, Part A]`.

**RPA** — Resolvable Private Address, a periodically changing random address generated from an IRK so only peers holding that IRK can identify the device. _Source:_ `[Core 6.0, Vol 6, Part B]` address types / `[Core 6.0, Vol 3, Part C]` (verify §); helper code `subsys/bluetooth/common/`.

**SDU** — Service Data Unit, a packet of data L2CAP exchanges with the upper layer. _Source:_ `doc/connectivity/bluetooth/bluetooth-le-host.rst:174`; `[Core 6.0, Vol 3, Part A]`.

**ULL** — Upper Link Layer, the generic, mayfly/thread-context half of Zephyr's split Link Layer that owns scheduling and control-procedure handling. _Source:_ `doc/connectivity/bluetooth/bluetooth-ctlr-arch.rst:136`; code `subsys/bluetooth/controller/ll_sw/ull_*.c`.

---

## Open questions

- Several spec citations are marked **(verify §)** because exact section numbers were not confirmed at this SHA: ACL (Vol 6 Part B framing), ATT/ATT MTU (Vol 3 Part F), GATT (Vol 3 Part G), IRK/LTK (Vol 3 Part H), LL (Vol 6 Part B), RPA (Vol 6 Part B / Vol 3 Part C). The host doc's L2CAP terminology table is sourced from Core Spec v5.4 (Vol 3, Part A, §1.4); Core 6.0 section numbering should be re-validated.
- For **LLL/ULL**, the controller arch `.rst` describes the split mostly via images; the most concrete textual line is `bluetooth-ctlr-arch.rst:136`. A finer definition would require citing the code split (`ll_sw/lll/` vs `ll_sw/ull_*.c`), already noted in each entry.
- **RPA** has two plausible source locations (LL address types in Vol 6 Part B vs. privacy in Vol 3 Part C); both are listed pending a definitive pick.
- **Spec version baseline**: Terms in this glossary follow Bluetooth Core Spec v5.4 wording (as Zephyr's own documentation uses). Procedure-level citations in Phase 1+ artifacts will use Core 6.x section numbers. Cross-version terminology drift is small; Part letters and section numbers will be spot-verified ad-hoc when first cited in later phases.
