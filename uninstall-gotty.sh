#!/bin/bash
set -euo pipefail

echo "Uninstalling Gotty for sentinel-agent"

SERVICE_FILE="/etc/systemd/system/gotty.service"
INSTALL_BIN="/opt/sentinel-agent/bin/gotty"
INSTALL_START="/opt/sentinel-agent/bin/start-gotty.sh"

if [ ! -f "$SERVICE_FILE" ] && [ ! -f "$INSTALL_BIN" ]; then
  echo "Gotty does not appear to be installed."
  exit 1
fi

if [ -f "$SERVICE_FILE" ]; then
  echo "Disabling the Gotty service to start on boot"
  sudo systemctl disable gotty.service 2>/dev/null || true

  echo "Stopping Gotty service"
  sudo systemctl stop gotty.service 2>/dev/null || true
fi

echo "Removing Gotty files"
sudo rm -f "$INSTALL_BIN" "$INSTALL_START"
sudo rm -f "$SERVICE_FILE"

echo "Reloading systemd configuration"
sudo systemctl daemon-reload

self="${BASH_SOURCE[0]}"
[[ "$self" = /* ]] || self="$(cd "$(dirname "$self")" && pwd)/$(basename "$self")"
rm -f "$self"

exit 0
