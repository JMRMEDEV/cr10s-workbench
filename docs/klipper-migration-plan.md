# CR-10S → Klipper Migration Plan

Goal: move motion planning to the Raspberry Pi 3 (Klipper) to fix BOTH problems hit with
stock Creality Marlin:
1. **8-bit board command-density stalls** (114K-cmd cover → ~120 cmd/min, 16h+). Klipper
   offloads planning to the Pi, sends scheduled steps → dense geometry prints at speed.
2. **Broken Z datum** (Creality Marlin ignores M851/M206/G92; Z0 crushes bed; needed the
   ZShift host hack). Klipper replaces that firmware → clean, working `z_offset` + live
   babystepping. **The ZShift middleware becomes unnecessary** (already uninstalled).

> BLTouch wiring is CONFIRMED GOOD (M119 open idle, M280 P0 S60 → TRIGGERED, reset→open,
> G28/G29 clean). Do NOT rewire the probe. The issue was never the wiring.

## Hardware / topology
- **Host:** Raspberry Pi 3 (Raspbian Bookworm, armv7l) — already runs OctoPrint. Klipper +
  Moonraker + Mainsail install alongside via KIAUH. OctoPrint can stay (optional).
- **Printer MCU:** Melzi board, **ATmega1284P** (NOT atmega2560 — confirmed via FTDI
  `0403:6001`). Klipper build target = `atmega1284p`, 16 MHz.
- **Flashing tool:** **Arduino Uno as ISP** (we have one + arduino-cli 1.5.0 with
  arduino:avr core). The Melzi likely has **no bootloader**, so USB flashing won't work
  until a bootloader is burned via ISP — the Uno handles this. Flash from the Pi (plug Uno
  into Pi USB) to keep toolchain + host in one place and avoid WSL2 USB passthrough issues.

## RECOVERY PATH (do this FIRST — before flashing anything)
- **Back up the current working state**: note it prints with stock Creality Marlin +
  OctoPrint + ZShift(removed). Keep the ZShift plugin source in this repo (`octoprint-zshift/`)
  so the old setup is restorable.
- **Save a Marlin recovery image**: before overwriting, read out the current flash with
  avrdude via ISP (`-U flash:r:cr10s_marlin_backup.hex:i`) so we can restore the exact
  factory firmware if Klipper doesn't pan out.
- Switching the MCU to Klipper means OctoPrint+Marlin can't drive it until Klipper is
  configured OR Marlin is reflashed. Don't start without the backup + a free evening.

## Steps
1. **Pi prep:** `sudo apt install avr-gcc avrdude dfu-util` (avr-gcc was missing).
2. **Install Klipper stack** via KIAUH (Klipper + Moonraker + Mainsail). OctoPrint stays.
3. **Build Klipper firmware:** `make menuconfig` →
   - Micro-controller: Atmega AVR
   - Processor model: **atmega1284p**
   - Clock: **16 MHz**
   - Bootloader: **No bootloader** (we flash via ISP)
   - `make` → produces `out/klipper.elf.hex`
4. **Wire Arduino Uno as ISP** to the Melzi ICSP header (MISO/MOSI/SCK/RESET/VCC/GND).
   Load the "ArduinoISP" sketch onto the Uno first.
5. **Backup factory firmware** (recovery path): avrdude read flash to .hex.
6. **Burn bootloader? Not needed** — flash Klipper directly via ISP with avrdude
   (`-c stk500v1 -p m1284p -U flash:w:klipper.elf.hex:i`). Verify fuses.
7. **Identify Klipper MCU serial** (`ls /dev/serial/by-id/*`) → put in `printer.cfg`.
8. **Write `printer.cfg`** using values we already captured from M503:
   - steps/mm: `M92 X80 Y80 Z400 E93` → rotation_distance equivalents
   - bed 300×300, Z max ~400
   - `[bltouch]` with the probe pin/control pin, x/y offset, and a **real z_offset**
   - `[bed_mesh]` for the glass
   - PID we tuned: hotend `Kp 18.51 Ki 1.64 Kd 52.32` (Klipper re-tunes, but a start point)
9. **Calibrate:** `PROBE_CALIBRATE` / paper test for z_offset (the proper fix for the
   whole saga), `BED_MESH_CALIBRATE`, `PID_CALIBRATE`.
10. **Re-slice** without the command-density workarounds — Klipper handles gap fill etc.
    fine, so we can restore quality settings and still print fast.

## What this fixes vs. keeps
- Fixes: command stalls, Z0-crush/offset, ZShift dependency, inconsistent flow margins.
- Keeps: the mechanical bed-level work, the glass+glue workflow, the PLA material intel
  (temps/speeds translate directly to Klipper).

---

## Progress log

### 2026-11-09 — Host software + firmware build (DONE, no Arduino needed yet)
- Pi 3 (Bookworm armv7l): installed `gcc-avr avr-libc avrdude binutils-avr dfu-util` + build deps.
  NOTE: Klipper's `install-debian.sh` fails on Bookworm (`python-dev` no longer exists) —
  installed `python3-dev python3-venv virtualenv` etc. manually, then built venv directly:
  `virtualenv -p python3 ~/klippy-env && pip install -r ~/klipper/scripts/klippy-requirements.txt`.
- Cloned `~/klipper` (v0.13.0-822-g282db764d), `~/moonraker`, `~/kiauh`.
- `c_helper.so` compiled OK on armv7.
- MCU firmware built: **atmega1284p @ 16 MHz, 250000 baud, no bootloader**.
  `out/klipper.elf.hex` = 123 KB hex / ~43.8 KB code (of 128 KB flash).
  Saved in repo: `klipper/firmware/klipper_atmega1284p_16mhz.hex` + `.config`.
- Klipper service NOT started yet (no printer.cfg / MCU flashed).

### Next (needs hands-on): ISP wiring + backup + flash
