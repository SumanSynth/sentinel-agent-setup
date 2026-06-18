#!/bin/bash
# Sentinel Agent Updater
#
# Usage (new version, same key):
#   sudo bash update.sh
#
# Usage (new version + rotated key after a leak):
#   sudo bash update.sh --new-key <NEW_SENTINEL_SECRET_KEY>
#
# Usage (migrating from old version — credentials were baked into the binary):
#   sudo bash update.sh --key <SENTINEL_SECRET_KEY>

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

SECRET_KEY=""      # for old-install migration (no env file exists yet)
NEW_KEY=""         # for key rotation after a credential leak

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)     SECRET_KEY="$2"; shift 2 ;;
    --new-key) NEW_KEY="$2";    shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo" >&2
  exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "ERROR: $INSTALL_DIR doesn't exist — run install.sh first." >&2
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

# ── step 1: recover / establish device id ─────────────────────────────────────
recover_device_id() {
  local id=""

  if [[ -f "$DEVICE_ID_FILE" ]]; then
    id=$(cat "$DEVICE_ID_FILE")
    echo "Using persisted device id: $id" >&2
    echo "$id"; return
  fi

  id=$(systemctl show sentinel-agent.service --property=ExecStart 2>/dev/null \
    | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | head -1 || true)

  if [[ -z "$id" && -f "$SERVICE_FILE" ]]; then
    id=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
      "$SERVICE_FILE" | head -1 || true)
  fi

  if [[ -n "$id" ]]; then
    mkdir -p "$(dirname "$DEVICE_ID_FILE")"
    echo "$id" > "$DEVICE_ID_FILE"
    chmod 600 "$DEVICE_ID_FILE"
    echo "Recovered and persisted device id: $id" >&2
    echo "$id"; return
  fi

  id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  mkdir -p "$(dirname "$DEVICE_ID_FILE")"
  echo "$id" > "$DEVICE_ID_FILE"
  chmod 600 "$DEVICE_ID_FILE"
  echo "WARNING: could not recover old device id — generated new: $id" >&2
  echo "$id"
}

DEVICE_ID=$(recover_device_id)
if [[ -z "$DEVICE_ID" ]]; then
  echo "ERROR: failed to determine device id" >&2
  exit 1
fi

# ── step 2: handle old install migration ──────────────────────────────────────
MIGRATING=false
if [[ ! -f "$ENV_FILE" ]]; then
  MIGRATING=true
  if [[ -z "$SECRET_KEY" && -z "$NEW_KEY" ]]; then
    echo "ERROR: old install detected — no $ENV_FILE found." >&2
    echo "       Re-run with --key <SENTINEL_SECRET_KEY> to migrate." >&2
    exit 1
  fi
  # For old install migration, --key and --new-key mean the same thing
  [[ -z "$NEW_KEY" ]] && NEW_KEY="$SECRET_KEY"
fi

# ── step 3: determine which key to verify against the new binary ───────────────
# If --new-key supplied → validate new key against new binary, then update env.
# Otherwise            → use key already in env file (no rotation).
if [[ -n "$NEW_KEY" ]]; then
  VERIFY_KEY="$NEW_KEY"
elif [[ -f "$ENV_FILE" ]]; then
  VERIFY_KEY=$(grep '^SENTINEL_SECRET_KEY=' "$ENV_FILE" | cut -d= -f2-)
  if [[ -z "$VERIFY_KEY" ]]; then
    echo "ERROR: SENTINEL_SECRET_KEY not found in $ENV_FILE" >&2
    exit 1
  fi
else
  echo "ERROR: no key available — provide --new-key or ensure $ENV_FILE exists." >&2
  exit 1
fi

# ── step 4: download new binary to temp ───────────────────────────────────────
TMP_BINARY=$(mktemp)
trap 'rm -f "$TMP_BINARY"' EXIT

echo "Downloading $BINARY_NAME ..."
wget -q -O "$TMP_BINARY" "$RELEASE_BASE/$BINARY_NAME"
chmod +x "$TMP_BINARY"

# ── step 5: verify key against the NEW binary before touching anything ─────────
echo "Verifying key against new binary ..."
if ! "$TMP_BINARY" verify-key "$VERIFY_KEY"; then
  echo "ERROR: key verification failed — new binary rejected the key." >&2
  echo "       The current install has NOT been changed." >&2
  if [[ -n "$NEW_KEY" ]]; then
    echo "       Check that --new-key matches the credentials compiled into this release." >&2
  else
    echo "       The new release may require a new key. Re-run with --new-key <KEY>." >&2
  fi
  exit 1
fi

# ── step 6: rewrite env file with active key + device id ─────────────────────
# Always rewrite so SENTINEL_DEVICE_ID is present even on older installs that
# only had SENTINEL_SECRET_KEY, and to apply any key rotation.
ACTIVE_KEY="$VERIFY_KEY"
[[ -n "$NEW_KEY" ]] && ACTIVE_KEY="$NEW_KEY"
echo "Updating env file ..."
mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
SENTINEL_SECRET_KEY=$ACTIVE_KEY
SENTINEL_DEVICE_ID=$DEVICE_ID
EOF
chmod 600 "$ENV_FILE"
chown root:root "$ENV_FILE"

# ── step 7: rewrite service file to canonical form ────────────────────────────
# Ensures EnvironmentFile is present and device ID is no longer a CLI arg.
echo "Updating service file ..."
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
systemctl daemon-reload

# ── step 8: atomic swap ────────────────────────────────────────────────────────
mv "$TMP_BINARY" "$BINARY"
trap - EXIT   # binary moved, cancel temp-file cleanup

# ── step 9: restart ───────────────────────────────────────────────────────────
echo "Restarting the sentinel service"
systemctl restart sentinel-agent.service

echo "Checking the status of the sentinel service"
systemctl status sentinel-agent.service

if [[ "$MIGRATING" == "true" ]]; then
  echo ""
  echo "Migration complete. Future updates will not require --key."
fi
