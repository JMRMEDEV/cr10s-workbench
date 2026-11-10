# PLA How-To — this CR-10S (Klipper + OctoPrint + BLTouch, glass + glue)

The working procedure as of 2026-11-09. Validated by a single-layer 50×50 mm test
("best PLA layer ever with this printer") and a near-perfect half-scale 3DBenchy.

## The setup this applies to
- CR-10S, Creality V2.2 board (ATmega2560), **Klipper** firmware; host = Raspberry Pi 3
  running Klipper + OctoPrint (OctoPrint talks to Klipper on `/tmp/printer` @ 250000).
- BLTouch (pin-27 adapter → `control_pin PB5`, Z-min → `sensor_pin ^PD3`), offsets x −42 / y −6.
- **`z_offset = 3.441`** (saved in `printer.cfg` auto block), 5×5 bed mesh `default` (auto-loaded).
- Glass bed + glue stick. No enclosure for PLA. 0.4 mm nozzle, 1.75 mm PLA.
- Slicer: PrusaSlicer CLI with **`slicer/pla_cr10s_klipper.ini`** (the only current PLA profile).

## Settings (pla_cr10s_klipper.ini)
| Setting | Value | Why |
|---------|-------|-----|
| Nozzle | 210 °C first layer, 205 °C after | PLA range; PID holds ±0.9 °C |
| Bed | **65 °C first layer, 60 °C after** | glass surface runs cooler than the sensor; 55 °C let parts lift |
| Layers | 0.24 mm first, 0.2 mm after | |
| Walls / infill | 3 perimeters, 15 % gyroid, 5 top / 4 bottom | |
| Gap fill | **on** | fine under Klipper (no command-density stall) |
| Part fan | **off layers 1–3, 50 % at 4, 100 % from 5** | early full fan shrank the base and popped it off the glass |
| Brim | **5 mm** | small footprints need the extra grip |
| First-layer squish | `SET_GCODE_OFFSET Z=-0.025` in start G-code | slightly stronger bond |
| Speeds | first layer 20, perimeters 45, infill 55, travel 150 mm/s | |
| Retraction | 5 mm @ 40 mm/s, 0.2 mm lift | bowden |
| Machine limits | `machine_limits_usage = ignore` | Klipper owns limits; avoids M201/M203/M205 noise |

Start G-code (Klipper): `M140/M104 → G28 → BED_MESH_PROFILE LOAD=default → SET_GCODE_OFFSET Z=-0.025
→ M190 → M109 → prime line X5 Y20→Y120`. Standard `M109`/`M190` waits are fine now (good PID).

## Step by step
1. **Bed prep.** Raise the nozzle out of the way (unhomed is fine):
   `./scripts/octo.sh gcode "FORCE_MOVE STEPPER=stepper_z DISTANCE=150 VELOCITY=8"`.
   Remove old parts, clean glue residue with warm water, finish with IPA, re-glue the
   footprint area (+ brim margin). PLA loaded.
2. **Slice.**
   ```bash
   prusa-slicer --export-gcode --load slicer/pla_cr10s_klipper.ini [--scale 0.5] \
     -o gcode/out/<part>.gcode <model>.stl
   ```
   PrusaSlicer auto-centers on (150,150). Check the model fits and is oriented flat-face-down.
3. **Upload + start.** `./scripts/octo.sh upload gcode/out/<part>.gcode` then
   `./scripts/octo.sh print <part>.gcode`. Bed to 65 °C takes ~4 min from cold.
4. **Watch the first layer + brim.** Live adjust if needed (persists until restart):
   `SET_GCODE_OFFSET Z_ADJUST=-0.025 MOVE=1` (more squish) / `+0.025` (less).
   To make an adjustment permanent: `Z_OFFSET_APPLY_PROBE` then `SAVE_CONFIG`.
5. **Watch layers ~5–15** (where earlier prints let go). Lifting brim/corners → cancel early.
6. Cancel: `./scripts/octo.sh cancel` (OctoPrint's cancel turns motors off → printer becomes
   unhomed; use `FORCE_MOVE` or `G28` before moving).

## Findings & mitigations (chronological)
| # | Symptom | Root cause | Mitigation |
|---|---------|-----------|-----------|
| 1 | Under Marlin: Z0 crushed the bed; M851/M206/G92 ignored | Creality Marlin build didn't apply probe/home offsets | moved to Klipper (proper `z_offset`); ZShift host workaround retired |
| 2 | Under Marlin: 6.5 h print → 16 h+ | 8-bit board ~120 cmd/min on dense G-code | Klipper (≈1,530 lines/min streamed, MCU ≤13 % busy) — see `docs/klipper-assessment.md` |
| 3 | First Klipper print: plastic never touched glass | cold paper test (z_offset 3.236) ~0.2 mm high | hot recalibration + printed single-layer test |
| 4 | Next: nozzle plowed early layers | hot paper test with "pressure" (3.641) ~0.2 mm low | midpoint **3.441** via `SET_GCODE_OFFSET` + `Z_OFFSET_APPLY_PROBE`; single-layer test confirmed |
| 5 | Half Benchy came loose after ~10 layers | weak grip: 55 °C bed, full fan from layer 2, small footprint, no brim | bed 65/60, fan delayed to layer 4–5, 5 mm brim, −0.025 squish → **near-perfect print** |
| 6 | Bottom layer slightly "melted" (elephant foot) — acceptable for laptop case | extra squish (−0.025) + 65 °C first-layer bed | if dimensions matter: set `elefant_foot_compensation = 0.15` in the profile, and/or drop the squish to 0 or the first-layer bed to 62 °C (change one at a time) |

**Rule learned:** paper feel is only good to ±0.2 mm here — finalize Z with a printed
single-layer test (`stl/first_layer_50mm.stl`) and live `SET_GCODE_OFFSET`.

## Known minor items
- OctoPrint's cancel sends Marlin `M108` → Klipper logs `Unknown command "M108"` (harmless).
- After `SAVE_CONFIG` / `RESTART` / cancel the printer is unhomed — always `G28` before `G1`.
- Bed mesh was probed cold; re-run `BED_MESH_CALIBRATE` with the bed at 60–65 °C, then `SAVE_CONFIG`,
  for best accuracy on large parts.
