# CLAUDE.md — `subsys/bluetooth/controller/ll_sw/nordic/`

The **Nordic vendor LLL implementation** plus the HAL it relies on. Inherits from `ll_sw/CLAUDE.md` and ancestors.

> Anything cited from this directory in Phase 2 artifacts MUST be tagged
> `[LLL-NORDIC]` (or, for HAL files, `[HAL-NORDIC]`). It is vendor-specific
> code, not the generic LLL contract.

## What lives here

```
nordic/
├── lll/                ← Nordic LLL .c implementations (the contract impl)
│   ├── lll.c                  ← Nordic LLL core dispatcher
│   ├── lll_adv.c              ← Adv ISR + state machine (nRF radio)
│   ├── lll_adv_aux.c
│   ├── lll_adv_sync.c
│   ├── lll_adv_iso.c          ← Phase 5 scope
│   ├── lll_scan.c             ← Scan ISR + state machine
│   ├── lll_scan_aux.c
│   ├── lll_sync.c
│   ├── lll_sync_iso.c         ← Phase 5
│   ├── lll_conn.c             ← Connection event ISR + state machine
│   ├── lll_conn_iso.c         ← Phase 5
│   ├── lll_central.c
│   ├── lll_peripheral.c
│   ├── lll_chan.c             ← Channel selection (CSA #1, #2)
│   ├── lll_clock.c            ← LFCLK / HFCLK management
│   ├── lll_df.c, lll_df_*.c   ← Direction Finding ISR
│   ├── lll_test.c             ← DTM (Direct Test Mode)
│   ├── lll_filter.c           ← FAL + RL ISR-side
│   └── lll_prof.c             ← Profiling instrumentation
├── hal/                ← Nordic-specific hardware abstraction layer
│   ├── nrf5/                  ← Per-SoC: nrf51, nrf52, nrf53, nrf54
│   │   ├── radio/             ← RADIO peripheral driver
│   │   │   ├── radio.c        ← Configure PHY, encryption, address, etc.
│   │   │   ├── radio_nrf5*.c  ← Per-SoC variants
│   │   │   ├── radio_df.c     ← Direction Finding RADIO setup
│   │   │   └── radio_chan.c
│   │   ├── ticker/            ← Nordic-specific ticker glue (RTC0/RTC1)
│   │   ├── cntr/              ← Counter abstraction
│   │   ├── ecb.c, ecb.h       ← AES-ECB (link layer encryption setup)
│   │   ├── ccm.c              ← AES-CCM (LL packet encryption)
│   │   ├── debug.c, debug.h   ← Debug pins for timing analysis
│   │   └── mayfly.c           ← Nordic mayfly impl (SWI binding)
│   ├── nrf5/swi.h             ← Software interrupt assignments
│   └── ...
└── (no openisa/ alternative — that's separate sibling)
```

## What the Nordic LLL gets from HAL (Task 2.4 anchor)

The vendor HAL provides these capabilities to the generic LLL:

| Capability | HAL file | Used by LLL for |
|---|---|---|
| Radio (PHY, address, CRC, whitening) | `hal/nrf5/radio/radio.c` | All air events |
| Hardware timer (TIFS, IFS) | `hal/nrf5/radio/radio.c` + nRF TIMER peripheral | Switching between Tx/Rx within IFS budget |
| Real-time counter (slot start) | `hal/nrf5/ticker/cntr_rtc.c` | Ticker base clock |
| Software interrupts (SWI) | `hal/nrf5/swi.h` + EGU peripheral | Mayfly post-ISR work |
| AES-CCM (LL crypto) | `hal/nrf5/ccm.c` + nRF CCM peripheral | Encrypted LL packets |
| AES-ECB (key derivation) | `hal/nrf5/ecb.c` + nRF ECB peripheral | Session key setup |
| PPI/DPPI (peripheral linking) | `hal/nrf5/radio/radio.c` interleaved | Zero-CPU-overhead chains: RADIO → TIMER → RADIO |
| GRTC (nRF54 only) | `hal/nrf5/radio/radio.c` + grtc-specific | Wider-range timer on nRF54 |
| FEM (front-end module) | gated by CONFIG_BT_CTLR_FEM | LNA/PA on supported boards |

