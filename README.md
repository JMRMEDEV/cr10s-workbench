# CR-10S Workbench

A personal workbench for my **Creality CR-10S**, now running **Klipper** on a Raspberry Pi 3
(with OctoPrint as the UI). It holds how to reach the Pi, the printer firmware config,
tested slicer profiles per material, calibration logs, and lessons from failed prints.

> Printer: Creality CR-10S · Board: Creality V2.2 (ATmega2560) · Probe: BLTouch (pin-27 adapter)
> Bed: glass + glue stick · Enclosure: DIY (for ABS only)
> Host: Raspberry Pi 3 (`octopi.local`) running **Klipper + OctoPrint**, 4K USB webcam

## Current state (2026-11-09)
- **Firmware:** Klipper (MCU flashed over USB; stock Marlin backed up in `klipper/marlin_backup/`).
- **Z:** BLTouch `z_offset = 3.441`, 5×5 bed mesh — first layer validated by a printed test.
- **PID:** hotend ±0.9 °C, bed ±0.4 °C at target.
- **PLA:** working profile + procedure → [docs/pla-howto.md](docs/pla-howto.md).
- **Performance:** dense G-code no longer stalls → [docs/klipper-assessment.md](docs/klipper-assessment.md).
- The old Marlin-era **ZShift** OctoPrint plugin is **retired** (uninstalled; kept for history).

## Layout
```
cr10s-workbench/
├── README.md
├── .env.example                 # credential/host template (real .env is gitignored)
├── docs/
│   ├── pla-howto.md             # START HERE for PLA: settings, steps, findings & mitigations
│   ├── klipper-migration-plan.md# full Marlin → Klipper log (pins, flashing, calibration)
│   ├── klipper-assessment.md    # MCU/host load, throughput vs Marlin
│   ├── connecting-to-pi.md      # IP discovery, SSH, OctoPrint API, Klipper service, webcam
│   └── octoprint-safe-mode.md   # safe-mode triggers & prevention
├── klipper/
│   ├── printer.cfg              # live Klipper config (pins, BLTouch, mesh, PID — SAVE_CONFIG block)
│   ├── firmware/                # Klipper MCU build (atmega2560) + .config
│   └── marlin_backup/           # stock Marlin flash + EEPROM, restore instructions
├── slicer/
│   ├── pla_cr10s_klipper.ini    # CURRENT PLA profile (Klipper)
│   └── README.md                # which profiles are current vs legacy
├── materials/                   # material notes (abs.md, pla.md history)
├── calibration/                 # bed leveling + PID logs
├── gcode/                       # start G-code snippets (Klipper + legacy Marlin)
├── stl/                         # test models (first_layer_50mm.stl; 3DBenchy is gitignored)
├── octoprint-zshift/            # RETIRED Marlin-era Z-offset middleware
└── scripts/
    ├── octo.sh                  # OctoPrint API over SSH: status/temps/gcode/upload/print/cancel
    └── snap.sh                  # webcam snapshot → downsample/crop for visual checks
```

## Credentials & safety
Secrets live in a **gitignored `.env`** (`cp .env.example .env && chmod 600 .env`).
Defaults are intentionally weak (`pi`/`raspberry`, web `admin`/`admin`) for a LAN-only device —
**change them** if the Pi is ever exposed beyond a trusted network.

## Quick start
```bash
./scripts/octo.sh ip                       # find the Pi on the current network
./scripts/octo.sh status                   # OctoPrint ↔ Klipper connection (/tmp/printer)
./scripts/octo.sh gcode "G28"              # home (BLTouch Z at bed center)
./scripts/octo.sh temps
./scripts/snap.sh look 1000                # webcam snapshot → /tmp/cam_look.jpg
```
Print PLA: follow [docs/pla-howto.md](docs/pla-howto.md).

## Materials
| Material | Profile | Status |
|----------|---------|--------|
| PLA 1.75 mm | `slicer/pla_cr10s_klipper.ini` · [how-to](docs/pla-howto.md) | ✅ Klipper — validated (half Benchy near-perfect) |
| ABS 1.75 mm | [materials/abs.md](materials/abs.md) | ⚠️ Marlin-era profile; needs a Klipper start G-code + re-test |

## Source
Early settings and lessons were distilled from the `tux-droid-2026` build notes
(`3D_PRINTING_NOTES.md`); everything since is logged in `docs/` and `calibration/`.
