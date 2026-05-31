# Zephyr BLE Analysis — Phase 1: HCI Transport Drivers

Revision: c2dc4ea037a6c1c0dce37d44949b066face27bea

---

## Overview

Zephyr selects an HCI transport driver at build time through the `zephyr,bt-hci` devicetree chosen node: the application DTS names a node whose `compatible` property binds it to a specific driver. Each driver implements the `bt_hci` device API (`struct bt_hci_driver_api` — fields `open`, `send`, `close`, and optional `setup`) and registers itself via `DEVICE_DT_INST_DEFINE`. The host calls `bt_hci_open(bt_dev.hci, bt_hci_recv)` once at `bt_enable()` time; after that, the driver pushes received frames up by calling the `recv` callback it was given. In combined build mode (host + controller in one image), the transport layer is the in-tree software controller registered in `subsys/bluetooth/controller/hci/hci_driver.c` — the physical transport drivers in `drivers/bluetooth/hci/` are not in the call path at all.

---

## Driver table

| Transport | Kconfig symbol | DT compatible | Framing | Source file | `send()` function | Registration call | Notes |
|---|---|---|---|---|---|---|---|
| H4 UART | `CONFIG_BT_H4` (Kconfig:13) | `zephyr,bt-hci-uart` | H4: 1-byte type prefix (0x01 cmd / 0x02 ACL / 0x04 evt / 0x05 ISO) [Core 6.0, Vol 4, Part A] | `drivers/bluetooth/hci/h4.c` | `h4_send` (h4.c:485) | `DEVICE_DT_INST_DEFINE` (h4.c:630) | Interrupt-driven UART; spawns dedicated `bt_rx_thread`; HW flow control required |
| H5 UART | `CONFIG_BT_H5` (Kconfig:22) | `zephyr,bt-hci-3wire-uart` | H5: SLIP-framed, 4-byte header, seq+ack, CRC optional [Core 6.0, Vol 4, Part A] | `drivers/bluetooth/hci/h5.c` | `h5_queue` (h5.c:598) | `DEVICE_DT_INST_DEFINE` (h5.c:806) | EXPERIMENTAL; link state machine with retransmissions; survives UART glitches at complexity cost |
| SPI (Zephyr generic) | `CONFIG_BT_SPI_ZEPHYR` (Kconfig:94) | `zephyr,bt-hci-spi` | H4-over-SPI: IRQ line signals controller readiness; half-duplex SPI transaction carries H4 packet | `drivers/bluetooth/hci/spi.c` | `bt_spi_send` (spi.c:302) | `DEVICE_DT_INST_DEFINE` (spi.c:443) | Targets controllers running Zephyr firmware |
| SPI (ST BlueNRG) | `CONFIG_BT_SPI_BLUENRG` (Kconfig:103) | `st,hci-spi-v1` or `st,hci-spi-v2` | H4-over-SPI; ST vendor framing on top | `drivers/bluetooth/hci/hci_spi_st.c` | `bt_spi_send` (hci_spi_st.c:722) | `DEVICE_DT_INST_DEFINE` (hci_spi_st.c:752) | Dual-compat (v1/v2); optional `BT_BLUENRG_ACI` for public address |
| IPC (nRF53xx) | `CONFIG_BT_HCI_IPC` (Kconfig:32) | `zephyr,bt-hci-ipc` | Raw HCI bytes over `ipc_service` memory channel; no on-wire framing | `drivers/bluetooth/hci/ipc.c` | `bt_ipc_send` (ipc.c:263) | `DEVICE_DT_INST_DEFINE` (ipc.c:403) | nRF5340 split-core (app core + net core); requires `IPC_SERVICE` + `MBOX`; enables `BT_HAS_HCI_VS` |
| User channel (native_sim) | `CONFIG_BT_USERCHAN` (Kconfig:154) | `zephyr,bt-hci-userchan` | H4 over Linux `AF_BLUETOOTH` / `BTPROTO_HCI` user-channel socket | `drivers/bluetooth/hci/userchan.c` | `uc_send` (userchan.c:343) | `DEVICE_DT_INST_DEFINE` (userchan.c:441) | `native_sim`/`native_sim//64` only; adapter must be down; uses `NATIVE_USE_NSI_ERRNO` |
| Combined / in-tree LL | `CONFIG_BT_LL_SW_SPLIT` (controller Kconfig) | `zephyr,bt-hci-ll-sw-split` | In-process function calls; no wire framing | `subsys/bluetooth/controller/hci/hci_driver.c` | `hci_driver_send` (hci_driver.c:959) | `BT_HCI_CONTROLLER_INIT(0)` → `DEVICE_DT_INST_DEFINE` (hci_driver.c:1073-1079) | Used in combined builds (nRF5x etc.); drivers in `drivers/bluetooth/hci/` are inactive |

### Additional vendor-specific drivers (not in primary analysis scope)

