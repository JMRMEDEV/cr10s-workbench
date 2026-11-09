#!/usr/bin/env bash
# snap.sh — grab a webcam snapshot from the OctoPi streamer, downsample and/or crop it.
# Usage: ./scripts/snap.sh [label] [max_width] [crop]
#   crop (optional) = "x0,y0,x1,y1" as FRACTIONS of the full frame (e.g. 0.3,0.6,0.8,1.0).
#   Crop is taken at full camera resolution, then limited to max_width.
# Prints the saved path(s). Raw full-res frame kept at /tmp/cam_<label>_raw.jpg
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "${SCRIPT_DIR}/../.env"; set +a
label="${1:-snap}"; width="${2:-512}"; crop="${3:-}"
raw="/tmp/cam_${label}_raw.jpg"
sshpass -p "$PI_SSH_PASS" ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no "${PI_SSH_USER}@${PI_IP}" \
  "curl -s -m 10 'http://127.0.0.1:8080/?action=snapshot'" > "$raw"
python3 - "$raw" "/tmp/cam_${label}.jpg" "$width" "$crop" <<'PY'
import sys
from PIL import Image
raw, out, w, crop = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
im = Image.open(raw).convert("RGB")
if crop:
    x0, y0, x1, y1 = (float(v) for v in crop.split(","))
    W, H = im.size
    im = im.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
if im.width > w:
    im = im.resize((w, round(im.height * w / im.width)))
im.save(out, quality=65)
print(out, im.size)
PY
