---
id: '001'
title: Fix noVNC connection drops / idle WebSocket timeouts
status: done
branch: sprint/001-fix-novnc-connection-drops-idle-websocket-timeouts
use-cases:
- UC-003
issues:
- plan-apply-the-novnc-timeout-fixes-from-fixing-novnc-timeouts-md.md
- fixing-novnc-timeouts.md
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Sprint 001: Fix noVNC connection drops / idle WebSocket timeouts

## Goals

Eliminate idle-drop disconnects from the in-browser VNC desktop so students
are not interrupted mid-session, and make any residual drop self-heal without
a manual page reload.

## Problem

Students using the noVNC virtual desktop (UC-002) experience session drops when
the screen is static for more than ~60 seconds. A page reload instantly restores
the connection, which is the signature of an **idle WebSocket timeout** — a
network intermediary (school firewall, NAT gateway, or Cloudflare edge) closes
a connection it perceives as dead because no RFB bytes are flowing on a static
screen. The root cause is that `websockify` is currently started via the
`novnc_proxy` wrapper **without a `--heartbeat` flag**, so the socket appears
idle to every hop in the path.

## Solution

Three layers, applied in order of impact:

1. **Server heartbeat (primary fix)** — replace the `novnc_proxy` invocation in
   `app/conf.d/novnc.conf` with a direct `websockify --heartbeat=25` call. This
   sends a WebSocket ping every 25 seconds, defeating every idle-timeout hop
   including those outside our control (school firewalls, Cloudflare's ~100s
   WS cap). This is the only layer that addresses hops we don't own.

2. **Client auto-reconnect (backstop)** — append `reconnect=true`,
   `reconnect_delay=2000`, and `autoconnect=true` to `JTL_VNC_URL` in
   `docker-compose.yaml`. These are native noVNC `vnc.html` query parameters
   that cause the client to reconnect automatically on any residual unclean
   close, so a drop is a brief blip rather than a frozen screen.

3. **Caddy / edge verification (audit)** — confirm that Caddy does not impose an
   idle timeout on established WebSocket connections (it does not by default) and
   determine whether `codespace.doswarm.jointheleague.org` is fronted by
   Cloudflare. Document findings; act only if the review reveals an actual
   timeout not covered by Layer 1.

## Success Criteria

- DevTools → Network → WS shows periodic ping frames (~25s apart) while the VNC
  screen is idle.
- An idle session remains connected for 5+ minutes without dropping (previously
  dropped with WS close code 1006 near the 60s mark).
- A forced drop (socket closed from DevTools or Caddy restart) reconnects
  automatically within ~2 seconds, without a manual page reload.
- `JTL_VNC_URL` query params survive into the browser address bar (i.e. the
  jtl-syllabus extension passes the URL through verbatim).
- Caddy / Cloudflare findings documented; no unaddressed idle-timeout source
  remains.

## Scope

### In Scope

- `app/conf.d/novnc.conf` — switch `[program:novnc]` command to direct
  `websockify --heartbeat=25`; fix stale comment (":1" → ":0").
- `docker-compose.yaml` — append reconnect query params to `JTL_VNC_URL`.
- Caddy label review (read-only audit; change only if a real idle timeout is
  found).
- End-to-end manual verification: rebuild image, confirm ping frames, idle test
  (5+ min), forced-drop reconnect test, URL passthrough check.

### Out of Scope

- Changes to TigerVNC configuration or the virtual display setup.
- Changes to the jtl-syllabus VS Code extension (if query strings are stripped,
  that is a separate issue in that repo).
- nginx, Traefik, HAProxy, Kubernetes ingress, or AWS ALB configuration (not
  used in this stack).
- Authentication, user accounts, or session management.
- Any other supervisor programs beyond `[program:novnc]`.

## Test Strategy

This is a Docker/supervisor/Caddy configuration sprint. There is no pytest suite
to run. Acceptance is established through:

1. **Config correctness** — reviewer verifies the `novnc.conf` command line and
   `docker-compose.yaml` env var against the acceptance criteria in each ticket.
2. **Image rebuild** — `docker compose build && docker compose up -d` (or
   equivalent swarm deploy) to bake the new `novnc.conf` into the image (required
   because `COPY ./app /app` runs at build time).
3. **Observable behavior** — DevTools WS ping frames, 5-minute idle hold, forced
   reconnect, URL passthrough.

## Architecture Notes

- `websockify` is already on `PATH` inside the container — it is pulled in as a
  dependency of the `novnc` apt package (`python3-websockify`). No new package
  installations are needed.
- The `--web /usr/share/novnc` flag preserves serving the noVNC HTML client from
  the same port. The positional args `6080 localhost:5901` preserve the existing
  listen-port → RFB-target routing.
- `user=root` in the supervisor program block is retained (the wrapper ran as
  root; websockify needs the same permissions to bind port 6080).
- The `novnc_proxy` wrapper is just a shell script that ultimately calls
  `websockify`; switching to the direct invocation with `--heartbeat` is
  functionally equivalent in every respect except the flag now lands reliably.
- Caddy WebSocket handling: Caddy hijacks the connection after the HTTP Upgrade
  handshake and streams it without imposing an idle timeout. The existing labels
  in `docker-compose.yaml` already include the WebSocket upgrade headers
  (`caddy.@ws.0_header`, `caddy.@ws.1_header`) and route `/websockify*` to
  port 6080.

## GitHub Issues

(None — tracked via CLASI issues only.)

## Definition of Ready

Before tickets can be created, all of the following must be true:

- [ ] Sprint planning documents are complete (sprint.md, use cases, architecture)
- [ ] Architecture review passed
- [ ] Stakeholder has approved the sprint plan

## Tickets

| # | Title | Depends On |
|---|-------|------------|
| 001 | Add websockify heartbeat to supervisor config | — |
| 002 | Add noVNC client auto-reconnect URL params | — |
| 003 | Verify Caddy and edge idle-timeout handling | 001, 002 |

Tickets execute serially in the order listed.
