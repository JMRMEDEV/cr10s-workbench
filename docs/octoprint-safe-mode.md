# OctoPrint Safe Mode — Triggers, Diagnosis & Recovery

Reference for why OctoPrint boots into **safe mode** (all third-party plugins —
including our `ZShift` — disabled) and how to prevent/recover. Written after a safe-mode
event during the 2026-11-08 calibration session.

---

## What safe mode is
A protective boot mode (since OctoPrint 1.3.0) that disables **all non-bundled
plugins and language packs**. It exists so a broken third-party plugin can't permanently
prevent the server from starting. The web UI shows a yellow "safe mode" banner.

**Impact for us:** the `ZShift` Z-offset middleware is a third-party plugin, so in safe
mode it is disabled → the +0.90mm Z rewrite stops → **slicer Z0 goes back to the raw
firmware datum = nozzle crushes the bed.** So safe mode is print-affecting for this
machine and must be recognized before starting a print.

---

## What triggers it

### 1. Automatic: "problem during last startup"  ← this is what hit us
Added in OctoPrint **1.3.11**. On a clean startup OctoPrint writes a "startup completed"
marker; on the *next* boot it checks that marker. If the previous run **did not finish
starting up** (crash, kill, power loss, or being restarted again before it finished
booting), it sets `server.startOnceInSafeMode = true` and the next boot is safe mode.

- API/sysinfo reports this as: `"safemode": "incomplete_startup"`
- Our log confirmed it verbatim:
  `octoprint.startup - INFO - Reason for safe mode: problem during last startup`

**Root cause in our session:** we issued several `sudo service octoprint restart`
commands in quick succession while tuning the plugin offset. Restarting OctoPrint again
*before the previous start had fully completed* looks exactly like an "incomplete
startup", so the safety belt tripped. It is self-clearing — the very next normal boot
ran fine with the plugin enabled.

### 2. Intentional (operator-initiated)
- System menu → **"Restart OctoPrint in safe mode"**
- CLI: `~/oprint/bin/octoprint safemode`  (sets the one-shot flag)
- CLI: `~/oprint/bin/octoprint serve --safe`  (one run only)
- `config.yaml`: `server: { startOnceInSafeMode: true }` then restart

All of the one-shot methods **clear automatically** after the next start.

### 3. Not a trigger
A plain reboot or a *clean* restart does NOT cause safe mode. Only an
incomplete/failed previous startup (or an explicit request) does.

---

## How to detect it
```bash
# via API (needs API key)
curl -s localhost:5000/api/server -H "X-Api-Key: $KEY"      # -> "safemode": "incomplete_startup" or null

# via logs on the Pi
grep -iE "SAFE MODE|Reason for safe mode" ~/.octoprint/logs/octoprint.log | tail

# is the plugin actually active? (look for '!' = disabled prefix)
grep -E "ZShift" ~/.octoprint/logs/octoprint.log | tail -1
#   |   ZShift (...)   -> ENABLED (good)
#   |  !ZShift (...)   -> DISABLED (safe mode)
```
`octo.sh` note: `./scripts/octo.sh version` works regardless; to confirm the plugin,
grep the log as above.

---

## How to recover
Safe mode from `incomplete_startup` is one-shot, so usually:
```bash
sudo service octoprint restart     # ONE clean restart, then WAIT for full startup
```
Then verify the plugin is back (no `!` prefix) **before** starting any print.

If it keeps re-entering safe mode (genuine failing plugin/startup):
```bash
grep -iE "error|exception|traceback" ~/.octoprint/logs/octoprint.log | tail -40
# fix/uninstall the offending plugin (allowed even in safe mode):
#   source ~/oprint/bin/activate && pip uninstall <plugin>
```

---

## How to PREVENT it (lessons for future automated sessions)
1. **Never restart OctoPrint again until the previous start fully completes.** After
   `service octoprint restart`, poll `curl localhost:5000/` until it returns `200`
   **and** then wait a few extra seconds for plugin init before any further restart.
2. **Batch config changes** — change `z_offset` (and any settings) once, then a single
   restart, instead of restart-per-tweak.
3. **Prefer live settings over restarts** — plugin setting changes can be applied via
   the Settings API / UI without a full server restart; reserve restarts for code
   changes (install/upgrade).
4. **Always confirm plugin state after any restart** (grep for `!ZShift`) before
   trusting the Z offset for a print.
5. On the Pi itself, avoid power-cutting during boot; let it finish.

---

## Quick reference
| Symptom | Meaning | Action |
|---------|---------|--------|
| Yellow "safe mode" banner / `!ZShift` in log | plugins disabled | one clean restart, wait, re-verify |
| `"safemode": "incomplete_startup"` | last boot didn't finish (crash / rapid restart / power loss) | clean restart (self-clears) |
| Re-enters safe mode every boot | a plugin/startup genuinely failing | read logs, uninstall offender |
| Nozzle crushes bed on a print that worked before | ZShift disabled by safe mode | check plugin enabled, restart, re-verify before printing |
