# Hotend PID Tuning Log — CR-10S

## 2026-11-08 — PID autotune (fix temperature oscillation)

### Why
During the v2 quarter-Benchy print, measured nozzle temperature at the 200 °C target
showed a **16.6 °C swing (±8.2 °C)** — sampled from 311 serial temperature reports.
This is the same poorly-tuned loop that caused the original `M109` 2h18m stall (see
`../materials/abs.md` failure #1) and contributes to variable flow / blobs on prints.

### Old PID (stock)
```
M301 P18.84 I2.56 D34.73
```
High Ki + low Kd → integral windup + under-damped → oscillation.

### Autotune
```
M303 E0 S200 C8 U1      # 8 cycles at 200 °C (print temp), nozzle heats in place, no motion
```
Result: `Ku: 30.85  Tu: 22.61` → Classic PID:
```
Kp: 18.51  Ki: 1.64  Kd: 52.32
```
Applied + saved:
```
M301 P18.51 I1.64 D52.32
M500                     # echo:Settings Stored (498 bytes; crc 32452)
```

### Verification — measured steady-state swing at 200 °C
| | Swing | Max dev | Mean |
|---|-------|---------|------|
| Old PID (during v2 print) | 16.6 °C | ±8.2 °C | — |
| **New PID (steady-state, 32 samples)** | **3.2 °C** | **±1.9 °C** | **200.05 °C** |

**~5× reduction in oscillation.** Mean on target. Saved to EEPROM (persists).

### Impact / next steps
- Expect more consistent extrusion on the next print (less flow variation from temp swing).
- This unblocks clean cooling/flow experiments (temp no longer a confound).
- Bed PID (`M303 E-1`) not tuned — bed held ±0.x °C, not a concern.
