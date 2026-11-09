# OctoPrint-ZShift

A tiny OctoPrint **middleware** plugin that adds a fixed offset to the `Z` value of
every `G0`/`G1` motion command **before it is sent to the printer**.

## Why this exists

The CR-10S's Creality Marlin firmware on this machine ignores every normal Z-datum
mechanism — `M851` (probe offset), `M206` (home offset) and even `G92 Z` are all
clamped, so the firmware's `Z0` ends up ~1.15 mm *below* the real first-layer height
(nozzle into the glass). Reflashing is the proper fix but needs an ISP programmer and
hands-on access.

Raw absolute `G1 Z<n>` moves, however, are honored exactly. So instead of asking the
firmware to shift the datum, this plugin makes **OctoPrint** do the math: it rewrites
`Z<n>` → `Z<n + offset>` on the way out. The slicer stays normal; the nozzle lands right.

## What it touches / what it doesn't

- Rewrites: `G0` / `G1` lines that contain a `Z` word.
- Leaves untouched: `G28` (home), `G29` (probe), `G92`, `M` commands, arcs without Z, etc.
- Relative moves (`G91`) are passed through unchanged — a relative Z step must not be
  offset (only absolute positions get the datum shift). The plugin tracks `G90`/`G91`.

## Settings

- `z_offset` (float, default `1.15`): millimetres added to absolute Z moves.
- `enabled` (bool, default `true`): master on/off.

## Install (on the Pi)

```bash
source ~/oprint/bin/activate
pip install /path/to/OctoPrint-ZShift   # or the folder copied to the Pi
sudo service octoprint restart
```

Then set the offset in OctoPrint → Settings → Plugins → ZShift (or in config.yaml).

## Safety note

This shifts **absolute** Z only, and never rewrites homing/probing. Verify the first
layer with a paper test after install/any offset change. The value here (1.15 mm) was
measured empirically at bed center; re-measure if the bed or probe mounting changes.
