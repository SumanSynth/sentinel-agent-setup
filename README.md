# sentinel-agent-setup

Public distribution repo for the Sentinel Agent binary and installer scripts.

> **Security model:** The binary contains AES-encrypted broker credentials.
> The decryption key is never stored in the binary — it is supplied at install
> time via `--key` and written to `/etc/sentinel-agent/env` (root-only, mode
> `0600`). The binary alone cannot connect to the broker without the key.

---

## Requirements

- Linux (amd64 or arm64)
- `wget`, `curl`, `uuidgen`, `systemd`
- Root / sudo access

---

## Install

Obtain your `SENTINEL_SECRET_KEY` from your admin or dashboard, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/install.sh \
  | sudo bash -s -- --key YOUR_SENTINEL_SECRET_KEY
```

What the installer does:
- Detects CPU architecture (amd64 / arm64) and downloads the correct binary
- Generates a stable device ID and saves it to `/etc/sentinel-agent/device_id`
- Writes the decryption key to `/etc/sentinel-agent/env` (mode `0600`, root only)
- Creates and starts a systemd service (`sentinel-agent.service`)

---

## Update

**New install (v1.0.3+):**
```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/update.sh \
  | sudo bash
```

**Migrating from an old install (credentials were baked into the binary):**
```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/update.sh \
  | sudo bash -s -- --key YOUR_SENTINEL_SECRET_KEY
```

The updater:
- Recovers the existing device ID from the systemd unit (no identity change)
- Writes the env file and updates the service unit if migrating from an old install
- Atomically swaps the binary — the old binary keeps running until `mv` completes
- Restarts the service

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/uninstall.sh \
  | sudo bash
```

The uninstaller removes the binary, credentials, and service file.
`/etc/sentinel-agent/device_id` is **intentionally kept** — if you reinstall
later the device will retain the same identity.

---

## Files installed on the machine

| Path | Purpose |
|---|---|
| `/opt/sentinel-agent/sentinel-agent-linux-amd64` | Agent binary |
| `/etc/sentinel-agent/env` | Decryption key (mode `0600`, root only) |
| `/etc/sentinel-agent/device_id` | Stable device identity (persisted across reinstalls) |
| `/etc/systemd/system/sentinel-agent.service` | Systemd unit |

---

## Install Gotty (optional)

Requires the sentinel agent to be installed first (`/opt/sentinel-agent` must
exist). Installs [Gotty](https://github.com/yudai/gotty) under
`/opt/sentinel-agent/bin`, writes `gotty.service`, and starts it (defaults:
bind `127.0.0.1`, port `2222`). Requires `ss` (iproute2) or `lsof` to check
the port before downloading.

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/install-gotty.sh \
  | sudo bash
```

Custom bind address / port:
```bash
curl -fsSL .../install-gotty.sh -o install-gotty.sh
sudo env GOTTY_IP=127.0.0.1 GOTTY_PORT=3333 bash install-gotty.sh
```

## Remove Gotty

Removes the Gotty binary, `start-gotty.sh`, and `gotty.service` only — does
not touch the sentinel agent files.

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/uninstall-gotty.sh \
  | sudo bash
```