| Driver | Kconfig | DT compatible | Source file | send() | Registration |
|---|---|---|---|---|---|
| STM32WB IPM | `CONFIG_BT_STM32_IPM` (Kconfig:120) | `st,stm32wb-rf` | `ipm_stm32wb.c` | `bt_ipm_send` (line 702) | `DEVICE_DT_INST_DEFINE` (line 723) |
| STM32WBA | `CONFIG_BT_STM32WBA` (Kconfig:130) | `st,hci-stm32wba` | `hci_stm32wba.c` | `bt_hci_stm32wba_send` (line 622) | `DEVICE_DT_INST_DEFINE` (line 629) |
| STM32WB0 | `CONFIG_BT_STM32WB0` (Kconfig:140) | `st,hci-stm32wb0` | `hci_stm32wb0.c` | `bt_hci_stm32wb0_send` (line 574) | `DEVICE_DT_INST_DEFINE` (line 581) |
| ESP32 | `CONFIG_BT_ESP32` (Kconfig:167) | `espressif,esp32-bt-hci` | `hci_esp32.c` | `bt_esp32_send` (line 860) | `DEVICE_DT_INST_DEFINE` (line 866) |
| NXP (UART/H4) | `CONFIG_BT_NXP` (Kconfig:213) | `nxp,hci-ble` | `hci_nxp.c` | `bt_nxp_send` (line 637) | `DEVICE_DT_INST_DEFINE` (line 661) |
| Infineon CYW208XX | `CONFIG_BT_CYW208XX` (Kconfig:223) | `infineon,cyw208xx-hci` | `hci_infineon_cyw208xx.c` | `cyw208xx_send` (line 375) | `DEVICE_DT_INST_DEFINE` (line 551) |
| Ambiq Apollo SPI | `CONFIG_BT_AMBIQ_HCI` (Kconfig:230) | `ambiq,bt-hci-spi` | `hci_ambiq.c` | `bt_apollo_send` (line 419) | `DEVICE_DT_INST_DEFINE` (line 446) |
| Renesas DA1469x | `CONFIG_BT_DA1469X` (Kconfig:205) | `renesas,bt-hci-da1469x` | `hci_da1469x.c` | `bt_da1469x_send` (line 481) | `DEVICE_DT_INST_DEFINE` (line 501) |
| Realtek Bee | n/a (DT-gated) | `realtek,bee-bt-hci` | `hci_bee.c` | `bt_hci_bee_send` (line 292) | `DEVICE_DT_INST_DEFINE` (line 298) |
| SiFli SF32LB | `CONFIG_BT_SF32LB` (Kconfig:373) | `sifli,sf32lb-mailbox` | `hci_sf32lb.c` | (IPC mailbox) | (IPC mailbox) |

---

## Per-driver notes

### H4 UART (`h4.c`)

H4 is the predominant physical transport defined in [Core 6.0, Vol 4, Part A, §2]. The first byte on the wire is the HCI packet indicator (type byte): `0x01` = HCI Command, `0x02` = ACL data, `0x03` = SCO/voice (BR/EDR), `0x04` = HCI Event, `0x05` = ISO data. No checksums, no acknowledgments — the UART hardware flow control (CTS/RTS) provides the only backpressure.

The driver is interrupt-driven. `bt_uart_isr` (h4.c:470) fires on both TX-ready and RX-ready UART interrupts. On the RX path, the ISR reads the type byte and header into `h4_data.rx`, then defers full-packet delivery to a dedicated `rx_thread` (spawned in `h4_open`, h4.c:539). The thread calls `h4->recv(dev, buf)` (h4.c:274), which is the `bt_hci_recv_t` callback registered by the host during `h4_open`.

The `send()` path (h4_send, h4.c:485) enqueues the `net_buf` to `h4->tx.fifo` and enables the UART TX interrupt, which drains the buffer in `process_tx` (h4.c:415).

Kconfig dependency: `DT_HAS_ZEPHYR_BT_HCI_UART_ENABLED` — the driver is only compiled when the DTS contains a `zephyr,bt-hci-uart` node with `status = "okay"`.

`hci_da1453x.c` (59 lines) is a thin vendor extension: it overrides the weak `bt_hci_transport_setup()` hook that `h4_open` calls, adding GPIO reset sequencing for Renesas DA1453x-based modules. The actual HCI driver remains `h4.c`.

### H5 UART (`h5.c`)

H5 (Three-Wire UART) is defined in [Core 6.0, Vol 4, Part A, §3]. The framing uses SLIP encoding (delimiter byte `0xC0`, escape byte `0xDB`) around a 4-byte H5 header that carries: 3-bit sequence number, 3-bit acknowledgment number, CRC-present flag, reliability flag, 4-bit packet type, and 12-bit payload length. Reliable packets (commands, ACL, events) require acknowledgment; unreliable packets (link control) do not.

The driver implements a link-state machine (UNINITIALIZED → INITIALIZED → ACTIVE) and uses two delayed work items for ACK timeout and retransmission timeout (both set to 250 ms). This complexity is the primary cost over H4.

Marked `EXPERIMENTAL` in Kconfig (line 25: `select EXPERIMENTAL`).

### SPI — Generic Zephyr (`spi.c`)

