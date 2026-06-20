# Docker Codeserver Python — Specification

## Base Image

`mcr.microsoft.com/devcontainers/python:3.12-bookworm`

## System Packages (apt)

git, bash, net-tools, netcat-traditional, nmap, supervisor, build-essential,
cron, tzdata, procps, tini, tigervnc-standalone-server, tigervnc-tools, dbus,
x11vnc, xvfb, x11-xserver-utils, fluxbox, novnc, imagemagick, oneko,
x11-apps, gh

Additional: rclone (installed via `curl -fsSL https://rclone.org/install.sh | bash`).

Timezone: `America/Los_Angeles` (set via `TZ` env var; symlinked to
`/etc/localtime`).

## code-server

- Installed via the official install script (`curl -fsSL https://code-server.dev/install.sh | sh`).
- Config: `/app/code-server.yaml`
  - Binds `0.0.0.0:80`
  - Auth: `none` (no password prompt in the browser)
  - Extensions dir: `/app/extensions`
  - User data dir: `/home/vscode/.local/share/code-server`
  - Workspace trust disabled (`disable-workspace-trust: true`)
  - Welcome text: "Welcome to the League Codeserver"
  - App name: "League Code Server"
- Extensions pre-installed at image build time (run as `vscode` user):
  - `jtl-syllabus-1.20250618.1.vsix` (bundled VSIX, JTL curriculum extension)
  - `ms-python.python`
  - `ms-toolsai.jupyter`
- VS Code user settings (`/app/vsc/settings.json`) are copied into the user
  data dir by `setup.sh` at container start, overwriting any previous file.
  Notable settings: autosave after 1 s, format on save, Copilot fully disabled,
  minimap off, activity bar at bottom, word wrap at 120 columns, startup editor
  is "readme".
- Workspace `.vscode/settings.json` is merged (via `jq`) with
  `/app/vsc/workspace-settings.json` at container start. That file sets the
  default Python interpreter to `/usr/local/bin/python3` and excludes
  `/bin/python3` and `/usr/bin/python3` from Jupyter kernel selection.
- VS Code debug configuration (`/app/vsc/launch.json`) provides a single
  launch config: "Python Debugger: Current File" using `debugpy` with the
  integrated terminal.
- Launched by supervisord as user `vscode`, `autorestart=true`, priority 20.

## Python Environment

- Runtime: Python 3.12 (from base image), interpreter at `/usr/local/bin/python3`.
- pip packages (`/app/requirements.txt`):
  - `pygame`
  - `pgzero`
  - `guizero`
  - `pillow`
  - `IPython`
  - `ipykernel`
  - `git+https://github.com/league-curriculum/jlt_lib.git` (League library)
  - `invoke`
- Jupyter kernel registered as `codehost` ("Python (League Code Host)") by
  `setup.sh` via `python -m ipykernel install --user --name codehost`.
- All `.ipynb` files in the workspace are updated to use the `codehost`
  kernelspec by `updateks.py` at startup. Backs up each notebook as
  `*.ipynb.bak.<timestamp>` before modifying.
- Default workspace Python interpreter set in
  `/workspace/.vscode/settings.json` at build time.

## Virtual Desktop (noVNC)

Three supervisor-managed processes, grouped under `[group:novnc]`, priority 999:

1. **desktop-preflight** (priority 10, `autorestart=false`, runs once): removes
   stale X11 sockets (`/tmp/.X11-unix`, `/tmp/.X*-lock`), recreates the
   directory with sticky bit (mode 1777), and starts `dbus-daemon` if not running.
2. **tigervnc** (user `vscode`, `autorestart=true`):
   `tigervncserver :0 -geometry ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} -depth 16 -rfbport 5901 -localhost -fg -dpi 96 -desktop fluxbox -SecurityTypes None`
   - Listens on `localhost:5901` (not exposed externally).
   - VNC password disabled (empty `/home/vscode/.vnc/passwd`, mode 600).
   - Display size defaults: 600x600 (`DISPLAY_WIDTH` / `DISPLAY_HEIGHT`).
   - Color depth: 16-bit.
