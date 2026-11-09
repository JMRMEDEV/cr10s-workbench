; CR-10S ABS start sequence — tested, Benchy 9/10
; KEY RULE: no M109. Current PID tune oscillates ±10C and makes M109 stall for hours.
; Use M104 (non-blocking) + G4 dwell instead.
M140 S100        ; start bed heating
M104 S245        ; start nozzle heating (non-blocking)
G28              ; home all
M420 S1          ; enable bed leveling mesh
M190 S100        ; wait for bed to FULLY reach 100C
G4 S60           ; soak 60s for even glass heating
M104 S245        ; ensure nozzle target
G4 S45           ; wait 45s for nozzle (NO M109)
G92 E0
G1 Z5 F3000
G1 X0 Y0 F5000
G1 Z0.28 F500
G1 X50 E10 F300  ; slow prime line
G1 X100 E20 F300
G92 E0
G1 Z2 F3000
