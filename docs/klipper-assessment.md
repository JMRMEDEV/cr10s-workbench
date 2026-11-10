# Klipper Computation Assessment — CR-10S (ATmega2560) + Raspberry Pi 3

Measured from `~/printer_data/logs/klippy.log` per-second `Stats` lines during the first
successful Klipper print (half-scale 3DBenchy, PLA, 2026-11-09 21:30–22:02).

## Why this was measured
Under stock Creality Marlin, the 8-bit board could only process **~120 G-code commands/min**
on dense geometry. The bottom-cover part (114,599 G1 commands) flooded `echo:busy: processing`
and an estimated 6.5 h print projected to **16 h+** (OctoPrint showed "4 days"). Klipper moves
motion planning to the Pi; this checks that the board and the Pi now have headroom.

## Results (31.4 min window, 1,881 one-second samples)

| Metric | Value | Meaning |
|--------|-------|---------|
| G-code streamed | **37,550 lines / 29,031 moves** (912 KB) in ~28 min of printing | ≈ **1,530 lines/min**, vs Marlin ceiling ~120/min (**~12×**) — and Klipper was not the limit |
| Sliced vs actual time | 24.5 min est. → ~28 min actual | normal estimate error (real accel limits). Marlin: 6.5 h → 16 h+ |
| MCU load (`mcu_awake`) | avg **6.4 %**, max **12.9 %** | ATmega2560 is mostly idle — ~8× headroom |
| MCU task time | avg 0.25 ms, max 0.31 ms | consistent, no long tasks |
| Host Klipper CPU (Pi 3) | **4.7 %** of one core; sysload avg 0.35, max 1.16 | Pi has plenty of capacity (OctoPrint + 4K webcam also running) |
| Free memory (Pi) | min **603 MB** | no memory pressure |
| Move buffer (`buffer_time`) | avg 1.06 s, max 7.4 s | queue kept ahead of the motors |
| `print_stall` | **1** in the whole print | a single brief buffer underrun; no visible effect |
| Serial errors | **0** retransmits, **0** invalid bytes | USB link (FTDI) clean |
| Round-trip latency | 10.6 ms avg, 14 ms max | healthy |
| MCU clock | 16,000,205–16,000,253 Hz | stable crystal (±3 ppm) |

## Conclusion
- The command-density bottleneck is **gone**. Dense geometry (gap fill, fine perimeters) no longer
  needs the low-command workaround profile (`slicer/pla_cr10s_lowcmd.ini` is legacy).
- Both the board (≤13 % busy) and the Pi 3 (≤5 % CPU for Klipper) have large headroom, so speed
  and acceleration can be raised later (input shaping / pressure advance are possible next steps).
- Re-check this table if a print stutters: `print_stall` rising or `buffer_time` stuck near 0
  during motion is the sign of host-side starvation.

## How to reproduce
```bash
# on the Pi: stats lines for heated periods (extruder target 205/210)
grep '^Stats ' ~/printer_data/logs/klippy.log | grep -E 'extruder: target=(205|210)' | tail
```
Key fields: `mcu_awake` (MCU busy fraction), `buffer_time`, `print_stall`, `bytes_retransmit`,
`cputime` (host CPU seconds, diff over wall time), `memavail`, `srtt`.
