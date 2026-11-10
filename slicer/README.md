# Slicer profiles (PrusaSlicer 2.4 CLI)

| Profile | Status | Use |
|---------|--------|-----|
| `pla_cr10s_klipper.ini` | **CURRENT** | PLA on Klipper — see `docs/pla-howto.md` |
| `pla_cr10s.ini` | legacy (Marlin) | original PLA profile; start G-code uses Marlin `M420`, relies on ZShift |
| `pla_cr10s_small.ini`, `pla_cr10s_small_v3.ini` | legacy (Marlin) | tiny-part cooling experiments (quarter Benchy) |
| `pla_cr10s_functional.ini` | legacy (Marlin) | large flat parts |
| `pla_cr10s_lowcmd.ini` | **obsolete** | workaround for the 8-bit Marlin command-density stall; not needed under Klipper |

Run: `prusa-slicer --export-gcode --load slicer/pla_cr10s_klipper.ini -o gcode/out/x.gcode model.stl`
(all profiles declare the 300×300 bed so parts center at 150,150).
