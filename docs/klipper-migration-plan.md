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

### 2026-11-09 — MCU IDENTIFICATION CORRECTION (important)
- **Physical chip reading is authoritative: `ATMEGA2560-16AU` on a Creality V2.0 board.**
- Earlier I wrongly inferred ATmega1284P/Melzi from the FTDI USB chip — the USB-serial
  chip is INDEPENDENT of the MCU. GPT's original "ATmega2560" was correct. Lesson: identify
  the MCU by the chip marking, not the USB bridge.
- Rebuilt Klipper for **atmega2560 @ 16MHz, 250000 baud** (44.6 KB of 256 KB flash).
  Saved: `klipper/firmware/klipper_atmega2560_16mhz.hex`. Removed the wrong 1284p hex.
- **Consequence (good): Creality V2.x/2560 boards ship with an Arduino MEGA2560 bootloader
  → flash Klipper OVER USB (avrdude `-c wiring`). The Arduino Uno / ISP is NOT needed.**
  Simpler and lower-risk. Printer can be closed back up.

### Flashing plan (USB, no ISP)
1. Close printer, power on normally, USB → Pi (`/dev/ttyUSB0`).
2. Stop OctoPrint (frees the port).
3. BACKUP: `avrdude -c wiring -p m2560 -P /dev/ttyUSB0 -b 115200 -D -U flash:r:marlin_backup.hex:i`
4. FLASH:  `avrdude -c wiring -p m2560 -P /dev/ttyUSB0 -b 115200 -D -U flash:w:klipper.elf.hex:i`
   (Klipper's own `make flash FLASH_DEVICE=/dev/ttyUSB0` wraps this.)
5. printer.cfg (2560 pins = the "Creality CR-10S / melzi? NO — ramps-like 2560" generic
   mega2560 pinmap; use Klipper's `generic-cr10s` / board-specific sample as starting point).

### 2026-11-09 — printer.cfg draft (research done, not deployed)
Draft: [`../klipper/printer.cfg`](../klipper/printer.cfg). Base = Klipper official
`printer-creality-cr10s-2017.cfg` (ATmega2560 pin map) + this printer's measured M92/PID.

BLTouch wiring (confirmed by photos/Gemini read + functional tests):
- 5-wire harness → White/Black pair on **Z-min** port → `sensor_pin: ^PD3` (official 2560 Z endstop pin).
- Blue/Red/Yellow → **pin-27 adapter** under the LCD ribbon (taps the LCD beeper line) → `control_pin`.
  - "pin 27 = PA4" in most guides is for **Melzi/1284p** (Ender 3, CR-10). NOT this board.
  - On this 2560 board the LCD beeper is D37 = **PC0** (best candidate, UNVERIFIED).

**Post-flash BLTouch check (NO axis motion, before any G28):**
1. `BLTOUCH_DEBUG COMMAND=pin_down` → pin must drop. `BLTOUCH_DEBUG COMMAND=pin_up` → pin retracts.
   If nothing moves: wrong control_pin → try next candidate, `RESTART`, repeat.
2. `QUERY_PROBE` → "open" with pin up. Push pin up gently during `pin_down` + `QUERY_PROBE` → "TRIGGERED".
3. Only then: measure x/y offsets, set `safe_z_home`/`bed_mesh` limits, `G28`, `PROBE_CALIBRATE`
   (paper test) → `SAVE_CONFIG`. Then `BED_MESH_CALIBRATE`, `PID_CALIBRATE`.

Still to measure on the machine: probe x_offset / y_offset (ruler, nozzle vs pin tip).

### 2026-11-09 — control pin confirmed from source
- Board silkscreen: **Creality V2.2** (same ATmega2560 family as the official CR-10S config).
- Marlin `pins_RAMPS_CREALITY.h` (Creality 2560 boards): `BEEPER_PIN 37`; Klipper arduino-mega
  alias `ar37 = PC0` → **BLTouch `control_pin: PC0`** (pin-27 adapter = LCD beeper line).
- Z-min: RAMPS `Z_MIN_PIN 18` = `ar18 = PD3` → `sensor_pin: ^PD3` (consistent).
- Original Z switch confirmed unplugged (photo); BLTouch pair occupies Z-min. Correct.

### 2026-11-09 — Klipper flashed + BLTouch control pin found by reverse engineering
- Klipper flashed over USB (`avrdude -c wiring`, 44,682 bytes written + verified). MCU connects
  cleanly; thermistors read room temp; OctoPrint drives Klipper via `/tmp/printer` @ 250000.
  Systemd unit written manually (`/etc/systemd/system/klipper.service`).
- First try `control_pin: PC0` → probe did nothing, **printer beeped**: PC0 is the LCD buzzer.
  (Every "pin 27 = PA4 / beeper" guide is for Melzi or doesn't apply to this board.)
- **Found the real pin by disassembling the stock Marlin backup** (`avr-objdump -m avr6`):
  - Located Arduino `digital_pin_to_port_PGM` table at flash 0x3102 → `pinMode` at 0xcec4.
  - `Servo::attach` at 0x20110 (stores 6-bit `Pin.nbr`, then `pinMode(pin, OUTPUT)`).
  - Init call at 0x223e2: `attach(servo0, pin=0x0B)` → **SERVO0_PIN = D11 = PB5**.
- With `control_pin: PB5`: pin_up→open, **touch_mode→TRIGGERED**, pin_up→open. BLTouch verified.

### 2026-11-09 — X/Y homing working
- Probe offsets measured: `x_offset -42` (probe left of nozzle), `y_offset -6` (probe toward front);
  retracted pin 3mm above nozzle, deployed pin 4.4mm below nozzle (safe).
- `safe_z_home` at nozzle (192,156) → probe at bed center; mesh 15..250 × 20..280 (probe coords).
- First `G28 X Y` failed: bed drove away from the Y switch. Detour: I wrongly inverted Y
  (`!PF7`), then verified physically: Y endstop is at the BACK, switch reads TRIGGERED on press,
  bed reaches it after ~240mm of travel. **Official `dir_pin: PF7` is correct** → reverted.
  `G28 Y`, `G28 X` → `X:0 Y:0`, no errors.
- Webcam (XIFT 4K) raised from 640x480 to 3840x2160 @5fps (`/boot/firmware/octopi.txt`);
  `scripts/snap.sh label width [crop]` grabs + downsamples/crops snapshots for visual checks.
- Added `[force_move]` for bring-up diagnostics.

### 2026-11-09 — Z offset calibrated (the original problem, solved)
- First `G28 Z` OK (probe at bed center, slow descent, no collision; camera-checked).
- `PROBE_CALIBRATE` at (150,150): probe samples agree within 0.0075mm. Paper test via TESTZ.
  Needed `position_min: -6` (probe triggers ~3.2mm above nozzle contact).
- **`z_offset = 3.236`** saved via `SAVE_CONFIG` (auto-generated block at end of printer.cfg).
- Verified: re-home → `G1 X150 Y150 Z0` → paper drag identical. **Z0 is correct in firmware;
  no ZShift middleware, no slicer offset.**

### 2026-11-09 — Bed mesh saved
- `BED_MESH_CALIBRATE` 5×5 over probe area 15..250 × 20..280 (cold bed), ~2.5 min.
- Range **0.59 mm** (min −0.219, max +0.371), avg 0.02 — consistent with last night's
  manual-level result (~0.5 mm). Saved as profile `default` via SAVE_CONFIG.
- Re-run with the bed at print temp (55–60°C PLA) for best accuracy before critical prints.

### 2026-11-09 — PID tuned under Klipper; OctoPrint error handling
- Hotend 13.824/0.912/52.358 (swing 1.7 °C), bed 57.273/3.320/246.990 (swing 0.8 °C). See pid-tuning-log.md.
- OctoPrint `serial.disconnectOnErrors: false`: a rejected command ("Must home axis first") made
  OctoPrint send M112 and drop Klipper. Klipper handles safety shutdowns itself.
- Rule: SAVE_CONFIG/RESTART clears homing → always `G28` before moving.

### 2026-11-09 — Z offset recalibrated hot: 3.236 → 3.641
- First half-Benchy: plastic never touched the glass (extruder verified OK separately) →
  first layer was printing ~0.4 mm too high. Cold paper test (3.236) was off.
- Recalibrated at temperature (bed 55 °C, nozzle 150 °C — no ooze): `PROBE_ACCURACY` 10 samples,
  range 0.0125 mm, σ 0.0037 → probe is fine. Paper spot −0.399 on the old scale →
  **`z_offset = 3.641`** (SAVE_CONFIG).
- Mistake to avoid: after a z_offset is saved, PROBE_CALIBRATE's Z scale includes it (start ≈ 5 +
  offset). I reused an absolute TESTZ target from the previous scale and drove the nozzle ~3 mm
  below the believed bed height. No damage found; re-homed (probe trigger consistent → no lost steps).
  Rule now: always read the start Z and never TESTZ below +0.5 without the user watching.

### 2026-11-09 — First layer dialed in: z_offset 3.441 ✅
- 3.236 (cold paper) → plastic never touched; 3.641 (hot paper, "pressure") → nozzle plowed layers.
- Middle ground via `SET_GCODE_OFFSET Z=0.2` + `Z_OFFSET_APPLY_PROBE` + `SAVE_CONFIG` → **3.441**.
- Validated with a 50×50×0.24 mm single-layer test (`stl/first_layer_50mm.stl`, Klipper PLA profile):
  user: "best PLA layer ever with this printer". No live adjustment needed.
- Lesson: paper feel is ±0.2 mm here; use a printed first-layer test + live SET_GCODE_OFFSET to finalize.

---

## FINAL STATUS — 2026-11-09 ✅ Migration complete
- Klipper on ATmega2560 (Creality V2.2), host Pi 3, OctoPrint via `/tmp/printer`.
- BLTouch PB5/^PD3, offsets −42/−6, **z_offset 3.441**, 5×5 mesh, PID hotend 13.824/0.912/52.358,
  bed 57.273/3.320/246.990. Y dir PF7 (official), X/Y endstops verified.
- First good print: half-scale 3DBenchy, PLA, near-perfect (slight elephant foot).
- Adhesion fixes that made it work: bed 65 °C first layer / 60 °C after, 5 mm brim, part fan
  delayed to layer 4–5, `SET_GCODE_OFFSET Z=-0.025`. Full procedure: `docs/pla-howto.md`.
- Performance: MCU ≤13 % busy, Pi Klipper CPU 4.7 %, 0 retransmits, ≈1,530 G-code lines/min
  streamed (vs ~120/min Marlin ceiling). Details: `docs/klipper-assessment.md`.
- Retired: OctoPrint-ZShift plugin, low-command slicer profile, Marlin start G-code (kept as legacy).
- Open items: re-probe mesh hot; elephant-foot compensation for dimensional parts; Klipper start
  G-code + re-test for ABS; OctoPrint cancel sends harmless Marlin `M108`; optional input shaping /
  pressure advance.
