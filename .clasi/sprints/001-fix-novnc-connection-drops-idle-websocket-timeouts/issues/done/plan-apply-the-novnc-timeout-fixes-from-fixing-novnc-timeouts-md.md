---
status: done
sprint: '001'
tickets:
- 001-001
- 001-002
- 001-003
---

# Plan: Apply the noVNC timeout fixes from `fixing-novnc-timeouts.md`

## Context

Users have **confirmed** the symptom the issue doc describes: the in-browser VNC desktop
freezes/drops and a page reload instantly restores it. That "reload fixes it" signature is
an **idle WebSocket timeout** — VNC/RFB sends zero bytes when the screen is static, so a
network hop (most likely a **school/corporate firewall or NAT** we don't control, possibly
also a Cloudflare/edge layer) closes the "dead" socket.

The issue doc (`.clasi/issues/fixing-novnc-timeouts.md`) is a correct, generic guide. Reviewed
against our actual stack, it maps as follows:

- **Layer 1 (server heartbeat)** — real, applicable gap. Our proxy runs with **no `--heartbeat`**.
  This is the only layer that defeats a hop we don't own, so it is the primary fix.
- **Layer 2 (proxy idle timeout)** — the doc omits **Caddy**, which is what we actually use.
  Caddy does **not** impose an idle timeout on an established WebSocket by default, so no Caddy
  config change is expected; the work here is to **verify** that and check for a Cloudflare edge.
- **Layer 3 (client auto-reconnect)** — applicable, but our stock noVNC client supports it via
  **URL query params**, not the custom `RFB` JS the doc shows.

Outcome: idle VNC sessions stay alive indefinitely, and any residual drop self-heals without a
manual reload.

## Files & changes

### Layer 1 — server heartbeat (the real fix)
**File:** [app/conf.d/novnc.conf](app/conf.d/novnc.conf#L12-L14)

Replace the `[program:novnc]` `command=` line. Switch from the `novnc_proxy` wrapper (which is
not guaranteed to forward `--heartbeat` to websockify) to calling `websockify` directly — this
is exactly what the wrapper does internally, but with the flag guaranteed to land:

```
; before
command=/usr/share/novnc/utils/novnc_proxy --listen 6080 --vnc localhost:5901
; after
command=websockify --heartbeat=25 --web /usr/share/novnc 6080 localhost:5901
```

- `websockify` is on `PATH` (provided by `python3-websockify`, a dependency of the `novnc`
  apt package — [Dockerfile:34](Dockerfile#L34)). Keep `user=root` as-is.
- `--web /usr/share/novnc` preserves serving the noVNC HTML client; positional `6080 localhost:5901`
  preserves listen-port → RFB-target. Behavior is equivalent to the old wrapper line.
- `--heartbeat=25` sends a WS ping every 25s (safely beats a 60s limit; well under Cloudflare's
  ~100s). If the idle test below still drops before ~60s, lower to `15` for very aggressive firewalls.
- While here, fix the stale comment on [novnc.conf:1](app/conf.d/novnc.conf#L1) ("DISPLAY :1" → `:0`).

### Layer 3 — client auto-reconnect (backstop)
**File:** [docker-compose.yaml:23](docker-compose.yaml#L23) — `JTL_VNC_URL`

Append stock-noVNC query params so a residual drop reconnects on its own instead of needing a reload:

```
- JTL_VNC_URL=https://codespace.doswarm.jointheleague.org/vnc/?autoconnect=true&reconnect=true&reconnect_delay=2000
```

- `reconnect=true` + `reconnect_delay=2000` are native `vnc.html` settings read from the query
  string; `autoconnect=true` keeps the view connecting without a manual "Connect" click.
- **Verify the consumer passes the URL through verbatim.** `JTL_VNC_URL` is consumed by the
  jtl-syllabus extension ([Dockerfile:81](Dockerfile#L81)), not by this repo. If the extension
  strips or rebuilds the query string, the params must instead be set where the extension opens
  the URL. Confirm during testing that the params survive into the browser address.

### Layer 2 — Caddy / edge review (verify, likely no change)
**File:** [docker-compose.yaml:30-46](docker-compose.yaml#L30-L46) (Caddy labels)

- Confirm Caddy is not closing idle WebSockets: Caddy streams hijacked WS connections with no
  idle timeout by default, so **no label change is expected**. Document this conclusion.
- Determine whether `codespace.doswarm.jointheleague.org` is fronted by **Cloudflare** (orange-cloud).
  If yes, its ~100s idle WS limit applies — but `--heartbeat=25` from Layer 1 already defeats it,
  so still no config change is needed. Note the finding either way; only act (grey-cloud / Spectrum)
  if drops persist after Layers 1 & 3.

## Process note (CLASI)

The repo is under the CLASI SE process (team-lead role) but the project is `uninitialized` with no
active sprint. These are small, targeted config edits. Recommend handling them **out of process** —
either create `.clasi/oop` or get an explicit "direct change" OK from the stakeholder — rather than
standing up a sprint. Confirm before editing.

## Verification (end-to-end)

1. Rebuild and redeploy so the new `novnc.conf` is baked in (`COPY ./app /app`,
   [Dockerfile:51](Dockerfile#L51)): `docker compose build && docker compose up -d`
   (or the equivalent swarm/doswarm deploy).
2. Open the VNC desktop. In **DevTools → Network → WS**, select the websockify socket and confirm
   small **ping frames every ~25s** while the screen is idle.
3. **Idle test:** connect and leave it completely untouched for **5+ minutes** — it should stay live
   (previously it dropped near the shortest path timeout with WS close code **1006**).
4. **Reconnect test:** force a drop (close the socket from DevTools, or restart Caddy) — the view
   should reconnect within ~2s **without a manual reload** (Layer 3).
5. Confirm `JTL_VNC_URL`'s query params actually reach the browser (Layer 3 only works if they do).
6. Record the Layer 2 finding (Caddy default OK; Cloudflare present or not).
