# Zephyr BLE Analysis — Phase 1: HCI Boundary

Revision: c2dc4ea037a6c1c0dce37d44949b066face27bea

---

## HCI surface

HCI (Host Controller Interface) is the standardized binary boundary between the Bluetooth Host stack and the Link Layer controller; all data and control flow between the two halves pass through this seam as typed packets (command, ACL, ISO, event). In Zephyr, this boundary is the single architectural point where host-only, controller-only, and combined build modes diverge in their transport wiring.

### HCI command groups by OGF

The opcode of every HCI command encodes a 6-bit Opcode Group Field (OGF) and a 10-bit Opcode Command Field (OCF), packed by `BT_OP(ogf, ocf)` at `include/zephyr/bluetooth/hci_types.h:386`. The OGF values defined in the file are:

| OGF (hex) | Group name | Example commands defined in hci_types.h | Count |
|---|---|---|---|
| `0x01` | Link Control | `BT_HCI_OP_INQUIRY`, `BT_HCI_OP_DISCONNECT`, `BT_HCI_OP_CONNECT`, `BT_HCI_OP_ACCEPT_CONN_REQ`, `BT_HCI_OP_AUTH_REQUESTED` | 26 |
| `0x02` | Link Policy | `BT_HCI_OP_SWITCH_ROLE`, `BT_HCI_OP_READ_LINK_POLICY_SETTINGS`, `BT_HCI_OP_WRITE_LINK_POLICY_SETTINGS`, `BT_HCI_OP_SNIFF_MODE`, `BT_HCI_OP_EXIT_SNIFF_MODE` | 7 |
| `0x03` | Controller & Baseband | `BT_HCI_OP_RESET`, `BT_HCI_OP_SET_EVENT_MASK`, `BT_HCI_OP_HOST_BUFFER_SIZE`, `BT_HCI_OP_WRITE_LOCAL_NAME`, `BT_HCI_OP_WRITE_SSP_MODE` | 26 |
| `0x04` | Informational Parameters | `BT_HCI_OP_READ_LOCAL_VERSION_INFO`, `BT_HCI_OP_READ_SUPPORTED_COMMANDS`, `BT_HCI_OP_READ_LOCAL_FEATURES`, `BT_HCI_OP_READ_BD_ADDR`, `BT_HCI_OP_READ_CODECS` | 10 |
| `0x05` | Status Parameters | `BT_HCI_OP_READ_RSSI`, `BT_HCI_OP_READ_ENCRYPTION_KEY_SIZE` | 2 |
| `0x08` | LE Controller commands | `BT_HCI_OP_LE_SET_EVENT_MASK`, `BT_HCI_OP_LE_SET_ADV_ENABLE`, `BT_HCI_OP_LE_CREATE_CONN`, `BT_HCI_OP_LE_SET_EXT_ADV_PARAM`, `BT_HCI_OP_LE_SET_CIG_PARAMS` | 151 |
| `0x3F` | Vendor Specific | (OGF defined at line 383; no concrete VS opcodes in this header — VS commands are defined per-vendor at runtime) | 0 in-tree |

OGF macro definitions: `BT_OGF_LINK_CTRL` (line 377), `BT_OGF_LINK_POLICY` (line 378), `BT_OGF_BASEBAND` (line 379), `BT_OGF_INFO` (line 380), `BT_OGF_STATUS` (line 381), `BT_OGF_LE` (line 382), `BT_OGF_VS` (line 383).

---

### LE Controller commands (OGF=0x08)

All LE commands are packed as `BT_OP(BT_OGF_LE, ocf)`. The table below lists selected commands representative of the major functional areas:

