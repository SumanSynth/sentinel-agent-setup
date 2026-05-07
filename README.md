# sentinel-agent-setup
Public repo for sentinel agent setup

## Gotty vs sentinel scripts

- **install-gotty.sh** — Uses `wget` and a random directory from `mktemp` (under `$TMPDIR` or `/tmp`, pattern `sentinel-agent-setup.XXXXXX`). That directory is removed on **any** script exit via an `EXIT` trap. After a **successful** install it also deletes the downloaded `install-gotty.sh`. If the install exits early or fails before that final step (port busy, missing tools, `wget`/`sudo` error, etc.), the temp dir is still cleaned but **the downloaded script is kept** so you can retry.
- **uninstall-gotty.sh** — After a **successful** uninstall it deletes the downloaded `uninstall-gotty.sh`. An early exit (e.g. nothing installed) **does not** delete the script.
- **install-gotty.sh** port check requires **`ss`** (usually **iproute2**) **or** **`lsof`** on the host. If neither exists, the installer exits with an error before downloading.
- **install.sh** / **update.sh** — `wget` release binaries into the **current directory** (no `mktemp`, no self-delete). **uninstall.sh** only removes `/opt/sentinel-agent` and the unit; it does not delete itself.

## Install agent
```
curl -sL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/install.sh -o install.sh && sudo chmod +x install.sh && sudo ./install.sh

```

## Update agent
```
curl -sL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/update.sh -o update.sh && sudo chmod +x update.sh && sudo ./update.sh

```


## Remove agent
```
curl -sL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/uninstall.sh -o uninstall.sh && sudo chmod +x uninstall.sh && sudo ./uninstall.sh

```

## Install Gotty (optional)

Requires the sentinel agent install first (`/opt/sentinel-agent` must exist). Installs [Gotty](https://github.com/yudai/gotty) under `/opt/sentinel-agent/bin`, writes `gotty.service`, and starts it (defaults: bind `127.0.0.1`, port `2222`). Before downloading, it verifies the TCP port is free (see **`ss`** / **`lsof`** above). Set **`GOTTY_IP`** / **`GOTTY_PORT`** in the environment when running the installer if you need non-defaults; they are stored in the unit as `Environment=` for `start-gotty.sh`.

```
curl -sL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/install-gotty.sh -o install-gotty.sh && sudo chmod +x install-gotty.sh && sudo ./install-gotty.sh
```

Example with custom bind/port:

```
sudo env GOTTY_IP=127.0.0.1 GOTTY_PORT=3333 ./install-gotty.sh
```

## Remove Gotty

Removes only the Gotty binary (`.../bin/gotty`), `start-gotty.sh`, and `gotty.service`. It does **not** remove `/opt/sentinel-agent/bin`, `/opt/sentinel-agent`, or any sentinel agent files. On success, deletes the downloaded `uninstall-gotty.sh` (see **Gotty vs sentinel scripts** above).

```
curl -sL https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/uninstall-gotty.sh -o uninstall-gotty.sh && sudo chmod +x uninstall-gotty.sh && sudo ./uninstall-gotty.sh
```
