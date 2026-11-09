# Connecting to the OctoPrint Pi

Everything needed to find, reach, and control the CR-10S's OctoPrint Pi.
Load credentials from `.env` first:

```bash
set -a; source .env; set +a   # exports PI_IP, PI_SSH_USER, etc.
```

---

## 1. Find the Pi's IP

The Pi's IP **changes between networks** (e.g. `192.168.1.20` at one place,
`192.168.100.33` at another). The `octopi.local` mDNS name is stable *on the same LAN*
but does **not** resolve from other networks or from inside some WSL2 network namespaces.

**From Windows (works from WSL2 via interop):**
```bash
# resolve the mDNS name
powershell.exe -NoProfile -Command "Resolve-DnsName octopi.local | Select -Expand IPAddress"

# or scan the ARP table for the Raspberry Pi MAC (OUI B8:27:EB)
powershell.exe -NoProfile -Command "Get-NetNeighbor -AddressFamily IPv4 | Where LinkLayerAddress -like 'B8-27-EB*'"
```

**From Linux on the same LAN:**
```bash
getent hosts octopi.local || avahi-resolve -n octopi.local
ping -c1 octopi.local
```

> Note: a remote/cloud shell (or a WSL2 namespace without LAN bridging) **cannot** reach
> the Pi. The connection must originate from a machine on the same network.

---

## 2. SSH into the Pi

The SSH login is **separate** from the OctoPrint web login. OctoPi defaults: `pi` / `raspberry`.

```bash
# interactive
ssh ${PI_SSH_USER}@${PI_IP}

# non-interactive (uses sshpass — password passes through the shell)
sshpass -p "$PI_SSH_PASS" ssh -o StrictHostKeyChecking=no "${PI_SSH_USER}@${PI_IP}" \
  "hostname; systemctl is-active octoprint"
```

Probe reachability / offered auth without guessing a password:
```bash
nc -z -w3 "$PI_IP" 22 && echo "port 22 open"
ssh -o BatchMode=yes -o PreferredAuthentications=none "${PI_SSH_USER}@${PI_IP}"  # prints allowed methods
```

---

## 3. OctoPrint REST API

The API key lives in `~/.octoprint/config.yaml` (`api.key`) on the Pi, or Settings → API in the web UI.

```bash
# printer/connection state
curl -s "${OCTOPRINT_URL}:5000/api/connection" -H "X-Api-Key: ${OCTOPRINT_API_KEY}"

# version
curl -s "${OCTOPRINT_URL}:5000/api/version" -H "X-Api-Key: ${OCTOPRINT_API_KEY}"

# connect to the printer over serial
curl -s -X POST "${OCTOPRINT_URL}:5000/api/connection" \
  -H "X-Api-Key: ${OCTOPRINT_API_KEY}" -H "Content-Type: application/json" \
  -d "{\"command\":\"connect\",\"port\":\"${PRINTER_SERIAL_PORT}\",\"baudrate\":${PRINTER_BAUDRATE}}"
```

> The global API key may be **read-only** for some actions; printer connect/control can
> return a permission error. Use a user/app API key with write access if needed.

---

## 4. Reset the OctoPrint web-UI password

The web-UI password is **not** the SSH password. It's stored in `~/.octoprint/users.yaml`.
You need SSH access to reset it. On OctoPrint 1.3.12+:

```bash
ssh ${PI_SSH_USER}@${PI_IP}
source ~/oprint/bin/activate
octoprint user password admin            # prompts for new password (interactive)
# non-interactive on 1.11+: octoprint user password admin --password 'newpass'
sudo service octoprint restart
```

Full reset to the first-run wizard (destructive — wipes all web users):
```bash
rm ~/.octoprint/users.yaml
sed -i 's/firstRun: false/firstRun: true/' ~/.octoprint/config.yaml
sudo service octoprint restart
```

Verify the service is back:
```bash
curl -s -o /dev/null -w "%{http_code}\n" "${OCTOPRINT_URL}:5000/"   # expect 200
```

Reference: <https://community.octoprint.org/t/i-forgot-my-octoprint-password-how-can-i-reset-it/215>

---

## 5. Current working values

See `.env` (gitignored). As of 2026-11-08:

| What | Value |
|------|-------|
| SSH | `pi` / `raspberry` @ `192.168.100.33` (host `octopi`) |
| Web UI | `admin` / `admin` — **change this** |
| API key | in `.env` as `OCTOPRINT_API_KEY` |
| Pi MAC | `B8:27:EB:2E:27:49` (use to re-find IP after a network change) |