| OpCode (hex) | Name | hci_types.h line | Spec section |
|---|---|---|---|
| `0x2001` | `BT_HCI_OP_LE_SET_EVENT_MASK` | 1160 | [Core 6.0, Vol 4, Part E, §7.8.1] |
| `0x2002` | `BT_HCI_OP_LE_READ_BUFFER_SIZE` | 1165 | [Core 6.0, Vol 4, Part E, §7.8.2] |
| `0x2005` | `BT_HCI_OP_LE_SET_RANDOM_ADDRESS` | 1178 | [Core 6.0, Vol 4, Part E, §7.8.4] |
| `0x2006` | `BT_HCI_OP_LE_SET_ADV_PARAM` | 1204 | [Core 6.0, Vol 4, Part E, §7.8.5] |
| `0x2008` | `BT_HCI_OP_LE_SET_ADV_DATA` | 1221 | [Core 6.0, Vol 4, Part E, §7.8.7] |
| `0x200a` | `BT_HCI_OP_LE_SET_ADV_ENABLE` | 1236 | [Core 6.0, Vol 4, Part E, §7.8.9] |
| `0x200b` | `BT_HCI_OP_LE_SET_SCAN_PARAM` | 1242 | [Core 6.0, Vol 4, Part E, §7.8.10] |
| `0x200c` | `BT_HCI_OP_LE_SET_SCAN_ENABLE` | 1259 | [Core 6.0, Vol 4, Part E, §7.8.11] |
| `0x200d` | `BT_HCI_OP_LE_CREATE_CONN` | 1272 | [Core 6.0, Vol 4, Part E, §7.8.12] |
| `0x200e` | `BT_HCI_OP_LE_CREATE_CONN_CANCEL` | 1291 | [Core 6.0, Vol 4, Part E, §7.8.13] |
| `0x2013` | `BT_HCI_OP_LE_CONN_UPDATE` | 1311 | [Core 6.0, Vol 4, Part E, §7.8.18] |
| `0x2017` | `BT_HCI_OP_LE_ENCRYPT` | 1342 | [Core 6.0, Vol 4, Part E, §7.8.22] |
| `0x2019` | `BT_HCI_OP_LE_START_ENCRYPTION` | 1358 | [Core 6.0, Vol 4, Part E, §7.8.24] |
| `0x201a` | `BT_HCI_OP_LE_LTK_REQ_REPLY` | 1366 | [Core 6.0, Vol 4, Part E, §7.8.25] |
| `0x2022` | `BT_HCI_OP_LE_SET_DATA_LEN` | 1443 | [Core 6.0, Vol 4, Part E, §7.8.33] |
| `0x2025` | `BT_HCI_OP_LE_P256_PUBLIC_KEY` | 1467 | [Core 6.0, Vol 4, Part E, §7.8.36] |
| `0x2026` | `BT_HCI_OP_LE_GENERATE_DHKEY` | 1469 | [Core 6.0, Vol 4, Part E, §7.8.37] |
| `0x2027` | `BT_HCI_OP_LE_ADD_DEV_TO_RL` | 1486 | [Core 6.0, Vol 4, Part E, §7.8.38] |
| `0x202d` | `BT_HCI_OP_LE_SET_ADDR_RES_ENABLE` | 1527 | [Core 6.0, Vol 4, Part E, §7.8.44] |
| `0x2030` | `BT_HCI_OP_LE_READ_PHY` | 1561 | [Core 6.0, Vol 4, Part E, §7.8.47] |
| `0x2031` | `BT_HCI_OP_LE_SET_DEFAULT_PHY` | 1579 | [Core 6.0, Vol 4, Part E, §7.8.48] |
| `0x2032` | `BT_HCI_OP_LE_SET_PHY` | 1590 | [Core 6.0, Vol 4, Part E, §7.8.49] |
| `0x2036` | `BT_HCI_OP_LE_SET_EXT_ADV_PARAM` | 1652 | [Core 6.0, Vol 4, Part E, §7.8.53] |
| `0x2039` | `BT_HCI_OP_LE_SET_EXT_ADV_ENABLE` | 1727 | [Core 6.0, Vol 4, Part E, §7.8.56] |
| `0x2041` | `BT_HCI_OP_LE_SET_EXT_SCAN_PARAM` | 1794 | [Core 6.0, Vol 4, Part E, §7.8.64] |
| `0x2043` | `BT_HCI_OP_LE_EXT_CREATE_CONN` | 1823 | [Core 6.0, Vol 4, Part E, §7.8.66] |
| `0x2044` | `BT_HCI_OP_LE_PER_ADV_CREATE_SYNC` | 1919 | [Core 6.0, Vol 4, Part E, §7.8.67] |
| `0x2062` | `BT_HCI_OP_LE_SET_CIG_PARAMS` | 2258 | [Core 6.0, Vol 4, Part E, §7.8.97] |
| `0x2064` | `BT_HCI_OP_LE_CREATE_CIS` | 2324 | [Core 6.0, Vol 4, Part E, §7.8.99] |
| `0x2068` | `BT_HCI_OP_LE_CREATE_BIG` | 2361 | [Core 6.0, Vol 4, Part E, §7.8.103] |
| `0x206e` | `BT_HCI_OP_LE_SETUP_ISO_PATH` | 2430 | [Core 6.0, Vol 4, Part E, §7.8.109] |
| `0x2074` | `BT_HCI_OP_LE_SET_HOST_FEATURE` | 2509 | [Core 6.0, Vol 4, Part E, §7.8.115] |
| `0x207A` | `BT_HCI_OP_LE_SET_TX_POWER_REPORT_ENABLE` | 782 | [Core 6.0, Vol 4, Part E, §7.8.121] |
| `0x207D` | `BT_HCI_OP_LE_SET_DEFAULT_SUBRATE` | 819 | [Core 6.0, Vol 4, Part E, §7.8.122] |
| `0x207E` | `BT_HCI_OP_LE_SUBRATE_REQUEST` | 829 | [Core 6.0, Vol 4, Part E, §7.8.123] |
| `0x2082` | `BT_HCI_OP_LE_SET_PER_ADV_SUBEVENT_DATA` | 1854 | [Core 6.0, Vol 4, Part E, §7.8.125] |
| `0x2085` | `BT_HCI_OP_LE_EXT_CREATE_CONN_V2` | 1824 | [Core 6.0, Vol 4, Part E, §7.8.128] |
| `0x2087` | `BT_HCI_OP_LE_READ_ALL_LOCAL_SUPPORTED_FEATURES` | 2549 | [Core 6.0, Vol 4, Part E, §7.8.131] |
| `0x2089` | `BT_HCI_OP_LE_CS_READ_LOCAL_SUPPORTED_CAPABILITIES` | 2579 | [Core 6.0, Vol 4, Part E, §7.8.133] |

Note: 151 total `BT_OP(BT_OGF_LE, ...)` macro definitions are present in this header at the pinned revision.

---

### HCI events

The general HCI event code (carried in `bt_hci_evt_hdr.evt`) is defined at `include/zephyr/bluetooth/hci_types.h`. Key standard events include:

| Event code (hex) | Name | hci_types.h line | Notes |
|---|---|---|---|
| `0x03` | `BT_HCI_EVT_CONN_COMPLETE` | 3092 | BR/EDR connection completion |
| `0x05` | `BT_HCI_EVT_DISCONN_COMPLETE` | 3108 | Connection disconnection (LE + BR/EDR) |
| `0x08` | `BT_HCI_EVT_ENCRYPT_CHANGE` | 3134 | Encryption state change |
| `0x0e` | `BT_HCI_EVT_CMD_COMPLETE` | 3157 | Synchronous command acknowledgement |
| `0x0f` | `BT_HCI_EVT_CMD_STATUS` | 3167 | Status for long-running commands |
| `0x13` | `BT_HCI_EVT_NUM_COMPLETED_PACKETS` | 3186 | Flow-control credit return |
| `0x3e` | `BT_HCI_EVT_LE_META_EVENT` | 3417 | Umbrella for all LE sub-events |
| `0x57` | `BT_HCI_EVT_AUTH_PAYLOAD_TIMEOUT_EXP` | 3423 | Authenticated payload timer expired |

The LE Meta Event (`0x3e`) carries a `subevent` byte that selects the specific LE event. The `struct bt_hci_evt_le_meta_event` wrapper is at line 3418.

#### LE Meta sub-events (BT_HCI_EVT_LE_*)

55 LE meta sub-event codes are defined in this header. Selected entries covering the core LE use-cases:

| Subevent code (hex) | Name | hci_types.h line | Spec section |
|---|---|---|---|
| `0x01` | `BT_HCI_EVT_LE_CONN_COMPLETE` | 3431 | [Core 6.0, Vol 4, Part E, §7.7.65.1] |
| `0x02` | `BT_HCI_EVT_LE_ADVERTISING_REPORT` | 3445 | [Core 6.0, Vol 4, Part E, §7.7.65.2] |
| `0x03` | `BT_HCI_EVT_LE_CONN_UPDATE_COMPLETE` | 3472 | [Core 6.0, Vol 4, Part E, §7.7.65.3] |
| `0x04` | `BT_HCI_EVT_LE_REMOTE_FEAT_COMPLETE` | 3481 | [Core 6.0, Vol 4, Part E, §7.7.65.4] |
| `0x05` | `BT_HCI_EVT_LE_LTK_REQUEST` | 3488 | [Core 6.0, Vol 4, Part E, §7.7.65.5] |
| `0x06` | `BT_HCI_EVT_LE_CONN_PARAM_REQ` | 3495 | [Core 6.0, Vol 4, Part E, §7.7.65.6] |
| `0x07` | `BT_HCI_EVT_LE_DATA_LEN_CHANGE` | 3504 | [Core 6.0, Vol 4, Part E, §7.7.65.7] |
| `0x08` | `BT_HCI_EVT_LE_P256_PUBLIC_KEY_COMPLETE` | 3513 | [Core 6.0, Vol 4, Part E, §7.7.65.8] |
| `0x09` | `BT_HCI_EVT_LE_GENERATE_DHKEY_COMPLETE` | 3519 | [Core 6.0, Vol 4, Part E, §7.7.65.9] |
| `0x0a` | `BT_HCI_EVT_LE_ENH_CONN_COMPLETE` | 3525 | [Core 6.0, Vol 4, Part E, §7.7.65.10] |
| `0x0b` | `BT_HCI_EVT_LE_DIRECT_ADV_REPORT` | 3539 | [Core 6.0, Vol 4, Part E, §7.7.65.11] |
| `0x0c` | `BT_HCI_EVT_LE_PHY_UPDATE_COMPLETE` | 3551 | [Core 6.0, Vol 4, Part E, §7.7.65.12] |
| `0x0d` | `BT_HCI_EVT_LE_EXT_ADVERTISING_REPORT` | 3559 | [Core 6.0, Vol 4, Part E, §7.7.65.13] |
| `0x0e` | `BT_HCI_EVT_LE_PER_ADV_SYNC_ESTABLISHED` | 3599 | [Core 6.0, Vol 4, Part E, §7.7.65.14] |
| `0x0f` | `BT_HCI_EVT_LE_PER_ADVERTISING_REPORT` | 3610 | [Core 6.0, Vol 4, Part E, §7.7.65.15] |
| `0x10` | `BT_HCI_EVT_LE_PER_ADV_SYNC_LOST` | 3621 | [Core 6.0, Vol 4, Part E, §7.7.65.16] |
| `0x11` | `BT_HCI_EVT_LE_SCAN_TIMEOUT` | 3626 | [Core 6.0, Vol 4, Part E, §7.7.65.17] |
| `0x12` | `BT_HCI_EVT_LE_ADV_SET_TERMINATED` | 3628 | [Core 6.0, Vol 4, Part E, §7.7.65.18] |
| `0x14` | `BT_HCI_EVT_LE_CHAN_SEL_ALGO` | 3645 | [Core 6.0, Vol 4, Part E, §7.7.65.20] |
| `0x19` | `BT_HCI_EVT_LE_CIS_ESTABLISHED` | 3721 | [Core 6.0, Vol 4, Part E, §7.7.65.25] |
| `0x1a` | `BT_HCI_EVT_LE_CIS_REQ` | 3741 | [Core 6.0, Vol 4, Part E, §7.7.65.26] |
| `0x1b` | `BT_HCI_EVT_LE_BIG_COMPLETE` | 3756 | [Core 6.0, Vol 4, Part E, §7.7.65.27] |
| `0x1c` | `BT_HCI_EVT_LE_BIG_TERMINATE` | 3773 | [Core 6.0, Vol 4, Part E, §7.7.65.28] |
| `0x1d` | `BT_HCI_EVT_LE_BIG_SYNC_ESTABLISHED` | 3779 | [Core 6.0, Vol 4, Part E, §7.7.65.29] |
| `0x1e` | `BT_HCI_EVT_LE_BIG_SYNC_LOST` | 3794 | [Core 6.0, Vol 4, Part E, §7.7.65.30] |
| `0x1f` | `BT_HCI_EVT_LE_REQ_PEER_SCA_COMPLETE` | 3800 | [Core 6.0, Vol 4, Part E, §7.7.65.31] |
| `0x20` | `BT_HCI_EVT_LE_PATH_LOSS_THRESHOLD` | 3812 | [Core 6.0, Vol 4, Part E, §7.7.65.32] |
| `0x21` | `BT_HCI_EVT_LE_TRANSMIT_POWER_REPORT` | 3828 | [Core 6.0, Vol 4, Part E, §7.7.65.33] |
| `0x22` | `BT_HCI_EVT_LE_BIGINFO_ADV_REPORT` | 3839 | [Core 6.0, Vol 4, Part E, §7.7.65.34] |
| `0x23` | `BT_HCI_EVT_LE_SUBRATE_CHANGE` | 3862 | [Core 6.0, Vol 4, Part E, §7.7.65.35] |

Additional v2 / Channel Sounding sub-events (hex `0x24`–`0x38`) are also defined; see lines 3262–3996.

---

## Host side

This section traces how the Zephyr BLE host originates HCI commands (host→controller) and receives HCI events (controller→host). All code cited is in `subsys/bluetooth/host/hci_core.c` unless another file is noted; the analysis assumes **Combined build mode** (`CONFIG_BT=y`, local LL via `zephyr,bt-hci-ll-sw-split`).

### Command path (host → controller)

