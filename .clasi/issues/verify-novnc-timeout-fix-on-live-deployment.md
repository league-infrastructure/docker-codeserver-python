---
status: pending
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Verify noVNC timeout fix on live deployment

## Description

Sprint 001 (closed, tag `v0.20260619.1`) implemented and **statically** verified
the noVNC idle-timeout fix, but the live-browser acceptance tests require a
deployed container and could not be run in the dev environment. This issue
tracks that post-deploy verification.

**What sprint 001 changed:**
- `app/conf.d/novnc.conf` — the `[program:novnc]` command now runs
  `websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901`
  (a WebSocket ping every 25s so the connection is never idle).
- `docker-compose.yaml` — `JTL_VNC_URL` now carries
  `?autoconnect=true&reconnect=true&reconnect_delay=2000` (stock-noVNC
  client auto-reconnect backstop).

## Verification steps (run after deploying the v0.20260619.1 image)

1. **Rebuild + deploy:** `docker compose build && docker compose up -d`
   (or the swarm/doswarm production deploy). The heartbeat change is baked
   into the image (`COPY ./app /app`), so a rebuild is required — a plain
   restart is not enough.
2. **Heartbeat present:** open the VNC desktop, DevTools → Network → WS →
   select the websockify socket; confirm small ping frames at ~25s intervals
   while the screen is idle.
3. **Idle hold:** leave the session completely untouched for 5+ minutes;
   confirm it stays live (previously dropped near 60s with WS close code 1006).
4. **Auto-reconnect:** force a socket close (DevTools → Close, or restart
   Caddy); confirm the noVNC view reconnects within ~2s **without** a manual
   page reload.
5. **Param passthrough (live confirm):** confirm the `reconnect`/`reconnect_delay`
   params actually appear in the URL when the VNC panel is opened via the
   jtl-syllabus extension. Static VSIX analysis found **Case A — verbatim
   passthrough** (`extension/out/virtdisplay.js` passes `JTL_VNC_URL` straight
   to `simpleBrowser.api.open`); confirm it live.

## Fallback

If the session still drops before ~60s despite the heartbeat, lower
`--heartbeat` from `25` to `15` in `app/conf.d/novnc.conf` and rebuild
(single-number edit; aggressive-firewall case).

## Context

The hostname `codespace.doswarm.jointheleague.org` resolves to a DigitalOcean
IP (grey-cloud, **not** Cloudflare — confirmed in sprint 001, ticket 003), so
the most likely original drop cause is a **school firewall / NAT idle timeout**
— exactly the uncontrolled hop that the server-side websockify heartbeat
defeats. Caddy was confirmed to impose no idle timeout on established
WebSockets, so no proxy-layer change was needed.

Related: sprint 001 (`.clasi/sprints/done/001-fix-novnc-connection-drops-idle-websocket-timeouts/`).
