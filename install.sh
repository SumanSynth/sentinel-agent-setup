#!/bin/bash
# Sentinel Agent Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/install.sh \
#     | sudo bash -s -- --key <SENTINEL_SECRET_KEY>

set -euo pipefail

# ── constants ─────────────────────────────────────────────────────────────────
RELEASE_BASE="https://control-centre-public.s3.ap-south-1.amazonaws.com/sentinel-agent"
INSTALL_DIR="/opt/sentinel-agent"
BINARY="$INSTALL_DIR/sentinel-agent-linux-amd64"
CONFIG_DIR="/etc/sentinel-agent"
ENV_FILE="$CONFIG_DIR/env"
DEVICE_ID_FILE="$CONFIG_DIR/device_id"
SERVICE_NAME="sentinel-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

SECRET_KEY=""

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) SECRET_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo" >&2
  exit 1
fi

# ── key required ──────────────────────────────────────────────────────────────
if [[ -z "$SECRET_KEY" ]]; then
  echo "ERROR: --key <SENTINEL_SECRET_KEY> is required" >&2
  echo "       Obtain the key from your admin or dashboard." >&2
  exit 1
fi

# ── guard: detect state of existing install ───────────────────────────────────
if [[ -d "$INSTALL_DIR" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    echo "ERROR: sentinel agent is already installed (new version)." >&2
    echo "       To update the binary:  sudo bash update.sh" >&2
    echo "       To reinstall cleanly:  sudo bash uninstall.sh && sudo bash install.sh --key <KEY>" >&2
  else
    echo "ERROR: old version of sentinel agent is installed." >&2
    echo "       To migrate to the new version: sudo bash update.sh --key $SECRET_KEY" >&2
  fi
  exit 1
fi

# ── detect architecture ───────────────────────────────────────────────────────
arch=$(uname -m)
case "$arch" in
  x86_64)
    echo "AMD64 architecture detected."
    BINARY_NAME="sentinel-agent-linux-amd64"
    ;;
  arm64|aarch64)
    echo "ARM64 architecture detected."
    BINARY_NAME="sentinel-agent-linux-arm64"
    ;;
  *)
    echo "ERROR: unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

# ── device id ─────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$DEVICE_ID_FILE")"
if [[ -f "$DEVICE_ID_FILE" ]]; then
  DEVICE_ID=$(cat "$DEVICE_ID_FILE")
  echo "Reusing existing device id: $DEVICE_ID"
else
  DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
  echo "$DEVICE_ID" > "$DEVICE_ID_FILE"
  chmod 600 "$DEVICE_ID_FILE"
  echo "Generated device id: $DEVICE_ID"
fi

# ── download binary to temp ───────────────────────────────────────────────────
TMP_BINARY=$(mktemp)
trap 'rm -f "$TMP_BINARY"' EXIT

echo "Downloading $BINARY_NAME ..."
wget -q -O "$TMP_BINARY" "$RELEASE_BASE/$BINARY_NAME"
chmod +x "$TMP_BINARY"

# ── verify key against the downloaded binary ──────────────────────────────────
echo "Verifying secret key against new binary ..."
if ! "$TMP_BINARY" verify-key "$SECRET_KEY"; then
  echo "ERROR: key verification failed — the key does not match this binary." >&2
  echo "       Check that you are using the correct SENTINEL_SECRET_KEY." >&2
  exit 1
fi

# ── install binary ────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
mv "$TMP_BINARY" "$BINARY"
trap - EXIT   # binary moved, cancel temp-file cleanup

# ── write env file (root-only, mode 0600) ────────────────────────────────────
echo "Writing env file to $ENV_FILE ..."
cat > "$ENV_FILE" <<EOF
SENTINEL_SECRET_KEY=$SECRET_KEY
SENTINEL_DEVICE_ID=$DEVICE_ID
EOF
chmod 600 "$ENV_FILE"
chown root:root "$ENV_FILE"

# ── create systemd service ────────────────────────────────────────────────────
echo "Creating service file at $SERVICE_FILE"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sentinel Agent Service
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=$ENV_FILE
ExecStart=$INSTALL_DIR/sentinel-agent-linux-amd64
WorkingDirectory=$INSTALL_DIR/
Restart=always
RestartSec=10s
User=root
Group=root
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# ── start service ─────────────────────────────────────────────────────────────
echo "Reloading systemd configuration"
systemctl daemon-reload

echo "Enabling the sentinel service to start on boot"
systemctl enable sentinel-agent.service

echo "Starting the sentinel service"
systemctl start sentinel-agent.service

echo "Checking the status of the sentinel service"
systemctl status sentinel-agent.service