Commands leave the host through a two-step queue: the caller enqueues a `net_buf` into `bt_dev.cmd_tx_queue`, a work item drains the queue one command at a time (respecting the controller's flow-control semaphore `ncmd_sem`), and then calls `bt_send()` → `bt_hci_send()` → the registered transport driver's `send` function pointer.

Call chain example — legacy LE advertising enable ([Combined build, `CONFIG_BT=y`, `CONFIG_BT_BROADCASTER=y`]):

1. [HOST] `bt_le_adv_start()` — `subsys/bluetooth/host/adv.c:1278` — public API entry point; looks up or creates the legacy advertiser object and dispatches to `adv_start_legacy()`
2. [HOST] `adv_start_legacy()` — `subsys/bluetooth/host/adv.c:891` — fills `bt_hci_cp_le_set_adv_param`, allocates a command buffer via `bt_hci_cmd_alloc()`, calls `bt_hci_cmd_send_sync(BT_HCI_OP_LE_SET_ADV_PARAM, ...)` at line 977, then calls `bt_le_adv_set_enable(adv, true)` at line 996
3. [HOST] `bt_le_adv_set_enable()` — `subsys/bluetooth/host/adv.c:358` — dispatcher; with no extended-adv support falls through to `bt_le_adv_set_enable_legacy()`
4. [HOST] `bt_le_adv_set_enable_legacy()` — `subsys/bluetooth/host/adv.c:296` — allocates a command buffer and calls `bt_hci_cmd_send_sync(BT_HCI_OP_LE_SET_ADV_ENABLE, buf, NULL)` at line 315
5. [HOST] `bt_hci_cmd_send_sync()` — `subsys/bluetooth/host/hci_core.c:415` — initialises a local `k_sem` on the stack, stores a pointer to it in `cmd(buf)->sync`, then calls `bt_hci_cmd_send()` at line 444; suspends the calling thread on `k_sem_take(&sync_sem, HCI_CMD_TIMEOUT)` at line 481 until the command-complete event gives the semaphore
6. [HOST] `bt_hci_cmd_send()` — `subsys/bluetooth/host/hci_core.c:364` — prepends the H:4 packet-type byte (`BT_HCI_H4_CMD`) and the HCI command header, enqueues the buffer into `bt_dev.cmd_tx_queue` via `k_fifo_put()` at line 408, then calls `bt_tx_irq_raise()` at line 409 to schedule the TX processor
7. [HOST] `tx_processor()` (work handler) — `subsys/bluetooth/host/hci_core.c:5141` — runs in the system workqueue (or dedicated `bt_tx_processor` workqueue if `CONFIG_BT_TX_PROCESSOR_THREAD=y`); calls `process_pending_cmd()` at line 5153
8. [HOST] `process_pending_cmd()` — `subsys/bluetooth/host/hci_core.c:5129` — takes `bt_dev.ncmd_sem` (one outstanding command at a time) then calls `hci_core_send_cmd()` at line 5133
9. [HOST] `hci_core_send_cmd()` — `subsys/bluetooth/host/hci_core.c:3234` — dequeues the buffer from `bt_dev.cmd_tx_queue`, saves a reference in `bt_dev.sent_cmd`, calls `bt_send()` at line 3255
10. [HOST] `bt_send()` — `subsys/bluetooth/host/hci_core.c:4348` — calls `bt_hci_send(bt_dev.hci, buf)` at line 4357
11. [HCI-XPORT] `bt_hci_send()` (inline) — `include/zephyr/drivers/bluetooth.h:227` — resolves to `DEVICE_API_GET(bt_hci, dev)->send(dev, buf)`; in combined build this calls the controller's registered `send` implementation (in `subsys/bluetooth/controller/hci/hci_driver.c`)

### RX thread and event dequeue

The host does not have a dedicated RX kernel thread in recent Zephyr. Instead, incoming buffers are placed on `bt_dev.rx_queue` (a `sys_slist_t` defined at `subsys/bluetooth/host/hci_core.h:405`) and processed by the `rx_work` work item, which is submitted to either the system workqueue (`CONFIG_BT_RECV_WORKQ_SYS`) or a dedicated `bt_workq` (`CONFIG_BT_RECV_WORKQ_BT`).

- `rx_work` work item: `subsys/bluetooth/host/hci_core.c:118` (`K_WORK_DEFINE(rx_work, rx_work_handler)`)
- Dedicated BT workqueue (optional): started at `hci_core.c:4735–4739` when `CONFIG_BT_RECV_WORKQ_BT=y`; thread named `"BT RX WQ"` with priority `K_PRIO_COOP(CONFIG_BT_RX_PRIO)`
- Entry function: `rx_work_handler()` at `hci_core.c:4616`
- Dequeue call: `net_buf_slist_get(&bt_dev.rx_queue)` at `hci_core.c:4624`

The path from the controller's callback to the queue:

- Controller (or transport driver) calls `bt_hci_recv()` at `hci_core.c:4547` — this is the function registered with `bt_hci_open()` at line 4742
- `bt_hci_recv()` acquires the scheduler lock and calls `bt_recv_unsafe()` at line 4553
- `bt_recv_unsafe()` at `hci_core.c:4481` inspects the H:4 type byte; events flagged `BT_HCI_EVT_FLAG_RECV_PRIO` (e.g. `CMD_COMPLETE`, `CMD_STATUS`) are dispatched synchronously via `hci_event_prio()` at line 4526 **before** queuing; events flagged `BT_HCI_EVT_FLAG_RECV` are placed on `bt_dev.rx_queue` via `rx_queue_put()` at line 4530 and `rx_work` is submitted

### Event dispatch

Two-tier dispatch is used: a top-level function routes by event code, and for LE meta events a second function routes by subevent code.

Top-level dispatcher: `hci_event()` at `hci_core.c:3212`
- Called from `rx_work_handler()` at `hci_core.c:4645` for `BT_HCI_H4_EVT` buffers
- Pulls the `bt_hci_evt_hdr` from the buffer, then calls `handle_event(hdr->evt, buf, normal_events, ...)` at line 3229
- `handle_event()` at `hci_core.c:226` iterates the `normal_events[]` table (defined at `hci_core.c:3091`) and invokes the matching handler by event code
- Standard events: switch via `normal_events[]` table — e.g. `BT_HCI_EVT_DISCONN_COMPLETE` → `hci_disconn_complete()` (line 3149 in table), `BT_HCI_EVT_ENCRYPT_CHANGE` → `hci_encrypt_change()` (line 3153 in table)
- Priority events: a parallel path through `hci_event_prio()` at `hci_core.c:4433` dispatches against `prio_events[]` table (line 4412); `CMD_COMPLETE` and `CMD_STATUS` are handled here — `hci_cmd_complete()` at `hci_core.c:2573` gives `sync_sem` back to the blocked caller of `bt_hci_cmd_send_sync()`
- LE meta events: `BT_HCI_EVT_LE_META_EVENT` (code `0x3e`, `hci_types.h:3417`) → `hci_le_meta_event()` at `hci_core.c:3080` (registered in `normal_events[]` at line 3094) → pulls the subevent byte → `handle_event(evt->subevent, buf, meta_events, ...)` at line 3088 → dispatches via `meta_events[]` table at `hci_core.c:2896`; e.g. `BT_HCI_EVT_LE_CONN_COMPLETE` (subevent `0x01`) → `le_legacy_conn_complete()` (table entry at line 2902), `BT_HCI_EVT_LE_ADVERTISING_REPORT` (subevent `0x02`) → `bt_hci_le_adv_report()` (line 2898, gated by `CONFIG_BT_OBSERVER`)

---

## Controller side

This section traces how the Zephyr BLE controller receives HCI commands from the host (controller→inbound) and generates HCI events back to the host (controller→outbound). All code cited is in `subsys/bluetooth/controller/hci/` unless another file is noted; the analysis assumes **Combined build mode** (DTS `compatible = "zephyr,bt-hci-ll-sw-split"`, `CONFIG_BT_LL_SW_SPLIT=y`).

### Transport registration

The controller registers itself as a Zephyr `bt_hci` device via `DEVICE_API(bt_hci, hci_driver_api)` at `hci_driver.c:1067`, which populates `.open = hci_driver_open`, `.close = hci_driver_close`, `.send = hci_driver_send`. The device instance is created at `hci_driver.c:1079` via `BT_HCI_CONTROLLER_INIT(0)` (which expands to `DEVICE_DT_INST_DEFINE`), using the DTS compatible `zephyr,bt-hci-ll-sw-split`.

On boot, the host calls `bt_hci_open(bt_dev.hci, bt_hci_recv)` at `host/hci_core.c:4742`. This resolves (via `DEVICE_API_GET`) to `hci_driver_open()` on the controller side. Inside `hci_driver_open()` at `hci_driver.c:1016`, the host's `bt_hci_recv` function pointer is stored in `data->recv` — this is the upward callback used for all future event delivery from controller to host.

### Command reception and decoding

In combined build mode, commands never cross a transport wire; they arrive as `net_buf` when the host calls `bt_hci_send()`, which resolves directly to `hci_driver_send()` on the controller side. `hci_driver_send()` strips the H:4 packet-type byte and dispatches by type: `BT_HCI_H4_CMD` packets are routed to `cmd_handle()`.

Call chain (combined build, inbound commands — example: `LE_SET_ADV_ENABLE`):

1. [HOST] `bt_send()` — `subsys/bluetooth/host/hci_core.c:4348` — calls `bt_hci_send(bt_dev.hci, buf)` at line 4357
2. [HCI-XPORT] `bt_hci_send()` (inline) — `include/zephyr/drivers/bluetooth.h:227` — resolves to `DEVICE_API_GET(bt_hci, dev)->send(dev, buf)`, i.e. calls `hci_driver_send()`
3. [CTLR] `hci_driver_send()` — `subsys/bluetooth/controller/hci/hci_driver.c:959` — strips the H:4 type byte via `net_buf_pull_u8()`, then calls `cmd_handle(dev, buf)` at line 979 for `BT_HCI_H4_CMD` packets
4. [CTLR] `cmd_handle()` — `subsys/bluetooth/controller/hci/hci_driver.c:891` — calls `hci_cmd_handle(buf, &node_rx)` at line 897 to decode the command; the returned `evt` buffer is the synchronous response
5. [CTLR] `hci_cmd_handle()` — `subsys/bluetooth/controller/hci/hci.c:5814` — pulls the `bt_hci_cmd_hdr`, extracts OGF and OCF, then dispatches by OGF: for `BT_OGF_LE` calls `controller_cmd_handle(ocf, cmd, &evt, node_rx)` at line 5851
6. [CTLR] `controller_cmd_handle()` — `subsys/bluetooth/controller/hci/hci.c:4547` — switch on OCF; for `BT_OCF(BT_HCI_OP_LE_SET_ADV_ENABLE)` calls `le_set_adv_enable(cmd, evt)` at line 4623 (gated by `CONFIG_BT_BROADCASTER`)
7. [CTLR] `le_set_adv_enable()` — `subsys/bluetooth/controller/hci/hci.c:1694` — decodes the parameter and calls `ll_adv_enable(cmd->enable)` (plain build without `CONFIG_BT_CTLR_ADV_EXT`) at line 1710; on return calls `cmd_complete_status(status)` at line 1713 to build the Command Complete event
8. [CTLR] `ll_adv_enable()` — `subsys/bluetooth/controller/ll_sw/ull_adv.c:820` — ULL entry point for advertising enable/disable; schedules the advertising role via the ticker and mayfly infrastructure (Phase 2 territory; trace stops here per Phase 1 rules)

### Event generation

Synchronous command response events (e.g. `CMD_COMPLETE`) are built entirely within the command handler before returning to `cmd_handle()`. Asynchronous events (e.g. `LE_CONN_COMPLETE`) are built by ULL callbacks and injected via `recv_fifo` later.

**Synchronous path** (CMD_COMPLETE for `LE_SET_ADV_ENABLE`):

1. [CTLR] `cmd_complete_status()` — `subsys/bluetooth/controller/hci/hci.c:321` — calls `bt_hci_cmd_complete_create(_opcode, sizeof(*ccst))` (defined in `subsys/bluetooth/host/hci_common.c:35`, shared by both halves), which allocates a `net_buf` and writes the `BT_HCI_EVT_CMD_COMPLETE` header; appends the status byte
2. [CTLR] `cmd_handle()` — `subsys/bluetooth/controller/hci/hci_driver.c:902` — after `hci_cmd_handle()` returns the event buffer, calls `bt_recv_prio(dev, evt)` (when `CONFIG_BT_CTLR_RX_PRIO_STACK_SIZE` is set) or `bt_recv(dev, evt)` otherwise
3. [CTLR] `bt_recv_prio()` — `subsys/bluetooth/controller/hci/hci_driver.c:271` — checks event flags via `bt_hci_evt_get_flags()`; for `CMD_COMPLETE` (flagged `BT_HCI_EVT_FLAG_RECV_PRIO` only) calls `data->recv(dev, buf)` at line 286
4. [HOST] `bt_hci_recv()` — `subsys/bluetooth/host/hci_core.c:4547` — the stored upward callback (registered at open time); acquires scheduler lock, calls `bt_recv_unsafe()` at line 4553, which dispatches `CMD_COMPLETE` synchronously via `hci_event_prio()` → `hci_cmd_complete()` → releases `sync_sem`, unblocking the caller of `bt_hci_cmd_send_sync()`

**Thread model note:** The `recv_thread` ("BT CTLR RX", created at `hci_driver.c:1033`) handles asynchronous events by draining `recv_fifo` and calling `data->recv(dev, frag)` at line 881. When `CONFIG_BT_CTLR_RX_PRIO_STACK_SIZE` is set, a higher-priority `prio_recv_thread` ("BT CTLR RX pri", created at `hci_driver.c:1026`) handles priority events (e.g. `DISCONN_COMPLETE`) and feeds normal events into `recv_fifo` for `recv_thread` to process.

---

## Buffers

Zephyr's BLE stack uses `net_buf` pools exclusively for all packet passing at the HCI boundary; the pools are deliberately separate by direction and packet type so that a buffer shortage in one path (e.g. many incoming ACL fragments) cannot starve a different path (e.g. outgoing commands). In combined builds the host-side pool definitions are shared between the host and controller halves — the controller allocates from host-defined pools when building event responses, which is the one deliberate cross-half dependency at this layer.

### Pool summary

> **Build-mode note (combined).** All pools below are compiled into the same image. In host-only builds the controller-side pools (controller/hci/hci.c) are absent; the host-only transport driver allocates from host pools via `bt_buf_get_rx()`. In controller-only builds, `hci_raw.c` provides its own local pools (`hci_rx_pool`, `hci_cmd_pool`, `hci_acl_pool`, `hci_iso_pool`).

| Pool name | Direction | Kconfig size knob(s) | Pool `file:line` | Allocator / accessor | Notes |
|---|---|---|---|---|---|
| `hci_cmd_pool` | host → controller | `CONFIG_BT_BUF_CMD_TX_COUNT` (count); `MAX(BT_BUF_EVT_RX_SIZE, BT_BUF_CMD_TX_SIZE)` (size, from `CONFIG_BT_BUF_EVT_RX_SIZE` and `CONFIG_BT_BUF_CMD_TX_SIZE`) | `host/hci_core.c:187` | `bt_hci_cmd_alloc()` at `hci_core.c:342` → `net_buf_alloc(&hci_cmd_pool, timeout)` at `hci_core.c:346` | Buffer sized to fit both the outgoing command payload and the incoming command-complete/status event payload, so the same buffer can be recycled for the synchronous response. If `CONFIG_BT_HCI_ACL_FLOW_CONTROL=y`, the count is automatically expanded to handle concurrent `HOST_NUM_COMPLETED_PACKETS` commands. |
| `sync_evt_pool` | controller → host | `CONFIG_BT_BUF_SYNC_EVT_POOL_COUNT` (count); `SYNC_EVT_SIZE` = `BT_BUF_RESERVE + BT_HCI_EVT_HDR_SIZE + 255` (size) | `host/buf.c:77` | `bt_buf_get_evt()` at `buf.c:154` for `BT_HCI_EVT_CMD_COMPLETE`, `BT_HCI_EVT_CMD_STATUS`, `BT_HCI_EVT_NUM_COMPLETED_PACKETS` → `net_buf_alloc(&sync_evt_pool, ...)` at `buf.c:165` | A singleton-style pool for events that must be processed synchronously (no queuing). Count is usually 1 but may be increased as an optimization to allow the transport to fill buffers in parallel with `bt_recv`. |
| `discardable_pool` | controller → host | `CONFIG_BT_BUF_EVT_DISCARDABLE_COUNT` (count); `CONFIG_BT_BUF_EVT_DISCARDABLE_SIZE` (size) | `host/buf.c:79` | `bt_buf_get_evt(..., discardable=true)` at `buf.c:154` → `net_buf_alloc(&discardable_pool, ...)` at `buf.c:170` | For low-priority events the host can afford to drop under memory pressure (e.g. advertising reports). Only used when the transport driver explicitly marks a buffer discardable. |
| `evt_pool` | controller → host | `CONFIG_BT_BUF_EVT_RX_COUNT` (count); `BT_BUF_EVT_RX_SIZE` = `BT_BUF_EVT_SIZE(CONFIG_BT_BUF_EVT_RX_SIZE)` | `host/buf.c:100` | `bt_buf_get_rx(BT_BUF_EVT, ...)` at `buf.c:131` → `net_buf_alloc(&evt_pool, ...)` at `buf.c:131`; **only present when `CONFIG_BT_HCI_ACL_FLOW_CONTROL=y`** | When ACL flow control is enabled, events and ACL data use separate pools for independent flow accounting. `Destroy` callback (`evt_pool_destroy`) calls `buf_rx_freed_notify(BT_BUF_EVT)`. |
| `acl_in_pool` | controller → host | `BT_BUF_ACL_RX_COUNT_EXTRA` (`CONFIG_BT_BUF_ACL_RX_COUNT_EXTRA`, default `CONFIG_BT_MAX_CONN`) + `BT_BUF_HCI_ACL_RX_COUNT` (count); `BT_BUF_ACL_SIZE(CONFIG_BT_BUF_ACL_RX_SIZE)` (size) | `host/buf.c:96` | `bt_buf_get_rx(BT_BUF_ACL_IN, ...)` at `buf.c:133` → `net_buf_alloc(&acl_in_pool, ...)`; **only present when `CONFIG_BT_HCI_ACL_FLOW_CONTROL=y`** | One extra buffer (beyond `BT_MAX_CONN`) is required so that L2CAP reassembly can hold the first fragment per connection while still accepting a new fragment from another connection. `Destroy` callback (`acl_in_pool_destroy`) calls `bt_hci_host_num_completed_packets()` to credit the controller. |
| `hci_rx_pool` | controller → host | `BT_BUF_RX_COUNT` = `CONFIG_BT_BUF_EVT_RX_COUNT` + `MAX(BT_BUF_ACL_RX_COUNT, BT_BUF_ISO_RX_COUNT)` (count); `BT_BUF_RX_SIZE` = `MAX(BT_BUF_ACL_RX_SIZE, BT_BUF_EVT_RX_SIZE, BT_BUF_ISO_RX_SIZE)` | `host/buf.c:114` | `bt_buf_get_rx()` → `net_buf_alloc(&hci_rx_pool, ...)`; **only present when `CONFIG_BT_HCI_ACL_FLOW_CONTROL` is NOT set** | Unified pool for events AND ACL-in. Simpler but provides no independent flow control per type. Both `BT_BUF_EVT` and `BT_BUF_ACL_IN` freed callbacks are fired together in `hci_rx_pool_destroy`. |
| `acl_tx_pool` | host → controller | `CONFIG_BT_L2CAP_TX_BUF_COUNT` (count, default `CONFIG_BT_BUF_ACL_TX_COUNT`); `BT_L2CAP_BUF_SIZE(CONFIG_BT_L2CAP_TX_MTU)` (size) | `host/conn.c:111` | `net_buf_alloc(&acl_tx_pool, ...)` at `conn.c:1584` (when `pool == &acl_tx_pool`) | Upper-layer L2CAP PDU buffers. One buffer holds a full L2CAP SDU; the fragmentation layer (`fragments` pool) creates zero-copy views for HCI ACL fragments. Gated by `CONFIG_BT_CONN`. |
| `fragments` | host → controller | `CONFIG_BT_CONN_FRAG_COUNT` (count, default `CONFIG_BT_BUF_ACL_TX_COUNT`); size = 0 (zero-copy view, no data) | `host/conn.c:144` | `net_buf_alloc_len(&fragments, 0, K_NO_WAIT)` at `conn.c:175` via `get_data_frag()` at `conn.c:168` | Each fragment is a `buf_view` window into a parent `acl_tx_pool` buffer. When the fragment is freed, `frag_destroy()` at `conn.c:157` releases the parent's window lock and kicks `bt_tx_irq_raise()` to send the next fragment. |
| `iso_rx_pool` | controller → host | `CONFIG_BT_ISO_RX_BUF_COUNT` (count); `BT_ISO_SDU_BUF_SIZE(CONFIG_BT_ISO_RX_MTU)` (size) | `host/iso.c:69` | `bt_iso_get_rx()` at `iso.c:629` → `net_buf_alloc(&iso_rx_pool, ...)` at `iso.c:631`; called from `bt_buf_get_rx(BT_BUF_ISO_IN, ...)` at `buf.c:125` | Only present when `CONFIG_BT_ISO_RX=y`. ISO RX buffers carry a full SDU; no fragmentation is done by the host (the ISOAL layer in the controller reconstructs SDUs before they surface here). |
| `vs_err_tx_pool` | controller → host | 1 buffer (hard-coded); `BT_BUF_EVT_RX_SIZE` | `controller/hci/hci.c:5268` | `net_buf_alloc(&vs_err_tx_pool, K_FOREVER)` at `hci.c:5325` | Controller-side only. A single reserved buffer for fatal-error vendor-specific event reporting (`CONFIG_BT_HCI_VS_FATAL_ERROR=y`). Isolated from all other pools to guarantee availability during a crash. |

> **ISO TX note.** There is no in-kernel ISO TX pool in the normal host path. ISO TX buffers are application-owned (`net_buf` allocated from an application-defined pool), enqueued to `conn->iso.txq`, and pulled by `iso_data_pull()` at `host/iso.c:800`. In raw/controller-only builds (`hci_raw.c`) a local `hci_iso_pool` exists at `hci_raw.c:59` (`CONFIG_BT_ISO_TX_BUF_COUNT` count, `BT_ISO_SDU_BUF_SIZE(CONFIG_BT_ISO_TX_MTU)` size).

### HCI ACL fragmentation

When an L2CAP PDU is larger than the controller's HCI ACL buffer size, the host fragments it into multiple HCI ACL packets before sending. The maximum payload size for each HCI ACL fragment is bounded by `bt_dev.le.acl_mtu` (set from the controller's `LE_READ_BUFFER_SIZE` response, and in combined builds capped by `CONFIG_BT_BUF_ACL_TX_SIZE`).

