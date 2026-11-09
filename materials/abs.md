# ABS — CR-10S Tested Profile

**Filament:** ABS 1.75mm (aged, somewhat brittle)
**Bed:** glass + glue stick · **Enclosure:** required (DIY clear plastic + PVC frame)
**Result:** Benchy v3 scored 9/10 with these settings.
**Slicer:** PrusaSlicer 2.4 (CLI `--export-gcode`)

---

## Temperatures
| | Value |
|---|---|
| Nozzle (first layer) | 245 °C |
| Nozzle (after) | 240 °C |
| Bed | 100 °C |
| Bed soak | 60 s (even glass heating) |

## Layers
| | Value |
|---|---|
| Layer height | 0.2 mm |
| First layer height | 0.28 mm |

## Speeds (mm/s)
| Move | Speed |
|---|---|
| First layer | 15 (very slow — critical for ABS adhesion) |
| Perimeters | 40 |
| Infill | 50 |
| Solid infill | 40 |
| Top solid infill | 30 |
| Travel | 150 |
| Bridge | 25 |

## Retraction (reduced for brittle ABS)
| | Value |
|---|---|
| Length | 3 mm |
| Speed | 30 mm/s |
| Deretract | 20 mm/s |
| Z-lift | 0.2 mm |

## Fan
| | Value |
|---|---|
| First 4 layers | 0 % |
| Max fan | 15 % |
| Bridge fan | 25 % |

## Infill & walls
| | Value |
|---|---|
| Infill density | 15 % |
| Infill pattern | Gyroid |
| Perimeters | 3 |
| Top layers | 5 |
| Bottom layers | 4 |

## Z-offset
`M851 Z-4.85` (BLTouch). See improvements below — consider `-4.80`.

## Start G-code
See [`../gcode/start_abs.gcode`](../gcode/start_abs.gcode). **Key rule: no `M109`** with the
current PID tuning (it oscillates and stalls). Use `M104` + `G4` dwell instead.

---

## Failure log (so I don't repeat these)

### #1 — Filament snap at ~45%
- `M109 S245` stalled **2h 18min**: PID tune (Kp 18.84 / Ki 2.56 / Kd 34.73) oscillated ±10 °C,
  so the "stable within 2 °C for 9 s" wait never completed.
- Aged/brittle ABS snapped; extruder kept spinning on nothing.
- Retraction too aggressive (was 5 mm @ 45 mm/s).

### #2 — No adhesion
- Start gcode used `M190 R90` → bed only reached 90 °C. ABS on glass needs full **100 °C**.
- No bed soak; glass needs time to spread heat evenly.
- Nozzle dwell too short during prime.

## Lessons
1. **Never `M109` with this PID tune** — use `M104` + `G4` delay.
2. **ABS on glass = full 100 °C + 60 s soak.** Don't cut corners.
3. **Reduce retraction for old/brittle ABS** — 3 mm max, 30 mm/s.
4. **Very slow first layer (15 mm/s).**
5. **Glue stick on glass — reapply between prints.**
6. **Enclosure mandatory** to prevent warping on taller parts.
7. PID may need a re-tune: `M303 S240 C10`.

## Next-print improvements to try
- Z-offset `-4.80` (−4.85 squishes first layer slightly too much).
- Bottom layers 5–6 for better hull coverage.
- Bridge fan 35 % for angled bottom sections.
- Dry filament 60–70 °C for 4–6 h to reduce brittleness.

---

## Hardware notes
- BLTouch: deploy/stow/trigger all tested OK.
- Thermistor screw was loose after PTFE tube swap — retightened.
- PSU must be physically on (USB from Pi powers firmware only, not motors/heaters).
- Y endstop physically loose but electrically functional.
- USB camera (XIFT 4K) in enclosure, streamed via mjpg_streamer (640×480 @10fps).
