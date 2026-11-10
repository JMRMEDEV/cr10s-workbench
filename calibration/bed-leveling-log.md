# Bed Leveling Log — CR-10S + BLTouch

Mesh values are mm deviation from the probed reference plane (3×3 grid, G29).
Columns = X (0=left, 1=mid, 2=right). Rows = Y (0=front, 1=mid, 2=back).

---

## 2026-11-08 — Relocation recalibration (new location)

**Context:** Moved to a new location; recalibrated from scratch.
**Firmware:** Marlin Creality CR10S · EEPROM:1 · AUTOLEVEL:1 · Z_PROBE:1
**Probe offset at start:** `M851 Z-4.85`
**Probe health:** deploy/stow OK; endstop reads `open` stowed, `TRIGGERED` when pin pushed up. ✓

### Pass 0 — initial probe (before any mechanical leveling)
```
        X0      X1      X2
Y0   +0.820  +0.505  +0.195
Y1   +0.435  +0.128  -0.258
Y2   +0.213  -0.282  -0.785
```
Range: **1.605 mm** (front-left high, back-right low — large diagonal tilt).

### Pass 1 — after first full 4-corner manual level
```
        X0      X1      X2
Y0   +0.285  +0.200  +0.125
Y1   +0.100  +0.065  -0.040
Y2   +0.085  -0.093  -0.275
```
Range: **0.560 mm** (~65% flatter). Center near zero.

### Pass 2 — after fine tweak (front-left tighten, back-right loosen)
```
        X0      X1      X2
Y0   +0.010  +0.072  +0.173
Y1   +0.105  +0.068  -0.037
Y2   +0.195  -0.063  -0.318
```
Range: **0.513 mm**. Center +0.068. Residual is a slight twist (back-left high,
back-right low). Diminishing returns reached — accepted as final; BLTouch mesh
compensates this easily.

**Decision:** stop manual leveling, enable mesh (`M420 S1`) and save to EEPROM (`M500`).

### Z-offset — IMPORTANT FINDINGS

**Mechanical/firmware Z-datum is broken on this Creality build.** Confirmed by direct
step-count measurement (400 steps/mm) that NONE of the standard datum mechanisms work:

| Command | Expected | Actual on this firmware |
|---------|----------|--------------------------|
| `M851 Z` (probe offset) | shift Z0 proportionally | clamped — large changes land Z0 at mechanical zero |
| `M206 Z` (home offset)  | shift working zero | ignored (Z0 still = mechanical zero) |
| `G92 Z`  (coord reset)  | relabel current height | ignored — nozzle drives to true Z0 |

Result: after `G28`, the firmware's `Z0` sits ~0.9–1.15 mm **below** the real
first-layer height, i.e. the nozzle crushes the glass at Z0. (Likely related to the
inverted probe wiring done during assembly.) Raw absolute `G1 Z<n>` moves, however, are
honored **exactly and linearly** (verified: Z0.5→222, Z1.0→422, Z1.15→490 steps).

**Empirical sweet spot (mesh off, center):** nozzle friction on paper at commanded
**Z1.15 → step count 490** with `M851 Z-4.85`.

### Solution — OctoPrint middleware (no reflash)

Built `OctoPrint-ZShift` (see `../octoprint-zshift/`): a plugin hooking
`octoprint.comm.protocol.gcode.queuing` that adds a fixed offset to the Z of every
**absolute** `G0`/`G1` before it reaches the printer. Homing/probing (`G28`/`G29`) and
relative moves are left untouched. The slicer stays normal; the nozzle lands correctly.

**Tuning (center paper test, first-layer command `G1 Z0.28`):**

| z_offset | firmware receives | count | feel |
|----------|-------------------|-------|------|
| 1.15 | Z1.43 | 602 | too high (paper slides freely) |
| 1.00 | Z1.28 | 542 | still a touch high |
| 0.80 | Z1.08 | 462 | too low (paper won't enter) |
| 0.95 | Z1.23 | 522 | slightly high |
| **0.90** | **Z1.18** | **502** | **✓ perfect — this is the spot** |

**FINAL: `plugins.zshift.z_offset = 0.90`, enabled.** Verified in serial log
(`Send: G1 Z1.1800`) and by paper test at bed center. No firmware change, no slicer
offset needed.

### Known remaining quirk
- During `G28` Z-homing the nozzle briefly kisses the glass before lifting (firmware
  datum issue, inside firmware — plugin cannot intercept homing). Deemed acceptable
  (brief, on glass). Proper fix = reflash corrected Marlin via ISP (board is 8-bit
  Melzi / ATmega1284P, FTDI USB `0403:6001`) — a hands-on job, not done remotely.

### M851 state
- Left at firmware default `M851 Z-4.85` (not used for datum; harmless). NOT re-saved by us.

### Notes
- Bed: glass + glue stick. Thumbwheel: tighten = bed down (fix high corner),
  loosen = bed up (fix low corner).
- EMERGENCY_PARSER:0 in this firmware — M112 not parsed instantly mid-move.
- All motion performed remotely via OctoPrint/SSH with operator present at the printer.

---

## 2026-11-09 — Klipper (replaces the Marlin datum work above)
- BLTouch under Klipper: `PROBE_ACCURACY` (hot, 10 samples) range 0.0125 mm, σ 0.0037 mm.
- `z_offset`: 3.236 (cold paper, too high) → 3.641 (hot paper, too low) → **3.441** (midpoint,
  validated by a printed 50×50 single layer).
- Bed mesh 5×5 (probe area 15..250 × 20..280), cold: range **0.59 mm** (−0.219 … +0.371),
  consistent with the manual-level result above. Saved as `default`; auto-loaded and also
  loaded in the start G-code.
- The Marlin offsets/ZShift values above are historical; they do not apply under Klipper.

## 2026-11-09 22:58 — Bed mesh re-probed HOT (bed 60 °C, 5 min soak, nozzle 150 °C)
Rows = probe Y 20 (front) → 280 (back); columns = probe X 15 (left) → 250 (right).
```
COLD (16:47)                                   HOT (22:58)
-0.180 -0.075  0.075  0.218  0.371             -0.224 -0.075  0.123  0.329  0.551
-0.200 -0.071  0.060  0.184  0.280             -0.213 -0.068  0.073  0.224  0.344
-0.096 -0.049  0.003  0.071  0.168             -0.136 -0.074 -0.016  0.091  0.243
 0.020  0.041  0.020  0.008 -0.015             -0.018  0.009  0.016  0.039  0.045
 0.024 -0.046 -0.115 -0.180 -0.219             -0.023 -0.068 -0.123 -0.165 -0.164
range 0.59 mm                                   range 0.775 mm
```
Biggest change: **front-right rises ~0.18 mm** when hot (0.371 → 0.551); right column +0.05–0.18 mm,
center unchanged. That is most of a 0.24 mm first layer, so large parts must use the hot mesh.
Saved as `default` (replaces the cold mesh). Re-probe hot if the bed/glass is reseated.
