#!/bin/bash
set -euo pipefail
echo "Installing Gotty for sentinel-agent"

VERSION="v1.0.4"
GOTTY_PORT="${GOTTY_PORT:-2222}"
GOTTY_IP="${GOTTY_IP:-127.0.0.1}"
RELEASE_BASE="https://control-centre-public.s3.ap-south-1.amazonaws.com/gotty"
RAW_BASE="https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main"
GOTTY_BIN_URL="${RELEASE_BASE}/gotty"
START_SCRIPT_URL="${RAW_BASE}/bin/start-gotty.sh"

SERVICE_FILE="/etc/systemd/system/gotty.service"
INSTALL_BIN="/opt/sentinel-agent/bin/gotty"
INSTALL_START="/opt/sentinel-agent/bin/start-gotty.sh"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo" >&2
  exit 1
fi

# Exit non-zero if TCP $1 is in use, or if port cannot be checked (missing tools).
gotty_require_port_free() {
  local port="$1"
  local found=""
  local lp

  if command -v ss >/dev/null 2>&1; then
    while read -r state recv send laddr peer _; do
      [ -z "${state:-}" ] && continue
      lp=""
      if [[ "$laddr" =~ \]:([0-9]+)$ ]]; then
        lp="${BASH_REMATCH[1]}"
      elif [[ "$laddr" =~ :([0-9]+)$ ]]; then
        lp="${BASH_REMATCH[1]}"
      fi
      if [ -n "$lp" ] && [ "$lp" = "$port" ]; then
        found=1
        break
      fi
    done < <(ss -ltn 2>/dev/null | tail -n +2 || true)
  elif command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
      found=1
    fi
  else
    echo "ERROR: Cannot verify TCP port ${port}: install iproute2 (\`ss\`) or \`lsof\`." >&2
    return 1
  fi

  if [ -n "$found" ]; then
    echo "ERROR: TCP port ${port} is already in use. Aborting Gotty install." >&2
    echo "Free this port or set GOTTY_PORT to a free value and configure systemd/start-gotty to match, then retry." >&2
    gotty_log_port_listeners "$port"
    echo "--- End diagnostics ---" >&2
    return 1
  fi

  echo "TCP port ${port} is available."
  return 0
}

gotty_log_port_listeners() {
  local port="$1"
  echo "--- Port ${port} diagnostics (listeners) ---" >&2
  if command -v ss >/dev/null 2>&1; then
    echo "[ss -ltnp]" >&2
    ss -ltnp 2>/dev/null | { head -n 1; grep -E ":${port}([[:space:]]|$)" || true; } >&2 || true
  else
    echo "[ss not installed]" >&2
  fi
  if command -v lsof >/dev/null 2>&1; then
    echo "[lsof TCP LISTEN ${port}]" >&2
    lsof -iTCP:"$port" -sTCP:LISTEN -P -n 2>/dev/null >&2 || true
  else
    echo "[lsof not installed]" >&2
  fi
}

if [ ! -d "/opt/sentinel-agent" ]; then
  echo "Directory /opt/sentinel-agent does not exist. Run install.sh for the sentinel agent first."
  exit 1
fi

if [ -f "$INSTALL_BIN" ] || [ -f "$SERVICE_FILE" ]; then
  echo "Gotty appears to be already installed ($INSTALL_BIN or $SERVICE_FILE exists)."
  exit 1
fi

echo "Checking TCP port ${GOTTY_PORT} (default 2222; override with GOTTY_PORT=...)"
gotty_require_port_free "$GOTTY_PORT" || exit 1

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/sentinel-agent-setup.XXXXXX") || {
  echo "Failed to create temporary directory."
  exit 1
}
cleanup_workdir() {
  if [ -n "${WORKDIR:-}" ] && [ -d "${WORKDIR}" ]; then
    rm -rf "${WORKDIR}"
  fi
}
trap cleanup_workdir EXIT

mkdir -p /opt/sentinel-agent/bin

echo "Downloading Gotty binary"
wget -q -O "$WORKDIR/gotty.download" "$GOTTY_BIN_URL"
mv "$WORKDIR/gotty.download" "$INSTALL_BIN"
chmod +x "$INSTALL_BIN"

echo "Downloading start script"
wget -q -O "$WORKDIR/start-gotty.download" "$START_SCRIPT_URL"
mv "$WORKDIR/start-gotty.download" "$INSTALL_START"
chmod +x "$INSTALL_START"

echo "Creating service file at $SERVICE_FILE"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gotty Service
After=network-online.target
Wants=network-online.target

[Service]
Environment=GOTTY_IP=${GOTTY_IP}
Environment=GOTTY_PORT=${GOTTY_PORT}
ExecStart=${INSTALL_START}
WorkingDirectory=/opt/sentinel-agent/bin
Restart=always
RestartSec=10s
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd configuration"
systemctl daemon-reload

echo "Enabling the Gotty service to start on boot"
systemctl enable gotty.service

echo "Starting the Gotty service"
systemctl start gotty.service

echo "Checking the status of the Gotty service"
systemctl status gotty.service || true

exit 0
