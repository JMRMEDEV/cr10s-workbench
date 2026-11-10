; LEGACY (stock Creality Marlin era). Uses Marlin-only M420 / avoids M109 because of the old PID.
; For Klipper use gcode/start_pla_klipper.gcode as the template.
; CR-10S PLA start sequence (derived from ABS start, no M109)
; KEY RULE: no M109/M190-blocking-with-oscillation. Current PID oscillates; use M104/M140 + G4.
; PLA: 210C nozzle / 60C bed, no long soak, no enclosure.
M140 S60         ; start bed heating
M104 S210        ; start nozzle heating (non-blocking)
G28              ; home all
M420 S1          ; enable bed leveling mesh
M190 S60         ; wait for bed to reach 60C
M104 S210        ; ensure nozzle target
G4 S30           ; dwell 30s for nozzle to stabilize (NO M109)
G92 E0
G1 Z5 F3000
G1 X5 Y20 F5000
G1 Z0.28 F500
G1 X5 Y120 E10 F600  ; prime line up the left edge
G92 E0
G1 Z2 F3000
