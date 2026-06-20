# Docker Codeserver Python — Use Cases

## UC-001: Student Opens Browser IDE

**Actor**: Student

**Preconditions**:
- Container is running and reachable at the public domain (e.g.
  `codespace.doswarm.jointheleague.org`).
- Caddy reverse proxy is up and routing `/*` to port 80.

**Main Flow**:
1. Student navigates to the public URL in any browser.
2. Caddy routes the request to code-server on port 80 (no login prompt;
   `auth: none` in `/app/code-server.yaml`).
3. code-server serves the VS Code UI.
4. The workspace (`WORKSPACE_FOLDER`) is open. The curriculum repo has already
   been cloned by `setup.sh`.
5. Student writes and edits Python files. Files autosave after 1 second
   (`files.autoSave: afterDelay`, `files.autoSaveDelay: 1000`).

**Postconditions**: Student is in a fully functional VS Code environment with
Python (`ms-python.python`), Jupyter (`ms-toolsai.jupyter`), and the JTL
Syllabus extension (`jtl-syllabus`) available.

**Error Flows**:
- Container not yet started: browser shows connection error or Caddy 502.
- `setup.sh` still running: workspace may be empty until the clone completes.
  code-server starts at supervisor priority 20; setup also runs at priority 10
  but as a one-shot script — a race is possible on first start if cloning is
  slow.

---

## UC-002: Student Runs a Graphical Python Program

**Actor**: Student

**Preconditions**:
- UC-001 completed; student has a Python file using pygame, pgzero, or guizero.
- Container `novnc` supervisor group is running (tigervnc on DISPLAY :0,
  websockify on port 6080).

**Main Flow**:
1. Student opens the integrated terminal in code-server and runs their script
   (e.g. `python3 my_game.py`), or uses the VS Code launch config "Python
   Debugger: Current File" (`/app/vsc/launch.json`).
2. The program opens a window on DISPLAY :0 (TigerVNC virtual framebuffer).
3. Student opens the VNC URL (surfaced by the JTL Syllabus extension via
   `JTL_VNC_URL`) in a new browser tab.
4. The noVNC client loads and connects over WebSocket to port 6080.
5. Caddy routes `/websockify*` to port 6080 (WebSocket upgrade headers required).
6. The virtual desktop (600x600 default) is streamed; student interacts with
   the running graphical app via mouse and keyboard.

**Postconditions**: Student can see and interact with their graphical program
in the browser without any local install.

**Error Flows**:
- TigerVNC crashed: supervisord restarts it automatically (`autorestart=true`).
  Stale X sockets may cause a restart loop; `desktop-preflight` cleans them
  at startup but not mid-session.
- `DISPLAY` not set or wrong: graphical apps fail with "cannot connect to
  X server". Mitigation: `DISPLAY=:0.0` is set as an image-level env var.
- noVNC page shows blank/non-connecting view: check that Caddy is sending
  `X-Forwarded-Proto: https` and that `JTL_VNC_URL` uses `wss://` when the
  page is served over HTTPS.

---

## UC-003: noVNC Session Drops Due to Idle Timeout

**Actor**: Student (passive — session drops without user action)

**Preconditions**:
- Student has an active noVNC session (UC-002 in progress).
- Screen is static (no mouse/keyboard activity for an extended period).
- A network intermediary (school firewall, NAT gateway, Cloudflare) has an
  idle WebSocket timeout (commonly 60 s).

**Main Flow**:
1. Screen is idle; no RFB bytes flow on the WebSocket connection.
2. After the intermediary's idle timeout (typically ~60 s), it closes the
   socket with WebSocket close code **1006** (abnormal, no close frame).
3. The noVNC client in the browser loses the connection; the VNC screen freezes.
4. Student reloads the page to reconnect.

**Postconditions (current, unfixed)**: Student must manually reload. The Xvnc
display server is unaffected and resumes immediately after reconnect.

**Desired Postconditions (after fix from `.clasi/issues/`)**:
- `websockify` runs with `--heartbeat=25` (replaces `novnc_proxy` in
  `app/conf.d/novnc.conf`), sending a WebSocket ping every 25 s to prevent
  any intermediary from seeing an idle socket.
