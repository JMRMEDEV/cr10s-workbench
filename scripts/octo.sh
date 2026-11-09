#!/usr/bin/env bash
# octo.sh — helper for the CR-10S OctoPrint Pi.
# Loads credentials from ../.env (relative to this script) and wraps common tasks.
#
# Usage:
#   ./scripts/octo.sh ip        # find the Pi's current IP (Windows/mDNS + ARP)
#   ./scripts/octo.sh ping      # check SSH reachability
#   ./scripts/octo.sh ssh [cmd] # SSH in (optionally run a command)
#   ./scripts/octo.sh status    # OctoPrint connection state via API
#   ./scripts/octo.sh version   # OctoPrint version via API
#   ./scripts/octo.sh connect   # tell OctoPrint to connect to the printer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi
set -a; source "$ENV_FILE"; set +a

: "${PI_IP:?set PI_IP in .env}"
: "${PI_SSH_USER:?set PI_SSH_USER in .env}"
# Prefer the IP (reliably routable) over the mDNS hostname, which may not resolve
# in every network namespace (e.g. some WSL2 setups). Override with OCTO_API_BASE.
API_BASE="${OCTO_API_BASE:-http://$PI_IP:5000}"

ssh_pi() {
  if command -v sshpass >/dev/null && [[ -n "${PI_SSH_PASS:-}" ]]; then
    sshpass -p "$PI_SSH_PASS" ssh -o StrictHostKeyChecking=no \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      "${PI_SSH_USER}@${PI_IP}" "$@"
  else
    ssh -o StrictHostKeyChecking=no "${PI_SSH_USER}@${PI_IP}" "$@"
  fi
}

api() {  # api METHOD PATH [data]
  local method="$1" path="$2" data="${3:-}"
  local args=(-s -X "$method" "${API_BASE}${path}" -H "X-Api-Key: ${OCTOPRINT_API_KEY}")
  [[ -n "$data" ]] && args+=(-H "Content-Type: application/json" -d "$data")
  curl "${args[@]}"
}

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
  ssh)   ssh_pi "$@" ;;
  status) api GET /api/connection | (command -v jq >/dev/null && jq . || cat); echo ;;
  version) api GET /api/version | (command -v jq >/dev/null && jq . || cat); echo ;;
  connect)
    api POST /api/connection \
      "{\"command\":\"connect\",\"port\":\"${PRINTER_SERIAL_PORT:-/dev/ttyUSB0}\",\"baudrate\":${PRINTER_BAUDRATE:-115200}}"
    echo "connect command sent"
    ;;
  help|*)
    sed -n '2,12p' "${BASH_SOURCE[0]}"
    ;;
esac
