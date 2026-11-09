# CR-10S Workbench

A personal workbench for my **Creality CR-10S** managed over **OctoPrint** (Raspberry Pi 3B).
It holds the things I keep re-learning: how to connect to the Pi, tested slicer settings
per material, start G-code, and hard-won lessons from failed prints.

> Printer: Creality CR-10S · Bed: glass + glue stick · Enclosure: DIY (clear plastic + PVC frame)
> Print server: OctoPrint on Raspberry Pi 3B (`octopi.local`)

## Layout

```
cr10s-workbench/
├── README.md              # you are here
├── .env.example           # credential template (committed)
├── .env                    # real credentials (gitignored — never committed)
├── docs/
│   └── connecting-to-pi.md # how to find + SSH into the Pi, OctoPrint API, reset web password
├── materials/
│   └── abs.md              # tested CR-10S ABS profile, temps, speeds, retraction, lessons
├── gcode/
│   └── start_abs.gcode     # proven ABS start sequence (no M109 — see notes)
└── scripts/
    └── octo.sh             # helper: load .env, hit OctoPrint API, SSH in
```

## Credentials & safety

Secrets live in a **gitignored `.env`**. Get started with:

```bash
cp .env.example .env   # then edit with real values
chmod 600 .env
```

`.gitignore` blocks `.env` (and keys/pems) so they never land in git. Only `.env.example`
with placeholders is committed. See [docs/connecting-to-pi.md](docs/connecting-to-pi.md).

Current defaults are intentionally weak (`pi`/`raspberry`, web `admin`/`admin`) for a
LAN-only device. **Change them** if the Pi is ever exposed beyond a trusted network.

## Quick start

```bash
# 1. find the Pi's current IP (it changes between networks)
./scripts/octo.sh ip

# 2. check printer connection status via the OctoPrint API
./scripts/octo.sh status

# 3. SSH into the Pi
./scripts/octo.sh ssh
```

## Materials

| Material | Profile | Status |
|----------|---------|--------|
| ABS 1.75mm | [materials/abs.md](materials/abs.md) | Tested — Benchy 9/10 |

More profiles (PLA, PETG) to be added as they're dialed in.

## Source

Settings and lessons distilled from my `tux-droid-2026` build notes
(`3D_PRINTING_NOTES.md`).