- `JTL_VNC_URL` includes `reconnect=true&reconnect_delay=2000` so the noVNC
  client auto-reconnects on any residual unclean close without a manual reload.

**Error Flows**:
- If close code is 1000/1001 (clean close), the cause is a deliberate
  application or session-manager shutdown; the heartbeat does not help.
  Check for an app-level inactivity timer or VNC server started without
  `-forever`.

---

## UC-004: Student Work Auto-Commits and Pushes

**Actor**: Cron / spawner service (automated)

**Preconditions**:
- Container is running.
- `JTL_SPAWNER_URL`, `JTL_USERNAME`, and `JTL_HOST_UUID` are set.
- `~/env.sh` was written by `setup.sh` (exports those three vars plus
  `WORKSPACE_FOLDER`).

**Main Flow**:
1. Every minute, cron runs `/app/bin/push.sh` as user `vscode`.
2. Script sources `~/env.sh` for env vars.
3. `git add -A` stages all changes in `WORKSPACE_FOLDER`.
4. If the diff is non-empty, commits with message "Auto-commit: workspace
   changes before push".
5. Script GETs
   `$JTL_SPAWNER_URL/host/$JTL_USERNAME/push?host_uuid=$JTL_HOST_UUID`.
6. The spawner (external service) performs the actual GitHub push using its
   own credentials.

**Postconditions**: Student work is committed locally and pushed to GitHub
within ~1 minute of the last change, without any GitHub credentials stored
in the container. Output logged to `/tmp/push.log`.

**Error Flows**:
- `JTL_SPAWNER_URL` not set: `~/env.sh` exports an empty value; the `curl`
  call targets an empty URL and silently fails (logged to `/tmp/push.log`).
- No changes in workspace: script logs "No changes to commit; skipping push."
  and exits cleanly.
- Network error reaching spawner: `curl` exits non-zero; logged but does not
  affect the next cron run.

---

## UC-005: Operator Builds and Releases a New Image Version

**Actor**: Instructor / infrastructure engineer

**Preconditions**:
- Docker, docker compose, and BuildKit available on the build machine.
- `Makefile` `VERSION` updated to the new date-based tag (`1.YYYYMMDD.N`).
- Git working tree is on the master branch.

**Main Flow**:
1. Engineer runs `make build`:
   - `DOCKER_BUILDKIT=1 docker compose build` builds the image.
   - Tags as `code-server-python:latest` and `code-server-python:$VERSION`.
2. Engineer runs `make push`:
   - Creates an empty git commit: "Release version $VERSION".
   - Pushes to origin.
   - Creates and pushes git tag `v$VERSION`.
3. CI/CD or the engineer deploys the new image to the container host.

**Postconditions**: A versioned, reproducible image is available and the git
tag marks the exact source state for the release.

**Error Flows**:
- JTL Syllabus VSIX is outdated: the new `.vsix` must be copied into
  `app/extensions/` and the `--install-extension` line in `Dockerfile` updated
  to the new filename before building.
- BuildKit unavailable: remove `DOCKER_BUILDKIT=1` prefix and accept slower
  legacy build.

---

## UC-006: Container Clones Curriculum Repo on First Start

**Actor**: System (`setup.sh`, triggered by supervisord on container start)

**Preconditions**:
- `JTL_REPO` env var is set to a valid Git URL.
- `WORKSPACE_FOLDER` directory does not yet contain a git repository.

**Main Flow**:
1. `setup.sh` runs as user `vscode` at supervisord priority 10.
2. `WORKSPACE_FOLDER` does not exist or is not a git repo:
   `git clone --depth 1 $JTL_REPO $WORKSPACE_FOLDER`.
3. `setup.sh` looks for `${WORKSPACE_FOLDER}/.jtl/setup.sh` (or the path in
   `$SETUP_SCRIPT` if set, resolved as `${WORKSPACE_FOLDER}/${SETUP_SCRIPT}`).
