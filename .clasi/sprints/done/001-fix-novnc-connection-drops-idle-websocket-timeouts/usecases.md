---
status: done
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Sprint 001 Use Cases

## SUC-001: Student VNC Session Stays Live Through Idle Periods
Parent: UC-003

- **Actor**: Student (passive — session persists without user action)
- **Preconditions**:
  - Student has an active noVNC session (UC-002 in progress).
  - Container is running the updated image with `websockify --heartbeat=25`
    baked into `app/conf.d/novnc.conf`.
  - Screen is static (no mouse/keyboard activity) for an extended period.
- **Main Flow**:
  1. Student pauses interaction; the VNC framebuffer is static.
  2. `websockify` sends a WebSocket ping frame every 25 seconds.
  3. The browser automatically replies with a pong frame.
  4. Every network intermediary (school firewall, NAT gateway, Cloudflare) sees
     periodic traffic and keeps the connection alive.
  5. Student resumes interaction — the session is still connected; no reload
     is required.
- **Postconditions**:
  - The WebSocket connection remains open indefinitely during idle periods.
  - DevTools → Network → WS shows periodic small ping frames ~25s apart.
  - No WS close code 1006 is observed during a 5+ minute idle hold.
- **Acceptance Criteria**:
  - [ ] `app/conf.d/novnc.conf` `[program:novnc]` command uses
        `websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901`.
  - [ ] After `docker compose build && docker compose up -d`, DevTools WS
        shows ping frames at ~25-second intervals while the VNC screen is idle.
  - [ ] Session remains connected for at least 5 minutes of idle time (previously
        dropped near 60 seconds with close code 1006).

---

## SUC-002: Residual VNC Drop Self-Heals Without Manual Reload
Parent: UC-003

- **Actor**: Student (passive — client reconnects automatically)
- **Preconditions**:
  - Student has an active noVNC session.
  - Container is running with the updated `JTL_VNC_URL` (includes
    `reconnect=true&reconnect_delay=2000&autoconnect=true`).
  - The jtl-syllabus extension passes `JTL_VNC_URL` to the browser verbatim.
- **Main Flow**:
  1. A residual drop occurs (e.g. brief network hiccup, Caddy restart, forced
     close from DevTools).
  2. The WebSocket closes with an unclean close code (1006).
  3. The noVNC client reads the `reconnect=true` and `reconnect_delay=2000`
     query parameters from the URL.
  4. After a 2-second delay the client automatically reconnects to the VNC server.
  5. The VNC session resumes; the student sees a brief screen freeze of ~2s but
     does not need to reload the page.
- **Postconditions**:
  - VNC session restores within ~2 seconds of an unclean close.
  - `JTL_VNC_URL` query params are visible in the browser address bar (or
    inside the extension's constructed URL), confirming passthrough.
- **Acceptance Criteria**:
  - [ ] `docker-compose.yaml` `JTL_VNC_URL` ends with
        `?autoconnect=true&reconnect=true&reconnect_delay=2000`.
  - [ ] Forcing a socket close from DevTools causes the noVNC view to
        reconnect automatically within ~2 seconds, without a manual page reload.
  - [ ] The `reconnect` and `reconnect_delay` params are confirmed present in
        the URL as seen by the browser (passthrough verified).

---

## SUC-003: Edge Infrastructure Confirmed Not Adding Idle Timeouts
Parent: UC-003

- **Actor**: Operator / sprint verifier
- **Preconditions**:
  - Layers 1 and 2 (SUC-001, SUC-002) are deployed and verified.
  - Access to `docker-compose.yaml` Caddy labels and DNS/Cloudflare config.
- **Main Flow**:
  1. Reviewer inspects the Caddy labels in `docker-compose.yaml` for any
     `timeout` or `idle_timeout` directives on the WebSocket route.
  2. Reviewer confirms that Caddy's default behavior for hijacked WebSocket
     connections is no idle timeout.
  3. Reviewer checks whether `codespace.doswarm.jointheleague.org` is fronted
     by Cloudflare (orange-cloud DNS).
  4. If Cloudflare is present: confirms the `--heartbeat=25` interval safely
     beats Cloudflare's ~100s idle WS cap (25s << 100s). No config change needed.
  5. Findings are documented in the ticket.
- **Postconditions**:
  - The audit is documented: Caddy idle-timeout behavior confirmed; Cloudflare
    presence noted with determination of whether any additional action is required.
  - No unaddressed idle-timeout source remains in the infrastructure path.
- **Acceptance Criteria**:
  - [ ] Caddy WebSocket idle-timeout behavior documented (expected: no timeout
        on established WS connections by default).
  - [ ] Cloudflare presence determined for `codespace.doswarm.jointheleague.org`.
  - [ ] If Cloudflare is present, explicit confirmation that `--heartbeat=25`
        defeats the ~100s cap.
  - [ ] Ticket notes indicate whether any further config change is warranted
        (expected: none).
