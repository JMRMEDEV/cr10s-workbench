# Stock Creality Marlin backup (pre-Klipper) — 2026-11-09

Read from the CR-10S board (Creality V2.2, ATmega2560, signature 0x1e9801) over USB via
the Arduino bootloader. Read twice; both reads byte-identical (flash + EEPROM).

| File | Content |
|------|---------|
| `marlin_flash_2026-11-09.hex` | full 256 KB flash (Marlin Creality firmware) |
| `marlin_eeprom_2026-11-09.hex` | 4 KB EEPROM (M851 Z-4.85, PID P18.51 I1.64 D52.32, mesh, M92 etc.) |

## Restore (revert from Klipper to stock Marlin)
On the Pi, with Klipper/OctoPrint stopped:
```bash
DEV=/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A10719QE-if00-port0
avrdude -c wiring -p m2560 -P $DEV -b 115200 -D -U flash:w:marlin_flash_2026-11-09.hex:i
avrdude -c wiring -p m2560 -P $DEV -b 115200 -U eeprom:w:marlin_eeprom_2026-11-09.hex:i
```
Note: the flash dump includes the bootloader region; `-D` (no chip erase) plus the bootloader's
self-protection keeps the bootloader intact when writing back via the bootloader.
