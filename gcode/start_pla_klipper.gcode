; CR-10S PLA start sequence — KLIPPER (matches slicer/pla_cr10s_klipper.ini)
; z_offset and bed mesh are handled by Klipper; standard heat-and-wait is fine (good PID).
M140 S65                      ; first-layer bed temp (glass surface runs cooler)
M104 S210
G28                           ; BLTouch Z home at bed center
BED_MESH_PROFILE LOAD=default
SET_GCODE_OFFSET Z=-0.025     ; slight extra first-layer squish (validated)
M190 S65
M109 S210
G92 E0
G1 Z5 F3000
G1 X5 Y20 F6000
G1 Z0.24 F600
G1 X5 Y120 E12 F900           ; prime line along the left edge
G92 E0
G1 Z2 F3000
