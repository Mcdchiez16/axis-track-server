#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# deploy.sh — Build & deploy axis-traccar to the production VPS
# ──────────────────────────────────────────────────────────────
# Usage (run from your local machine):
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Requirements:
#   • SSH key access to the server
#   • .env file exists on the server at /opt/axis-traccar/.env
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SERVER="administrator@102.210.102.40"
REMOTE_DIR="/opt/axis-traccar"

echo "==> Syncing files to $SERVER:$REMOTE_DIR ..."
rsync -avz --exclude='.git' --exclude='node_modules' \
  ./ "${SERVER}:${REMOTE_DIR}/"

echo "==> Building and starting containers on the server ..."
ssh "$SERVER" bash -s <<'ENDSSH'
  set -euo pipefail
  cd /opt/axis-traccar

  # Open firewall ports if UFW is active
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    echo "  --> Ensuring firewall rules ..."
    ufw allow 8082/tcp
    ufw allow 5027/tcp
    ufw allow 5027/udp
    ufw allow 5055/tcp
  fi

  echo "  --> Building axis-traccar image ..."
  docker compose build --no-cache

  echo "  --> Starting stack ..."
  docker compose up -d

  echo "  --> Container status:"
  docker compose ps
ENDSSH

echo ""
echo "✅ Deployment complete!"
echo "   Traccar Web UI → https://gps.devaxis.co.zm"
echo "   Default login  → admin / admin  (change immediately!)"