**Outbound fragmentation (host → controller):**

- `conn_mtu()` at `host/conn.c:618` returns `bt_dev.le.acl_mtu` for LE connections; this is the maximum payload per HCI ACL fragment.
- `get_data_frag()` at `host/conn.c:168` allocates a zero-copy `fragments` view of at most `conn_mtu(conn)` bytes from the parent `acl_tx_pool` buffer.
- The fragmenting loop at `host/conn.c:699` computes `frag_len = MIN(conn_mtu(conn), remaining_len)` and sets the HCI Packet Boundary Flag: `BT_ACL_START_NO_FLUSH` (0b10 — "first non-automatically-flushable") for the first fragment, `BT_ACL_CONT` (0b01) for continuation fragments [Core 6.0, Vol 4, Part E, §5.4.2].
- `send_acl()` at `host/conn.c:534` prepends the `struct bt_hci_acl_hdr` (handle + boundary flag packed by `bt_acl_handle_pack()`) and the H:4 type byte, then calls `bt_send()`.

**Inbound reassembly (controller → host):**

- `hci_acl()` at `host/hci_core.c:669` receives each HCI ACL fragment from the RX work handler; it pulls the `bt_hci_acl_hdr` and extracts the boundary `flags` field.
- `bt_conn_recv()` at `host/conn.c:491` dispatches to `bt_acl_recv()` at `host/conn.c:400`.
- `bt_acl_recv()` handles reassembly: a `BT_ACL_START` fragment allocates a new `acl_in_pool` buffer stored in `conn->rx` (line 416); subsequent `BT_ACL_CONT` fragments are copied into it via `net_buf_add_mem(conn->rx, buf->data, buf->len)` at line 445.
- When the accumulated length matches the L2CAP length field in the first fragment, the reassembled L2CAP PDU is delivered to `bt_l2cap_recv()`.

