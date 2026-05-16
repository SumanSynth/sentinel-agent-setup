# Sentinel Agent

Lightweight system monitoring agent that runs as a background service.

---

## Requirements

- Linux (amd64 or arm64)
- `wget`, `uuidgen`, `systemd`
- Root / sudo access

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/install.sh | sudo bash -s -- --key YOUR_SENTINEL_SECRET_KEY
```

---

## Update

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/update.sh | sudo bash
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/uninstall.sh | sudo bash
```

---

## Install Gotty (optional)

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/install-gotty.sh | sudo bash
```

## Remove Gotty

```bash
curl -fsSL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/uninstall-gotty.sh | sudo bash
```
