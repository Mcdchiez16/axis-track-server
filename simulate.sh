#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# simulate.sh — Send a fake GPS position to Traccar (Osmand protocol)
# Useful for testing webhooks and the dashboard without real hardware.
# ──────────────────────────────────────────────────────────────
# Usage:
#   ./simulate.sh <device_id> <lat> <lng> <speed_kmh> <odometer_m> <ignition>
#
# Example (Lusaka area):
#   ./simulate.sh 123456 -15.4230 28.2950 85 153000000 true
#
# Arguments:
#   device_id     Unique device identifier registered in Traccar
#   lat           Latitude  (decimal degrees, negative = South)
#   lng           Longitude (decimal degrees)
#   speed_kmh     Speed in km/h (converted to knots internally)
#   odometer_m    Odometer reading in metres
#   ignition      true | false
#
# Target: Osmand protocol on port 5055 (localhost by default)
# Change TRACCAR_HOST below if testing against the production server.
# ──────────────────────────────────────────────────────────────

set -euo pipefail

TRACCAR_HOST="${TRACCAR_HOST:-localhost}"
TRACCAR_PORT="${TRACCAR_PORT:-5055}"

DEVICE_ID="${1:?Usage: $0 <device_id> <lat> <lng> <speed_kmh> <odometer_m> <ignition>}"
LAT="$2"
LNG="$3"
SPEED_KMH="$4"
ODOMETER_M="$5"
IGNITION="${6:-true}"

# Convert km/h → knots (1 knot = 1.852 km/h)
SPEED_KNOTS=$(echo "scale=4; $SPEED_KMH / 1.852" | bc)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

URL="http://${TRACCAR_HOST}:${TRACCAR_PORT}/?id=${DEVICE_ID}"
URL="${URL}&timestamp=${TIMESTAMP}"
URL="${URL}&lat=${LAT}&lon=${LNG}"
URL="${URL}&speed=${SPEED_KNOTS}"
URL="${URL}&hdop=1.0&altitude=1200"
URL="${URL}&batt=85"
URL="${URL}&ext_power=${IGNITION}"
URL="${URL}&odometer=${ODOMETER_M}"
URL="${URL}&ignition=${IGNITION}"

echo "→ Sending position to Traccar at ${TRACCAR_HOST}:${TRACCAR_PORT} ..."
echo "  Device : $DEVICE_ID"
echo "  Lat/Lng: $LAT, $LNG"
echo "  Speed  : ${SPEED_KMH} km/h (${SPEED_KNOTS} kn)"
echo "  Odo    : ${ODOMETER_M} m"
echo "  Ignition: $IGNITION"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
echo "  HTTP Response: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
  echo "✅ Position sent successfully."
else
  echo "⚠️  Unexpected HTTP code. Check Traccar logs."
  exit 1
fi