**Relationship between HCI fragment size and L2CAP MTU/MPS:**

```
Application SDU (arbitrary size)
         │
         ▼ L2CAP fragmentation (if SDU > MPS)
L2CAP PDU (bounded by CONFIG_BT_L2CAP_TX_MTU = MPS)
         │
         ▼ HCI ACL fragmentation (if PDU > bt_dev.le.acl_mtu)
HCI ACL fragments (each ≤ CONFIG_BT_BUF_ACL_TX_SIZE = bt_dev.le.acl_mtu payload)
         │
         ▼ Link Layer fragmentation (if ACL frame > LL PDU size)
LL PDUs transmitted over the air
```

The HCI boundary introduces an additional fragmentation tier between L2CAP and the Link Layer. In practice, combined builds set `CONFIG_BT_BUF_ACL_TX_SIZE` large enough that no HCI-level fragmentation occurs for typical MTU sizes, and the LL handles all over-the-air segmentation.

### Cross-half dependency note

`bt_hci_cmd_complete_create()` at `subsys/bluetooth/host/hci_common.c:35` and `bt_hci_cmd_status_create()` at `hci_common.c:59` are implemented in the host half of the tree but are compiled into and called by the controller-side `hci.c` (at lines 311, 318, 326). These functions call `bt_buf_get_evt()` → `bt_buf_get_rx(BT_BUF_EVT, ...)`, which allocates from `sync_evt_pool` (for `CMD_COMPLETE`/`CMD_STATUS` events) or `evt_pool`/`hci_rx_pool` (for general events), all of which are defined in `host/buf.c`. In a combined build, the controller therefore draws from host-owned buffer pools when building synchronous command responses — there is no separate controller event pool for these common events. The only controller-exclusive pool is `vs_err_tx_pool` at `controller/hci/hci.c:5268`, which is isolated deliberately for fatal-error reporting.

