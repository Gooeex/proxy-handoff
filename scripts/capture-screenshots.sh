#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# capture-screenshots.sh — generate reference PNGs from the canonical prototypes.
#
# Purpose: produce the visual-regression baseline in ../screenshots/.
#          Devs compare implementation output against these PNGs before each PR.
#
# Requires: macOS Chrome at /Applications/Google Chrome.app  (or override CHROME=...)
#           python3 (for the local file server)
#
# Usage:    cd path/to/proxy-handoff && bash scripts/capture-screenshots.sh
#
# What it does:
#   1. Starts a python http.server on port 8901 (kills any existing one)
#   2. Iterates over (page, viewport) tuples below
#   3. For client-portal pages, uses scripts/_auth-bootstrap.html to skip login
#   4. Writes PNGs to screenshots/<surface>/<page>-<viewport>.png
# ----------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PORT="${PORT:-8901}"
BASE="http://127.0.0.1:${PORT}"
OUT="screenshots"
PROFILE="/tmp/proxy-handoff-capture-profile"

[ -x "$CHROME" ] || { echo "Chrome not found at: $CHROME"; exit 1; }
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }

# ---------- 1. Start local server (only if one isn't already running) --------
if curl -sf -o /dev/null "$BASE/index.html" 2>/dev/null; then
  echo "▸ Reusing existing server on :${PORT}"
  KEEP_SERVER=1
else
  echo "▸ Starting local server on :${PORT}"
  python3 -m http.server "$PORT" --bind 127.0.0.1 >/tmp/proxy-handoff-server.log 2>&1 &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
  sleep 1
  curl -sf -o /dev/null "$BASE/index.html" || { echo "Server didn't come up"; exit 1; }
  KEEP_SERVER=0
fi

mkdir -p "$OUT/admin" "$OUT/client" "$OUT/design-system"

# ---------- 2. Helper: take one screenshot ------------------------------------
# Chrome's --headless+--screenshot writes the file immediately but doesn't always
# exit cleanly. We wrap it in a 15s wall-clock kill so the script keeps moving
# even if Chrome lingers on shutdown.
shoot () {
  local url="$1" out="$2" w="$3" h="$4"
  rm -f "$out"
  ( "$CHROME" --headless --disable-gpu --hide-scrollbars --no-sandbox \
      --window-size="${w},${h}" \
      --virtual-time-budget=4000 \
      --screenshot="$out" \
      "$url" >/dev/null 2>&1 ) &
  local CPID=$!
  ( sleep 15 && kill -9 $CPID 2>/dev/null ) &
  local WPID=$!
  wait $CPID 2>/dev/null
  kill $WPID 2>/dev/null; wait 2>/dev/null
  if [ -f "$out" ]; then
    printf "  ✓ %-46s %sx%s  %s bytes\n" "$(basename "$out")" "$w" "$h" "$(wc -c <"$out" | tr -d ' ')"
  else
    printf "  ✗ %-46s FAILED\n" "$(basename "$out")"
  fi
}

# Two viewports: desktop and mobile.
VIEWS=( "1440x900:1440" "375x812:375" )

# ---------- 3. Admin panel ----------------------------------------------------
# No auth needed — hash routes only.
ADMIN_ROUTES=( "dashboard" "orders" "proxies" "plans" "clients" "payments" "renewals" "settings" "logs" )

echo
echo "▸ Admin panel (9 routes × 2 viewports)"
# Admin's go() router doesn't fire on hash change at load — use the iframe
# bootstrap so each capture lands on the requested route.
for route in "${ADMIN_ROUTES[@]}"; do
  for view in "${VIEWS[@]}"; do
    size="${view%%:*}"; tag="${view##*:}"
    w="${size%%x*}"; h="${size##*x}"
    shoot "$BASE/scripts/_admin-bootstrap.html?r=${route}" \
          "$OUT/admin/${route}-${tag}.png" "$w" "$h"
  done
done

# ---------- 4. Client portal --------------------------------------------------
# Auto-login via scripts/_auth-bootstrap.html?r=<route>
CLIENT_ROUTES=( "dashboard" "proxies" "proxies/PXY-30412" "orders" "orders/ORD-10847" "billing" "catalog" "checkout" "settings" )

echo
echo "▸ Client portal (9 routes × 2 viewports)"
for route in "${CLIENT_ROUTES[@]}"; do
  for view in "${VIEWS[@]}"; do
    size="${view%%:*}"; tag="${view##*:}"
    w="${size%%x*}"; h="${size##*x}"
    # Slug for filename — replace / with -
    slug="${route//\//-}"
    # URL-encode the / inside ?r=
    enc="${route//\//%2F}"
    shoot "$BASE/scripts/_auth-bootstrap.html?r=${enc}" \
          "$OUT/client/${slug}-${tag}.png" "$w" "$h"
  done
done

# ---------- 5. Design system reference ----------------------------------------
echo
echo "▸ Design system reference (1 viewport)"
shoot "$BASE/prototypes/design-system-reference.html" \
      "$OUT/design-system/reference-1440.png" 1440 900

echo
echo "▸ Done. PNGs in: $OUT/"
echo "  Total: $(find "$OUT" -name '*.png' | wc -l | tr -d ' ') files."
