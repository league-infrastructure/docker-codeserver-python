---
id: '002'
title: Add noVNC client auto-reconnect URL params
status: in-progress
use-cases:
- SUC-002
depends-on: []
github-issue: ''
issue: []
completes_issue: false
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Add noVNC client auto-reconnect URL params

## Description

Even with the Layer 1 heartbeat (Ticket 001), a brief network interruption or
a Caddy restart can produce an unclean WebSocket close. Currently the student
must manually reload the page to reconnect. This ticket appends native noVNC
query parameters to `JTL_VNC_URL` in `docker-compose.yaml` so the noVNC client
reconnects automatically within ~2 seconds of any unclean close.

The stock `novnc` apt package ships `vnc.html`, which reads `reconnect`,
`reconnect_delay`, and `autoconnect` from `URLSearchParams` at page load. No
custom JS or HTML changes are required. This is the client-side backstop
(Layer 3).

An important verification is required: `JTL_VNC_URL` is consumed by the
jtl-syllabus VS Code extension. If the extension reconstructs the URL
programmatically rather than passing it verbatim, the query params never reach
the browser and Layer 3 is silently ineffective. This must be checked.

## Files to Modify

- `docker-compose.yaml`

## Implementation Plan

### Step 1 — Update `JTL_VNC_URL` in docker-compose.yaml

In the `environment:` block of the `devcontainer` service (line 23), change:

```yaml
- JTL_VNC_URL=https://codespace.doswarm.jointheleague.org/vnc/
```

To:

```yaml
- JTL_VNC_URL=https://codespace.doswarm.jointheleague.org/vnc/?autoconnect=true&reconnect=true&reconnect_delay=2000
```

Parameter meanings (native noVNC `vnc.html` query-string settings):
- `autoconnect=true` — connect immediately on page load; no manual "Connect"
  button click required.
- `reconnect=true` — attempt to reconnect on unclean close.
- `reconnect_delay=2000` — wait 2000ms (2 seconds) before reconnecting.

### Step 2 — Verify URL passthrough (critical check)

This step determines whether Layer 3 actually works in production.

The jtl-syllabus extension reads `JTL_VNC_URL` and opens the VNC view.
Two possible behaviours:

**Case A — verbatim passthrough**: the extension opens the URL exactly as
provided, including the query string. The params appear in the browser
address bar or in the WS connection URL visible in DevTools. Layer 3 works.

**Case B — query string stripped or rebuilt**: the extension parses the URL
and reconstructs it without the query string, or opens a hard-coded path.
The params never reach `vnc.html`. Layer 3 is silently ineffective.

To verify: after deploying, open the VNC panel via the extension. In DevTools
→ Network → WS (or by inspecting the tab URL), confirm `reconnect=true` and
`reconnect_delay=2000` are present in the URL.

If Case B is confirmed:
- Document the finding in this ticket's notes.
- File a follow-on CLASI issue for the jtl-syllabus extension repo.
- Layer 3 cannot be completed within this sprint; note it for the team-lead.

### Step 3 — Test auto-reconnect (only if passthrough confirmed)

1. Open the VNC desktop via the extension.
2. Confirm the WS URL or tab URL contains the reconnect params.
3. In DevTools → Network → WS, force-close the socket (right-click → Close)
   or restart Caddy.
4. Observe: the noVNC view should briefly show a disconnection state, then
   reconnect within ~2 seconds — without a manual page reload.

## Static Analysis Finding

**Case A — verbatim passthrough confirmed.**

File: `extension/out/virtdisplay.js` (inside `jtl-syllabus-1.20250618.1.vsix`)

```
line 42:  let vncUrl = process.env.JTL_VNC_URL;
line 52:  await vscode.commands.executeCommand('simpleBrowser.api.open', vncUrl, {
```

The extension reads `JTL_VNC_URL` verbatim from the environment and passes it
directly to `simpleBrowser.api.open` without any parsing, reconstruction, or
stripping of the query string. The query params (`autoconnect`, `reconnect`,
`reconnect_delay`) will be present in the URL loaded by the Simple Browser
webview. Layer 3 will work as designed.

No `new URL()`, `URL()` constructor, or string rebuild is present in the
relevant code path — the value flows straight through.

## Acceptance Criteria

- [x] `docker-compose.yaml` `JTL_VNC_URL` value ends with
      `?autoconnect=true&reconnect=true&reconnect_delay=2000`.
- [x] The query params are confirmed present in the URL as seen by the browser
      when the VNC panel is opened via the jtl-syllabus extension (passthrough
      verified — **Case A confirmed by static analysis of VSIX bundle**;
      live browser check pending stakeholder deployment).
- [ ] If passthrough is confirmed: a forced socket close causes the noVNC view
      to reconnect automatically within ~2 seconds, without a manual page reload.
      **Pending stakeholder deployment — live forced-reconnect test required.**

## Testing

No automated tests exist for this project's configuration. All verification
is manual.

**Config correctness check** (before deploy):
- Verify the `JTL_VNC_URL` line in `docker-compose.yaml` matches the acceptance
  criteria exactly.

**Manual verification (post-deploy)**:
1. `docker compose up -d` (env-var change takes effect on container restart;
   no image rebuild required for this ticket alone).
2. Open VS Code in the browser; use the JTL Syllabus extension to open the
   VNC panel.
3. Inspect the VNC tab URL or DevTools → Network → WS frame URL for the
   query params.
4. If params present (Case A): force-close the WebSocket (DevTools) and
   observe auto-reconnect within ~2s.
5. If params absent (Case B): document the finding; file a follow-on issue.
