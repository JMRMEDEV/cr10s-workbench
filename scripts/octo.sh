#!/usr/bin/env bash
# octo.sh — helper for the CR-10S OctoPrint Pi.
# Loads credentials from ../.env (relative to this script) and wraps common tasks.
#
# API calls tunnel through SSH to localhost:5000 on the Pi BY DEFAULT, so they work
# from any network (not just the Pi's LAN). Use --direct (or OCTO_DIRECT=1) to hit the
# LAN IP directly when you're on the same network.
#
# Usage:
#   ./scripts/octo.sh ip                 # find the Pi's current IP (Windows/mDNS + ARP)
#   ./scripts/octo.sh ping               # check SSH reachability
#   ./scripts/octo.sh ssh [cmd]          # SSH in (optionally run a command)
#   ./scripts/octo.sh version            # OctoPrint version
#   ./scripts/octo.sh status             # printer connection state
#   ./scripts/octo.sh temps              # current tool/bed temperatures
#   ./scripts/octo.sh job                # current job progress
#   ./scripts/octo.sh connect            # connect OctoPrint to the printer (serial)
#   ./scripts/octo.sh disconnect         # disconnect from the printer
#   ./scripts/octo.sh gcode "M105"       # send one or more G-code commands
#   ./scripts/octo.sh upload file.gcode  # upload a gcode file to OctoPrint
#   ./scripts/octo.sh print file.gcode   # start printing an already-uploaded file
#   ./scripts/octo.sh pause | resume | cancel
#
# Flags: --direct  hit http://PI_IP:5000 directly instead of SSH->localhost
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE not found. Copy .env.example to .env and fill it in." >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a

: "${PI_IP:?set PI_IP in .env}"
: "${PI_SSH_USER:?set PI_SSH_USER in .env}"
: "${OCTOPRINT_API_KEY:?set OCTOPRINT_API_KEY in .env}"

# --direct flag anywhere in args toggles direct mode
DIRECT="${OCTO_DIRECT:-0}"
_args=()
for a in "$@"; do
  if [[ "$a" == "--direct" ]]; then DIRECT=1; else _args+=("$a"); fi
done
set -- "${_args[@]:-}"

ssh_pi() {
  if command -v sshpass >/dev/null && [[ -n "${PI_SSH_PASS:-}" ]]; then
    sshpass -p "$PI_SSH_PASS" ssh -o StrictHostKeyChecking=no \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      -o ConnectTimeout=8 "${PI_SSH_USER}@${PI_IP}" "$@"
  else
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "${PI_SSH_USER}@${PI_IP}" "$@"
  fi
}

# api METHOD PATH [json-data]
# Default: run curl against localhost:5000 ON THE PI via SSH (network-agnostic).
# --direct: run curl from this machine against http://PI_IP:5000 (same-LAN only).
api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ "$DIRECT" == "1" ]]; then
    local args=(-s -X "$method" "http://${PI_IP}:5000${path}" -H "X-Api-Key: ${OCTOPRINT_API_KEY}")
    [[ -n "$data" ]] && args+=(-H "Content-Type: application/json" -d "$data")
    curl "${args[@]}"
  else
    # Build the remote curl safely. Single-quote the JSON for the remote shell.
    local remote="curl -s -X ${method} http://localhost:5000${path} -H 'X-Api-Key: ${OCTOPRINT_API_KEY}'"
    if [[ -n "$data" ]]; then
      local esc=${data//\'/\'\\\'\'}   # escape single quotes for remote shell
      remote+=" -H 'Content-Type: application/json' -d '${esc}'"
    fi
    ssh_pi "$remote"
  fi
}

pretty() { if command -v jq >/dev/null; then jq .; else cat; fi; }

cmd="${1:-help}"; shift || true
case "$cmd" in
  ip)
    echo "Configured PI_IP=$PI_IP (host ${PI_HOST:-octopi.local})"
    if command -v powershell.exe >/dev/null; then
      echo -n "mDNS resolve: "
      powershell.exe -NoProfile -Command "try { (Resolve-DnsName ${PI_HOST:-octopi.local} -ErrorAction Stop | ? {\$_.Type -eq 'A'} | Select -Expand IPAddress) } catch { 'n/a' }" 2>/dev/null | tr -d '\r'
      echo "ARP (Raspberry Pi OUI B8:27:EB):"
      powershell.exe -NoProfile -Command "Get-NetNeighbor -AddressFamily IPv4 | ? LinkLayerAddress -like 'B8-27-EB*' | Select IPAddress,LinkLayerAddress | Format-Table -AutoSize" 2>/dev/null | tr -d '\r'
    fi
    ;;
  ping)
    if nc -z -w3 "$PI_IP" 22 2>/dev/null; then echo "SSH $PI_IP:22 OPEN"; else echo "SSH $PI_IP:22 unreachable"; fi
    ;;
  ssh)       ssh_pi "$@" ;;
  version)   api GET /api/version | pretty; echo ;;
  status)    api GET /api/connection | pretty; echo ;;
  temps)     api GET /api/printer | pretty; echo ;;
  job)       api GET /api/job | pretty; echo ;;
  connect)
    api POST /api/connection \
      "{\"command\":\"connect\",\"port\":\"${PRINTER_SERIAL_PORT:-/dev/ttyUSB0}\",\"baudrate\":${PRINTER_BAUDRATE:-115200}}"
    echo "connect command sent" ;;
  disconnect)
    api POST /api/connection '{"command":"disconnect"}'; echo "disconnect command sent" ;;
  gcode)
    [[ $# -ge 1 ]] || { echo "usage: octo.sh gcode \"M105\" [\"G28\" ...]" >&2; exit 1; }
    # build JSON array of commands
    local_json='{"commands":['
    first=1
    for g in "$@"; do
      [[ $first -eq 1 ]] && first=0 || local_json+=','
      local_json+="\"${g//\"/\\\"}\""
    done
    local_json+=']}'
    api POST /api/printer/command "$local_json"; echo "sent: $*" ;;
  upload)
    [[ $# -eq 1 ]] || { echo "usage: octo.sh upload <local-file.gcode>" >&2; exit 1; }
    f="$1"; [[ -f "$f" ]] || { echo "no such file: $f" >&2; exit 1; }
    # scp to the Pi, then upload to OctoPrint via localhost API
    tmp="/tmp/$(basename "$f")"
    if command -v sshpass >/dev/null && [[ -n "${PI_SSH_PASS:-}" ]]; then
      sshpass -p "$PI_SSH_PASS" scp -o StrictHostKeyChecking=no "$f" "${PI_SSH_USER}@${PI_IP}:${tmp}"
    else
      scp -o StrictHostKeyChecking=no "$f" "${PI_SSH_USER}@${PI_IP}:${tmp}"
    fi
    ssh_pi "curl -s http://localhost:5000/api/files/local -H 'X-Api-Key: ${OCTOPRINT_API_KEY}' -F 'file=@${tmp}' && rm -f '${tmp}'" | pretty; echo ;;
  print)
    [[ $# -eq 1 ]] || { echo "usage: octo.sh print <filename-on-octoprint.gcode>" >&2; exit 1; }
    api POST "/api/files/local/$1" '{"command":"select","print":true}'; echo "print started: $1" ;;
  pause)   api POST /api/job '{"command":"pause","action":"pause"}'; echo "paused" ;;
  resume)  api POST /api/job '{"command":"pause","action":"resume"}'; echo "resumed" ;;
  cancel)  api POST /api/job '{"command":"cancel"}'; echo "cancelled" ;;
  help|*)  sed -n '2,33p' "${BASH_SOURCE[0]}" ;;
esac