Targets controllers running Zephyr firmware. An IRQ GPIO line from the controller to the host signals that the controller has data to send. The host then initiates a half-duplex SPI read transaction. The `send()` path (`bt_spi_send`, spi.c:302) drives the SPI write transaction. The framing carries an H4-compatible packet with a length prefix negotiated at initialization.

Init priority is configurable via `CONFIG_BT_SPI_INIT_PRIORITY` (default 75). Boot timeout for the controller's `EVT_BLUE_INITIALIZED` vendor event is set by `CONFIG_BT_SPI_BOOT_TIMEOUT_SEC` (default 30 s).

### SPI — ST BlueNRG (`hci_spi_st.c`)

Supports two ST SPI protocol versions via dual `DT_DRV_COMPAT` definitions at lines 11 and 14. The `BT_BLUENRG_ACI` option enables ACI (Application Controller Interface) message support for BlueNRG-MS devices, and selects `BT_HCI_SET_PUBLIC_ADDR` so the host can configure the public BD_ADDR via a vendor HCI command during `setup()`.

### IPC (`ipc.c`)

Used on nRF5340 targets (split-image: host on application core, controller on network core). The `ipc_service` subsystem and a `MBOX` device provide the inter-core channel. HCI bytes flow raw over the IPC channel — no H4 type byte prefix is added because both sides share a common message boundary. The Kconfig entry (`BT_HCI_IPC`) automatically selects `BT_HAS_HCI_VS` because the Zephyr open-source controller on the network core supports vendor-specific extensions.

`CONFIG_BT_HCI_IPC_SEND_RETRY_COUNT` (default 3) and `CONFIG_BT_HCI_IPC_SEND_RETRY_DELAY_US` (default 75 µs) govern retry behavior when `ipc_service_send` returns `-ENOMEM`.

The `BT_DRIVER_QUIRK_NO_AUTO_DLE` quirk (Kconfig:281) defaults to `y` when `BT_HCI_IPC` is set, because the Zephyr open-source controller does not auto-initiate Data Length Update for new connections.

### User Channel (`userchan.c`)

The user channel is a Linux kernel mechanism that allows a userspace process to open an `AF_BLUETOOTH` socket with `BTPROTO_HCI` in `HCI_CHANNEL_USER` mode, bypassing BlueZ and taking exclusive control of a real HCI adapter. Zephyr's `native_sim` board uses this to run the full Zephyr BLE stack on top of a Linux host adapter — useful for protocol testing without physical hardware.

Kconfig constraint: `depends on BOARD_NATIVE_SIM` (line 156). The adapter must be administratively down before Zephyr takes over. The driver registers `userchan_bottom.c` helpers for the low-level socket I/O.

---

## Combined-build "driver" (`subsys/bluetooth/controller/hci/hci_driver.c`)

In a combined build (host + in-tree software controller in one image), this file registers as the sole `bt_hci` device. It uses the DT compatible `zephyr,bt-hci-ll-sw-split` (hci_driver.c:69).

Registration macro:

```c
// hci_driver.c:1073-1079
#define BT_HCI_CONTROLLER_INIT(inst) \
    static struct hci_data data_##inst; \
    DEVICE_DT_INST_DEFINE(inst, NULL, NULL, &data_##inst, NULL, POST_KERNEL, \
                          CONFIG_KERNEL_INIT_PRIORITY_DEVICE, &hci_driver_api)

BT_HCI_CONTROLLER_INIT(0)
```

The `bt_hci` API struct:

```c
// hci_driver.c:1067-1072
static DEVICE_API(bt_hci, hci_driver_api) = {
    .open  = hci_driver_open,
    .send  = hci_driver_send,
    .close = hci_driver_close,
};
```

`hci_driver_send` (hci_driver.c:959) receives a `net_buf` from the host, classifies it as Command, ACL, or ISO, and passes it into the controller LL via `ll_*` API calls — bypassing any physical transport entirely. The HCI boundary here is purely logical (an in-process function call), not a physical wire.

In this mode, physical drivers in `drivers/bluetooth/hci/` are inactive — their DTS nodes are absent, so their `DT_HAS_*_ENABLED` Kconfig guards evaluate false and their source files compile out.

---

## Open questions

1. `hci_nxp_setup.c` exists in the directory but has no `DEVICE_DT_INST_DEFINE` of its own — it appears to provide supplemental initialization for `hci_nxp.c`. The exact split of responsibility between the two files has not been verified.

2. `nrf53_support.c` appears to provide supplemental nRF53 multi-image support beyond `ipc.c`. Its role relative to `ipc.c` in combined vs. split nRF5340 builds should be confirmed before claiming `ipc.c` is the sole IPC driver entry point.

3. The `BT_SF32LB` driver (`hci_sf32lb.c`) uses SiFli-specific IPC mailbox infrastructure (`USE_SIFLI_IPC_QUEUE`, `USE_SIFLI_HAL`). Its `send()` entry point and DEVICE_DT_INST_DEFINE line have not been verified — it was not part of the primary five-driver scope but is listed in the vendor table for completeness.
