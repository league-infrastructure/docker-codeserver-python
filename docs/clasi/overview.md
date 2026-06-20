# Docker Codeserver Python — Overview

## What It Is

A Docker image that delivers a browser-accessible Python development environment
for League students. It replicates the GitHub Codespaces experience for students
who cannot obtain or keep GitHub accounts, so every student gets an identical,
zero-install IDE from any browser.

## Who It Is For

- **Students**: access a full IDE and Python runtime from any browser; no local
  install or GitHub account required.
- **Instructors / operators**: build and deploy a single image that is identical
  for every student in a class. The spawner service manages container lifecycle
  and git/storage sync from outside the container.

## What It Provides

- **Browser IDE**: code-server (open-source VS Code) bound on port 80, no
  authentication prompt (`auth: none`), pre-loaded with the JTL Syllabus
  extension, ms-python, and the Jupyter extension.
- **Python environment**: Python 3.12 with pygame, pgzero, guizero, pillow,
  IPython, ipykernel, and the League curriculum library (`jlt_lib`). A Jupyter
  kernel named `codehost` ("Python (League Code Host)") is registered at
  startup and all notebooks in the workspace are updated to use it.
- **Virtual desktop via noVNC**: TigerVNC runs on DISPLAY :0 (Fluxbox window
  manager, 600x600 default). websockify bridges it to a WebSocket on port 6080.
  Students reach it at `/vnc/` through the reverse proxy. Required for graphical
  Python programs (pygame, guizero, tkinter). Known issue: sessions drop on idle
  due to missing WebSocket heartbeat; tracked in `.clasi/issues/`.
- **Automatic repo setup**: on first start, clones the curriculum repo
  (`JTL_REPO`) into `WORKSPACE_FOLDER` and runs a repo-level `.jtl/setup.sh`
  if present. On subsequent starts it `git pull`s instead.
- **Auto-commit and push**: a cron job runs every minute. When workspace
  changes are detected it commits locally and calls back to the code-spawner
  service to perform the actual GitHub push — no student GitHub credentials
  inside the container.
- **rclone storage sync**: `rclone.sh` syncs the workspace to/from an
  S3-compatible object store (DigitalOcean Spaces), invoked by the spawner
  and keyed by class ID and username.
- **Keystroke telemetry (KST)**: the JTL Syllabus VS Code extension reads
  `KST_REPORTING_URL` and `KST_REPORT_INTERVAL` to report student activity.
  These env vars are set in the image defaults and overridden at deploy time;
  no in-container script handles telemetry directly.

## How It Is Built and Run

Built with `make build` (DOCKER_BUILDKIT=1, docker compose), versioned with a
date-based tag (`1.YYYYMMDD.N`). Tagged and pushed with `make push`, which also
creates a git tag. Supervisor (`tini + supervisord`) manages all in-container
processes: code-server, TigerVNC, noVNC/websockify, cron, and a one-shot setup
script. The reverse proxy (Caddy, configured via docker-compose labels)
terminates TLS, routes `/websockify*` and `/vnc/*` to port 6080, and all other
traffic to port 80.
