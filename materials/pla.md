# PLA — CR-10S Profile (derived from ABS intel)

**Status:** UNTESTED — derived from the tested ABS profile (`abs.md`) + PLA best practice.
First validation print: quarter-scale 3DBenchy (this session).
**Bed:** glass + glue stick · **Enclosure:** NOT needed for PLA (leave open — PLA hates heat soak)
**Slicer:** PrusaSlicer 2.x CLI on WSL · **Z datum:** handled by OctoPrint-ZShift (+0.90mm), slicer Z-offset = 0

---

## How these were derived from ABS

| Parameter | ABS (tested) | PLA (this profile) | Why it changed |
|-----------|--------------|--------------------|----------------|
| Nozzle temp | 245/240 °C | **210/205 °C** | PLA melts far cooler; >220 causes stringing/clogging |
| Bed temp | 100 °C | **60 °C** | PLA needs only mild bed heat for glass+glue |
| Bed soak | 60 s | **none** | soak was for even glass heat at 100°C; unnecessary at 60°C |
| Max fan | 15 % | **100 %** | **reversed** — PLA wants full cooling for crisp detail |
| First layers fan | 0 % (4 layers) | **0 % layer 1 only** | still want layer-1 adhesion, then cool hard |
| First layer speed | 15 mm/s | **20 mm/s** | PLA adheres easier; can go slightly faster |
| Retraction | 3 mm @ 30 | **5 mm @ 40** | ABS was reduced for brittleness; PLA bowden needs ~5mm |
| Enclosure | mandatory | **none / open** | trapped heat makes PLA soft, worsens stringing |
| M109 wait | avoided | **avoided** | PID oscillation is firmware, not material — same rule |

Kept from ABS (good regardless of material): slow first layer philosophy, gyroid infill,
glue stick on glass, no-M109 start sequence.

---

## Settings

### Temperatures
- Nozzle: **210 °C** first layer, **205 °C** after
- Bed: **60 °C** (no soak)

### Layers
- Layer height: **0.2 mm**
- First layer height: **0.28 mm** (matches ABS; first-layer Z handled by ZShift)

### Speeds (mm/s)
| Move | Speed |
|------|-------|
| First layer | 20 |
| Perimeters | 45 |
| Infill | 55 |
| Solid infill | 45 |
| Top solid infill | 30 |
| Travel | 150 |
| Bridge | 30 |

### Retraction (bowden)
- Length: **5 mm**
- Speed: **40 mm/s**
- Z-lift: 0.2 mm

### Fan
- Layer 1: **0 %**
- Layer 2+: **100 %**
- Bridges: 100 %

### Infill & walls
- Density: **15 %**, pattern **Gyroid**
- Perimeters: 3 · Top: 5 · Bottom: 4

---

## Start G-code (PLA, no M109)
See [`../gcode/start_pla.gcode`](../gcode/start_pla.gcode). Same no-M109 strategy as ABS,
retuned for 210/60 °C with no soak.

## ZShift interaction (important)
- Slicer must emit **absolute** Z (PrusaSlicer default `G90`). The ZShift plugin adds
  +0.90mm to every absolute `G0/G1 Z` → slicer Z0 lands at the real first layer.
- **Do NOT** set a slicer Z-offset — that would double-count with ZShift.
- Confirm ZShift is enabled (not safe mode) before printing — see `../docs/octoprint-safe-mode.md`.

## First-print watch list
- First layer adhesion at 60°C + glue (PLA usually sticks well).
- Stringing on the Benchy's chimney/cabin → tune retraction / lower temp to 200.
- If first layer too squished/loose, adjust the ZShift `z_offset` (not the slicer).
