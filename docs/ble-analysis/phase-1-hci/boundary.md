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

## Open questions

- The `BT_OGF_VS` (0x3f) group is defined at line 383 but no concrete VS opcodes appear in `hci_types.h`. Vendor-specific commands are expected to be defined in board/vendor extension headers (e.g., in-tree Zephyr vs. extensions). Need to locate where in-tree VS commands are declared (if any exist at this SHA).
- Spec section numbers for the newest commands (`0x207F` `BT_HCI_OP_LE_SET_EXT_ADV_PARAM_V2`, `0x2085`–`0x20A5` range, Channel Sounding group) map to Core 6.0 Vol 4 Part E sections beyond §7.8.130. The exact section number for each needs verification against the Core 6.0 spec table of contents; placeholder citations have been used for commands beyond `0x207F`.
- The count of LE meta sub-events (`0x24`–`0x38`) includes several "v2" variants introduced in BT 5.4 and Core 6.0. These are present in the header but their spec section mapping has not been fully enumerated in this task.