4. If found, runs it with the workspace path as the first argument.
5. Merges `/app/vsc/workspace-settings.json` into
   `${WORKSPACE_FOLDER}/.vscode/settings.json` via `jq`.
6. Installs ipykernel: `python -m ipykernel install --user --name codehost`.
7. Runs `updateks.py codehost` to set the kernelspec in all `.ipynb` files
   in the workspace (backs each up as `*.ipynb.bak.<timestamp>`).

**Postconditions**: Workspace contains the curriculum repo. VS Code opens to
the correct folder with the `codehost` kernel pre-selected for all notebooks.

**Error Flows**:
- `JTL_REPO` not set: `setup.sh` logs "JTL_REPO is not set" and skips cloning.
- Clone fails (network error, bad URL): workspace is empty; code-server opens
  to an empty workspace folder.
- Repo already exists (container restart): `setup.sh` runs `git pull` instead
  of cloning. The `.jtl/setup.sh` is NOT re-run on pull.
- `SETUP_SCRIPT` set but file missing: `setup.sh` skips it silently (guarded
  by `if [ -f "$SETUP_SCRIPT" ]`).

---

## UC-007: Spawner Syncs Workspace to Object Storage

**Actor**: Code-spawner service (external, calls into the container)

**Preconditions**:
- `STORAGE_BUCKET`, `STORAGE_ENDPOINT`, `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `JTL_CLASS_ID`, `JTL_USERNAME`, and
  `WORKSPACE_FOLDER` are set.
- `rclone` is installed in the container (via install script in `Dockerfile`).

**Main Flow**:
1. Spawner calls `/app/bin/rclone.sh {copy|sync} {in|out}` inside the container.
2. Script strips scheme from `STORAGE_ENDPOINT` to get the bare hostname.
3. Builds remote key:
   `$STORAGE_BUCKET/class_$JTL_CLASS_ID/$JTL_USERNAME$WORKSPACE_FOLDER`.
4. Executes `rclone {copy|sync}` in the specified direction using an inline
   DigitalOcean S3 backend (`provider=DigitalOcean,env_auth=true`).
5. rclone outputs progress at `INFO` log level.

**Postconditions**:
- Sync out: workspace files are persisted to object storage.
- Sync in: workspace files are restored from object storage.

**Error Flows**:
- Missing required env var: script exits immediately with `parameter not set`
  error (uses `${VAR:?message}` guard).
- Invalid first or second argument: script prints usage and exits 1.
- Storage credentials invalid or endpoint unreachable: rclone exits non-zero;
  spawner receives the error.

---

## UC-008: Student Runs a Jupyter Notebook

**Actor**: Student

**Preconditions**:
- UC-001 completed; student has a `.ipynb` file in the workspace.
- `setup.sh` has completed (ipykernel `codehost` registered; notebook
  kernelspecs updated by `updateks.py`).
- `ms-toolsai.jupyter` extension is installed.

**Main Flow**:
1. Student opens a `.ipynb` file in code-server.
2. VS Code uses the `ms-toolsai.jupyter` extension to render the notebook.
3. The kernel selector shows "Python (League Code Host)" as the pre-selected
   kernel (set by `updateks.py`; `/bin/python3` and `/usr/bin/python3` are
   excluded from the selector via `workspace-settings.json`).
4. Student runs cells; the kernel executes them on `/usr/local/bin/python3`.
5. Cells that produce graphical output render inline (IPython / Matplotlib);
   cells using pygame/guizero open a window on DISPLAY :0 (viewable via
   noVNC per UC-002).

**Postconditions**: Student can run interactive Python notebooks with full
curriculum library access.

**Error Flows**:
- `setup.sh` not yet finished when student opens notebook: kernel may not be
  registered; student sees an empty kernel list. Reload VS Code window once
  setup completes.
- Kernel crashes: VS Code shows "Kernel died" banner; student restarts the
  kernel from the toolbar.
- Notebook kernelspec not updated (e.g. `updateks.py` failed on a malformed
  notebook): VS Code prompts to select a kernel manually.