**Critical Nordic concept: PPI / DPPI**. The Nordic radio achieves spec-compliant IFS (150 µs) by pre-programming hardware to do RADIO-stop → TIMER-restart → RADIO-start without CPU involvement. When Phase 2 says "Nordic LLL meets TIFS without ISR latency", PPI is the mechanism.

## Per-SoC variation

Don't assume nrf52 LLL = nrf53 LLL = nrf54 LLL:

| SoC | Notable difference |
|---|---|
| nrf51 | Older, limited; some boards may not be at pinned SHA |
| nrf52 | Mainstream, PPI-based |
| nrf53 | Split app + net core; net core has its own LLL build |
| nrf54 | DPPI (Distributed PPI) instead of legacy PPI; GRTC replaces RTC; **different radio peripheral version** |

When tracing radio setup, **check which `radio_nrf5<XX>.c` file is included** at the pinned SHA. Different SoC peripheral versions = different register interface.

## Mayfly on Nordic

`hal/nrf5/mayfly.c` (or wherever it lives at pinned SHA — verify) implements `mayfly_enqueue` using EGU (Event Generator Unit) software interrupts. Each priority level uses a different EGU channel.

When Task 2.1 traces "ULL submits mayfly → LLL fires", the Nordic concrete path is:
1. `mayfly_enqueue()` writes to mayfly FIFO (lock-free)
2. Triggers EGU SWI via `NVIC_SetPendingIRQ`
3. SWI ISR drains FIFO, calls registered callback
4. Callback runs in SWI context (still ISR, but not radio-tight)

**SWI is NOT the same as radio ISR**. Tag SWI-context work as `[SWI]` not `[ISR/LLL]` — different priority, different timing budget, different rules.

## Common pitfalls

1. **Reading `nordic/lll/` without realizing it's vendor-specific**. The function `lll_conn_isr_rx()` here is one of several possible implementations; the contract is in `../lll/lll_conn.h`. Cite this dir → tag `[LLL-NORDIC]`.

2. **`hal/nrf5/` files have per-SoC `#if`s**. `radio.c` contains code for multiple SoCs gated by `CONFIG_SOC_NRF52*` etc. When citing a function, also mention the relevant Kconfig if the implementation branches.

3. **PPI vs DPPI confusion**. nRF53 uses PPI, nRF54 uses DPPI. They look similar but are different peripherals. Some sample code uses macro-based abstraction; some uses direct registers.

4. **Crypto offload location matters**. AES-CCM via the nRF CCM peripheral happens at radio Tx/Rx boundary — packet is encrypted/decrypted by hardware "in flight". It is NOT software AES like SMP uses. Cite `hal/nrf5/ccm.c` for the LL encryption path; `crypto/` directory (separate) for SMP.

5. **`debug.c` / debug pins**. Many LL traces leave assertions like "set debug pin 3 high". These are timing-analysis aids on hardware; they're no-ops if `CONFIG_BT_CTLR_DEBUG_PINS_*` is off. Don't read too much into them for behavior tracing.

## Phase 2 deliverables anchored here

- **Task 2.4** is almost entirely about this directory:
  - Generic LLL contract surface (from `../lll/`) → what Nordic provides
  - Table: "generic LLL needs X" → "Nordic HAL provides via file:line"
  - Radio, timer (RTC + TIMER + GRTC depending on SoC), AES-CCM, AES-ECB, mayfly-SWI, PPI/DPPI, RNG, optional FEM
- **Task 2.1** uses `nordic/lll/lll_*.c` files for the ISR-side examples of mayfly handoffs (look for `mayfly_enqueue` call sites)
- **Task 2.3** uses `nordic/lll/lll_conn.c` for the on-air state of connection events (paired with `ull_conn.c` on the ULL side)
