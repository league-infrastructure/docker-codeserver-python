---
id: '001'
title: Add websockify heartbeat to supervisor config
status: done
use-cases:
- SUC-001
depends-on: []
github-issue: ''
issue:
- plan-apply-the-novnc-timeout-fixes-from-fixing-novnc-timeouts-md.md
- fixing-novnc-timeouts.md
completes_issue: false
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Add websockify heartbeat to supervisor config

## Description

The noVNC supervisor program (`[program:novnc]` in `app/conf.d/novnc.conf`)
currently starts the WebSocket proxy using the `novnc_proxy` shell wrapper
without a `--heartbeat` flag. When the VNC screen is static, no RFB bytes
flow on the WebSocket, causing network intermediaries (school firewalls, NAT
gateways, Cloudflare) to close the connection with WS close code 1006.

This ticket replaces the `novnc_proxy` invocation with a direct `websockify`
call that includes `--heartbeat=25`. Websockify then sends a WebSocket ping
every 25 seconds, keeping the connection alive through every hop in the path,
including hops outside our control. This is the primary fix for UC-003.

`websockify` is already on PATH inside the container (installed as
`python3-websockify`, a dependency of the `novnc` apt package).

## Files to Modify

- `app/conf.d/novnc.conf`

## Implementation Plan

### Step 1 — Fix the stale display comment (line 1)

The existing comment reads `:1`; the actual display is `:0` (confirmed by
the `tigervnc` command using `:0` and by `DISPLAY=:0.0` in the Dockerfile).

Change:
```
; --- TigerVNC built-in server on DISPLAY :1 ---
```
To:
```
; --- TigerVNC built-in server on DISPLAY :0 ---
```

### Step 2 — Replace the `[program:novnc]` command line

Change:
```
command=/usr/share/novnc/utils/novnc_proxy --listen 6080 --vnc localhost:5901
```
To:
```
command=websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901
```

Flag-by-flag equivalence:
- `--heartbeat=25` — sends a WebSocket ping every 25 seconds (new; the fix).
- `--web /usr/share/novnc` — serves the noVNC HTML client from this directory
  (equivalent to `novnc_proxy`'s default web root).
- `6080` — listen port (was `--listen 6080`).
- `localhost:5901` — RFB target (was `--vnc localhost:5901`).

All other fields in `[program:novnc]` are unchanged: `user=root`,
`autorestart=true`, log file paths.

### Step 3 — Rebuild and redeploy

`app/conf.d/novnc.conf` is baked into the image at build time via
`COPY ./app /app` (Dockerfile line 51). The change has no effect until
the image is rebuilt:

```
docker compose build
docker compose up -d
```

Or the equivalent swarm/doswarm deploy for the production environment.

## Acceptance Criteria

- [x] `app/conf.d/novnc.conf` line 1 comment reads `:0` (not `:1`).
- [x] `[program:novnc]` `command=` line is exactly:
      `websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901`
- [x] All other fields in `[program:novnc]` are unchanged (`user=root`,
      `autorestart=true`, log paths).
- [ ] After `docker compose build && docker compose up -d`, DevTools → Network →
      WS shows periodic small ping frames at approximately 25-second intervals
      while the VNC screen is idle.
      _(pending-deploy: live browser verification requires a running container; team-lead is tracking)_
- [ ] An idle VNC session remains connected for at least 5 continuous minutes
      (previously disconnected near 60 seconds with close code 1006).
      _(pending-deploy: live browser verification requires a running container; team-lead is tracking)_

## Testing

No automated tests exist for this project's configuration. All verification
is manual.

**Config correctness check** (before rebuild):
- Visually verify the two edited lines match the acceptance criteria.
- DONE: Both edited lines confirmed correct by re-reading the file after edit.

**Live browser verification**: pending stakeholder deployment — a running
container with a browser is required and is not available in this environment.
The team-lead is tracking the live-browser acceptance criteria.

**Manual verification (post-rebuild)**:
1. `docker compose build && docker compose up -d`
2. Open the VNC desktop in a browser.
3. Open DevTools → Network → WS, select the websockify socket.
4. Wait 30+ seconds with no mouse/keyboard activity.
5. Confirm small ping frames appear at ~25-second intervals in the WS frame list.
6. Leave connected for 5+ minutes idle — confirm no disconnect (no close code
   1006, no page freeze).

**Fallback**: if the session still drops before 60 seconds, lower `--heartbeat`
from 25 to 15 (very aggressive firewall) and rebuild. This is a single number
edit; no other change is needed.