---

## Open questions

- The `BT_OGF_VS` (0x3f) group is defined at line 383 but no concrete VS opcodes appear in `hci_types.h`. Vendor-specific commands are expected to be defined in board/vendor extension headers (e.g., in-tree Zephyr vs. extensions). Need to locate where in-tree VS commands are declared (if any exist at this SHA).
- Spec section numbers for the newest commands (`0x207F` `BT_HCI_OP_LE_SET_EXT_ADV_PARAM_V2`, `0x2085`–`0x20A5` range, Channel Sounding group) map to Core 6.0 Vol 4 Part E sections beyond §7.8.130. The exact section number for each needs verification against the Core 6.0 spec table of contents; placeholder citations have been used for commands beyond `0x207F`.
- The count of LE meta sub-events (`0x24`–`0x38`) includes several "v2" variants introduced in BT 5.4 and Core 6.0. These are present in the header but their spec section mapping has not been fully enumerated in this task.
- (From Task 1.2) The `rx_work` work item is submitted to either the system workqueue or a dedicated `bt_workq`; the exact choice is determined by `CONFIG_BT_RECV_WORKQ_SYS` vs `CONFIG_BT_RECV_WORKQ_BT`. Neither option is a fixed-priority dedicated thread — this means RX processing priority can be preempted by other work items on the same queue. The impact on latency-sensitive events (e.g. `LE_CONN_COMPLETE`) is mitigated by the priority path (`hci_event_prio()`) that runs synchronously in the caller's context before queuing.
- (From Task 1.2) `bt_hci_cmd_send_sync()` blocks the calling thread until `CMD_COMPLETE` or `CMD_STATUS` arrives. In combined builds the controller processes commands in the same OS context hierarchy — the interaction between the blocked caller thread, the TX processor workqueue, and the RX workqueue should be traced in Task 1.4 to confirm no deadlock is possible.
- (From Task 1.3) `bt_hci_cmd_complete_create()` and `bt_hci_evt_create()` are implemented in `subsys/bluetooth/host/hci_common.c` (lines 35 and 19 respectively) and are called from the controller-side `hci.c`. This means the controller pulls a buffer allocation function from the host half of the tree in combined builds — a subtle cross-half dependency that should be captured in Task 1.6's buffer flow analysis.
- (From Task 1.3) The controller has two receive threads: `recv_thread` ("BT CTLR RX") for normal events and, when `CONFIG_BT_CTLR_RX_PRIO_STACK_SIZE` is set, `prio_recv_thread` ("BT CTLR RX pri") for priority events. The existence and priority of `prio_recv_thread` depends on this Kconfig; the analysis should confirm which targets set it in combined builds.
- (From Task 1.3) For `CONFIG_BT_CTLR_ADV_EXT`, `le_set_adv_enable()` rejects legacy advertising commands (via `adv_cmds_legacy_check()`) and requires the use of extended advertising commands instead. The exact fallback/error behavior in combined builds when `CONFIG_BT_CTLR_ADV_EXT=y` but the host uses legacy commands needs verification in Task 1.4's sequence diagram.