3. **novnc** (user `root`, `autorestart=true`):
   `/usr/share/novnc/utils/novnc_proxy --listen 6080 --vnc localhost:5901`
   - Exposes port 6080. The reverse proxy routes `/vnc/` and `/websockify*` here.
   - **Known issue**: `novnc_proxy` is called without `--heartbeat`, so sessions
     drop when the screen is idle due to WebSocket idle-timeout on network
     intermediaries (firewalls, NAT, Cloudflare). Fix: replace `novnc_proxy`
     with `websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901`
     and add client-side auto-reconnect via `JTL_VNC_URL` query params.
     See `.clasi/issues/fixing-novnc-timeouts.md` and
     `.clasi/issues/plan-apply-the-novnc-timeout-fixes-from-fixing-novnc-timeouts-md.md`.

Environment variable `DISPLAY=:0.0` is set in the image.
Logs for both tigervnc and novnc go to `/var/log/novnc.log`.

## Networking / Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 80 | HTTP | code-server (VS Code IDE) |
| 6080 | HTTP/WS | noVNC / websockify (VNC over WebSocket) |
| 8080 | — | Host-side mapped port for code-server (`docker-compose: 8080:80`) |
| 5901 | RFB/TCP | TigerVNC, internal only (`localhost:5901`, not exposed) |

Caddy reverse proxy routing (configured via docker-compose labels for host
`codespace.doswarm.jointheleague.org`):

- `/websockify*` → port 6080 (WebSocket upgrade: `Connection *Upgrade*` +
  `Upgrade websocket` headers matched)
- `/vnc/*` → port 6080 (path-stripped reverse proxy)
- `/*` → port 80 (code-server catch-all)
- Basic auth configured for `admin` user (bcrypt hash in compose labels).

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PASSWORD` | `code4life` | Carried in image (code-server auth is `none`, so effectively unused at runtime) |
| `WORKSPACE_FOLDER` | `/workspace/` | Path passed to code-server and used by all setup/sync scripts |
| `HOME` | `/home/vscode` | Home directory for the `vscode` user |
| `DISPLAY` | `:0.0` | X11 display for graphical apps |
| `DISPLAY_WIDTH` | `600` | TigerVNC geometry width |
| `DISPLAY_HEIGHT` | `600` | TigerVNC geometry height |
| `LANG` / `LANGUAGE` | `en_US.UTF-8` | Locale |
| `LC_ALL` | `C.UTF-8` | Locale (overrides per-category) |
| `TZ` | `America/Los_Angeles` | Timezone |
| `KST_REPORT_INTERVAL` | `10` | Telemetry report interval in seconds (consumed by JTL Syllabus extension) |
| `KST_DEBUG` | `0` | Telemetry debug flag (consumed by JTL Syllabus extension) |
| `LEAGUE_CODESERVER` | `1` | Image identity marker |
| `DEBIAN_FRONTEND` | `noninteractive` | Suppresses apt prompts during build |
| `JTL_REPO` | (none) | Git URL of curriculum repo to clone into workspace |
| `JTL_SYLLABUS` | (none) | Path to syllabus YAML inside the cloned repo (consumed by JTL extension) |
| `JTL_USERNAME` | (none) | Student username; used in push callback URL and rclone object-store path |
| `JTL_CLASS_ID` | (none) | Class ID; used in rclone object-store path |
| `JTL_VNC_URL` | (none) | Public URL for the VNC/noVNC endpoint (consumed by JTL Syllabus extension to open the VNC panel) |
| `JTL_IMAGE_URI` | (none) | Docker image URI (informational, consumed by JTL extension) |
| `JTL_SPAWNER_URL` | (none) | Base URL of the code-spawner service; used by `push.sh` |
| `JTL_HOST_UUID` | (none) | UUID of this container host; appended to push callback URL |
| `KST_REPORTING_URL` | (none) | Telemetry endpoint URL (consumed by JTL Syllabus extension) |
| `SETUP_SCRIPT` | (none) | Override path to repo setup script, relative to workspace root |
| `STORAGE_BUCKET` | (none) | S3 bucket name for rclone |
| `STORAGE_ENDPOINT` | (none) | S3-compatible endpoint URL for rclone (scheme stripped internally) |
| `AWS_ACCESS_KEY_ID` | (none) | S3 credentials for rclone (`env_auth=true`) |
| `AWS_SECRET_ACCESS_KEY` | (none) | S3 credentials for rclone (`env_auth=true`) |

## Startup Sequence (supervisord)

Entrypoint: `tini -- supervisord -c /app/supervisord.conf`

Supervisord runs as `root`, `nodaemon=true`, logs to stdout/stderr (Docker
captures them). Socket at `/var/run/supervisor.sock`.

1. **desktop-preflight** (priority 10, one-shot): cleans X sockets, starts dbus.
2. **setup** (priority 10, one-shot, user `vscode`, `/app/bin/setup.sh`):
   - Creates `~/.config/rclone/rclone.conf` (empty placeholder).
   - Copies `/app/vsc/settings.json` to VS Code user settings dir.
   - If `JTL_REPO` is set: clones into `WORKSPACE_FOLDER` (or `git pull` if
     directory already exists). Then runs `.jtl/setup.sh` from the repo if found.
   - Exports `WORKSPACE_FOLDER`, `JTL_SPAWNER_URL`, `JTL_USERNAME`,
     `JTL_HOST_UUID` to `~/env.sh` for cron consumption.
   - Merges `/app/vsc/workspace-settings.json` into
     `${WORKSPACE_FOLDER}/.vscode/settings.json` using `jq`.
   - Installs ipykernel: `python -m ipykernel install --user --name codehost`.
   - Updates all `.ipynb` kernelspec metadata via `updateks.py codehost`.
3. **codeserver** (priority 20, `autorestart=true`, user `vscode`): launches
   `code-server --config /app/code-server.yaml $WORKSPACE_FOLDER`.
4. **tigervnc** + **novnc** (group `novnc`, priority 999, `autorestart=true`).
5. **cron** (`autorestart=true`, user `root`): `cron -f -L 15`.

## Cron Jobs

`/etc/crontab` (replaced from `/app/crontab` at build time):

| Schedule | User | Command |
|----------|------|---------|
| Every minute (`* * * * *`) | vscode | `/app/bin/push.sh >> /tmp/push.log 2>&1` |

`push.sh` behavior: sources `~/env.sh` for env vars, does `git add -A` in
`$WORKSPACE_FOLDER`, commits if staged changes exist with message "Auto-commit:
workspace changes before push", then POSTs to
`$JTL_SPAWNER_URL/host/$JTL_USERNAME/push?host_uuid=$JTL_HOST_UUID` to trigger
the spawner to perform the GitHub push. No GitHub credentials are stored in the
container.

## rclone Storage Sync

`/app/bin/rclone.sh {copy|sync} {in|out}` syncs `$WORKSPACE_FOLDER` to/from
an S3-compatible object store. Called by the spawner (not by internal cron).

Remote key format: `$STORAGE_BUCKET/class_$JTL_CLASS_ID/$JTL_USERNAME$WORKSPACE_FOLDER`

Provider: DigitalOcean (S3-compatible, `provider=DigitalOcean,env_auth=true`).
Credentials via `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars.
Endpoint scheme is stripped (`http://` / `https://` prefix removed) before
passing to rclone. Log level: `INFO`.

