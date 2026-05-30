# CLAUDE.md — `drivers/bluetooth/hci/`

HCI transport drivers. **This directory is only used when host and controller are in separate images.** Loaded when reading files here. Inherits from root `CLAUDE.md`.

## Role

```
Host (subsys/bluetooth/host/hci_core.c)
       │
       ▼ bt_dev.drv->send / drv->open
┌────────────────────────────────┐
│  THIS DIRECTORY                │
│  bt_hci_driver_api implementor │
│  per physical transport        │
└──────────────┬─────────────────┘
               │
               ▼
        Wire / IPC / Loopback
               │
               ▼
        External controller chip
```

**In combined builds, this directory is mostly bypassed.** The controller's `hci_driver.c` registers as the active `bt_hci_driver` directly, so files here are not in the call path. Phase 1 Task 1.5 surveys this directory because we want the catalogue regardless — many real products use a host-only Zephyr image with an external controller.

## Files (varies by SHA — verify with `ls`)

| File | Transport | Framing | Typical use |
|---|---|---|---|
| `h4.c` | UART | H4 (1-byte type + payload) | Most common external-controller setup |
| `h5.c` | UART | H5 (SLIP + link state machine) | When UART is unreliable / needs flow ctrl |
| `ipc.c` | nRF53 IPC service | Raw HCI bytes over IPC | nRF5340 split between app + net cores |
| `userchan.c` | AF_BLUETOOTH (Linux) | H4 over user channel | QEMU / posix testing |
| `spi.c` | SPI + IRQ line | H4-like | Some legacy + IRQ-driven controllers |
| `uart_async.c` | UART (async API) | H4 | Modern replacement for `h4.c` on async-capable UART |
| `virtual.c` | Loopback / native | Direct | Test / simulation |

Run `ls drivers/bluetooth/hci/` at the pinned SHA — the exact set evolves.

## API surface — `struct bt_hci_driver_api`

Every driver here implements a fixed-shape API (struct name and field set may vary by Zephyr version; older code uses `struct bt_hci_driver`).

Core operations:

| Op | When | Direction |
|---|---|---|
| `open` | After `bt_enable()` once transport is ready | initialization |
| `send` | Host has a command or ACL/ISO to transmit | Host → Controller |
| `setup` *(optional)* | After open, before normal operation | initialization |
| `close` *(optional)* | On `bt_disable()` | shutdown |

**Receive is async.** Drivers do not have a `recv` function called by the host. Instead, the driver internally drives an RX path (thread, callback, IRQ handler) and pushes received buffers into the host by calling `bt_recv()`. This inversion is the most-misread part of the API.

## Registration pattern

Two patterns coexist (driver-by-driver basis):

1. **Modern: devicetree-driven**
   ```c
   DEVICE_DT_INST_DEFINE(0, hci_<transport>_init, ..., &hci_<transport>_api, ...);
   ```
   The `zephyr,bt-hci` chosen node in the application's DTS selects which driver is active.

2. **Legacy: explicit register**
   ```c
   bt_hci_driver_register(&drv);
   ```
   Driver picks itself at init time based on Kconfig.

Phase 1 Task 1.5 should record both registration sites where applicable.

## Framing notes (Phase 1 needs short summaries, not deep dives)

- **H4**: First byte = type (0x01 cmd, 0x02 ACL, 0x03 SCO, 0x04 evt, 0x05 ISO). Rest = payload. No checksums, no acks.
- **H5**: SLIP-encoded H4. Adds 3-wire link state machine, ACKs, sequence numbers. Survives UART glitches; cost is significant complexity in the driver state machine.
- **IPC** (nRF53): uses `ipc_service` subsystem; raw HCI bytes flow over a memory-mapped channel between application and network cores. No on-wire framing — IPC handles framing.
- **userchan**: Linux-only test transport; uses `AF_BLUETOOTH` `BTPROTO_HCI` socket with `HCI_CHANNEL_USER`. Used by QEMU and native_sim.
- **SPI**: half-duplex command/event exchange. IRQ line tells host when controller has data; host then drives a SPI transaction. Implementations differ on framing (some use a length-prefix, some use H4-over-SPI).

## Common analysis pitfalls in this directory

1. **Drivers register similar-looking APIs with **subtly different lifecycles**.** `h4.c` blocks during open; `uart_async.c` does not. Don't claim "the driver does X" — claim "h4.c does X, uart_async.c does Y".
2. **RX inversion mentioned above.** A reader unfamiliar with the API may search for a `recv` field in the api struct and conclude RX is missing. Point to `bt_recv()` instead.
3. **DTS gating is invisible from C.** A driver may exist in source but be inactive because its DT node is not enabled. Always check whether `CONFIG_BT_HCI_<TRANSPORT>` is on AND whether the DT node is `status = "okay"`.
4. **Combined builds don't use these drivers.** In a combined build, `subsys/bluetooth/controller/hci/hci_driver.c` registers as the `bt_hci_driver` — drivers here are inactive. Be explicit about this in Task 1.5's preamble.

## Phase 1 deliverables anchored here

- Task 1.5's `transport-drivers.md` enumerates this directory in full.
- For Task 1.4 (canonical example `HCI_LE_Set_Advertising_Enable` in combined mode), this directory is **not** in the call path — controller's `hci_driver.c` plays the `bt_hci_driver` role instead. Note this in the diagram caption to avoid confusion.
