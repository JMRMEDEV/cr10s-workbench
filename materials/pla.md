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

---

## v2 — Post quarter-Benchy refinements (small parts)

First test (quarter Benchy, this profile) printed **structurally successfully** — no layer
shift, recognizable geometry, good adhesion — validating the BLTouch/mesh/ZShift stack.
Fine-detail quality was limited by **cooling on tiny layers + 0.4mm nozzle resolution at
25% scale** (not a calibration fault). Refinements applied in
[`../slicer/pla_cr10s_small.ini`](../slicer/pla_cr10s_small.ini):

| Change | From | To | Reason |
|--------|------|----|--------|
| Min layer time | — | **15 s** (`slowdown_below_layer_time`) | #1 fix: tiny layers must cool before the next starts |
| Min print speed floor | — | 10 mm/s | so slowdown doesn't stall to zero |
| Nozzle temp | 210/205 | **205/200** | reduce heat buildup / sagging |
| Bed temp | 60 | 55 | sufficient for PLA + glue |
| Layer height | 0.2 | **0.12** | finer vertical detail (not 0.10 — too-short layers worsen heat soak) |
| Perimeters | 3 | **2** | small part; faster, less heat dwell |
| External perimeter speed | (45) | **20 mm/s** | crisper outer walls |
| Small perimeter speed | — | **12 mm/s** | chimney/railings definition |
| Bridge speed | 30 | 18 | window spans |
| Fan full after | layer 1 | **layer 2** | layer-1 adhesion, then cool hard |

Result: ~11 min print (up from ~5) — the extra time IS the cooling fix (min-layer-time).

### Hardware limits (can't fix in slicer)
- At 25% scale Benchy ≈ 15×7.75×12 mm. The chimney bore is ~0.75 mm — <2× a 0.4 mm
  nozzle, so some tiny features are physically unresolvable. A **0.25 mm nozzle** would
  help most for small models (bigger impact than layer height alone).
- For very small parts, printing **2+ copies spaced ~25-30 mm apart** also improves
  cooling (nozzle leaves each part to cool) — optional, needs bed_shape centering care.

### Flow
- Left at default. Blobs seen may be mild over-extrusion but unproven; fix cooling first,
  then run a flow calibration only if the hull is still rough.

---

## v3 — Cooling experiment (two parts) + PID fix

Prereq done: **hotend PID retuned** (swing 16.6°C→3.2°C, see `../calibration/pid-tuning-log.md`)
— removes temp oscillation as a confound before testing cooling.

Config: [`../slicer/pla_cr10s_small_v3.ini`](../slicer/pla_cr10s_small_v3.ini) (= v2 with
`min_print_speed = 5`, so the 15s min-layer-time can slow further).

**Finding that drove the two-part approach:** only ~5 layers (the chimney, Z≈10.5–11mm)
are "tiny" (<20 extrusion moves). Slicer slowdown alone can't give them 15s without the
nozzle stalling *on top of the chimney* (heat-soak). Printing **two Benchies 30mm apart,
layer-by-layer** lets the nozzle leave each part to cool — the right fix for those layers.

Slice: `--duplicate 2 --duplicate-distance 30` (simultaneous, not sequential).
Result: ~21m, centered on (150,150), two copies stacked along Y. No M109. ZShift active.

Success criterion (per GPT): cleaner chimney, less cabin-window distortion, less bow curl.
If v3 ≈ v2, cooling is no longer the limiter → move to flow calibration / geometry.

---

## Functional / large flat parts — profile

Config: [`../slicer/pla_cr10s_functional.ini`](../slicer/pla_cr10s_functional.ini).
For large flat covers with bosses (e.g. bottom-cover-internal, 177×252×10mm). Priorities:
**XY accuracy** (boss placement) and **no warp** — NOT the small-part cooling crawl.

- Normal speeds (big layers cool fine): outer 30, perimeter 45, infill 70 mm/s.
- 3 perimeters, 20% grid infill (not fragile, not heavy).
- **6mm brim** + 55°C bed for anti-warp on the large footprint.
- 200/205°C (post-PID-tune stable temp → consistent boss dimensions).
- Auto-placed/centered on 300×300 bed; Z auto-dropped to plate (model Z-min was −2.2).
- ZShift (+0.90) handles first-layer datum as usual; no M109.
- First boss/placement test part: ~6.5h, ~98g.

**Warp watch:** glue the FULL footprint (~175×250mm), not just center; no draft; PLA = no enclosure.