Required env vars (script exits with error if missing): `WORKSPACE_FOLDER`,
`STORAGE_BUCKET`, `JTL_CLASS_ID`, `JTL_USERNAME`, `STORAGE_ENDPOINT`,
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.

## Keystroke Telemetry (KST)

Telemetry is consumed entirely by the JTL Syllabus VS Code extension
(`jtl-syllabus-1.20250618.1.vsix`). No in-container script handles telemetry.
The extension reads `KST_REPORTING_URL` to find the reporting endpoint and
`KST_REPORT_INTERVAL` (default `10` seconds) to set its report cadence.
`KST_DEBUG=0` is set in the image; set to `1` at runtime for verbose extension
logging.

## Git Configuration (in image)

Set at build time for the `vscode` user:
- `pull.rebase true`
- `user.email student@jointheleague.org`
- `user.name League Student`

PS1 gets a trailing newline via `~/.bashrc` for terminal readability.

## Build and Versioning

- Version format: `1.YYYYMMDD.N` (e.g. `1.20250926.4`), set as `VERSION` in
  `Makefile`.
- `make build`: runs `DOCKER_BUILDKIT=1 docker compose build`, tags image as
  `code-server-python:latest` and `code-server-python:$VERSION`.
- `make push`: creates an empty git commit ("Release version $VERSION"), pushes
  to origin, creates and pushes `v$VERSION` git tag.
- `make ver`: prints the current version string.
- `package.json` lists `wscat` as a dev dependency (used for manual WebSocket
  debugging; not included in the image).
