---
id: '003'
title: Verify Caddy and edge idle-timeout handling
status: done
use-cases:
- SUC-003
depends-on:
- '001'
- '002'
github-issue: ''
issue: []
completes_issue: true
---
<!-- CLASI: Before changing code or making plans, review the SE process in CLAUDE.md -->

# Verify Caddy and edge idle-timeout handling

## Description

This is a verification and documentation ticket. Tickets 001 and 002 address
the websockify heartbeat and client reconnect layers. This ticket confirms that
no idle timeout exists within our own infrastructure (Caddy) that would
independently close idle WebSocket connections, and determines whether
Cloudflare is in the path.

Expected outcome: no config changes are needed. The purpose is to close the
audit loop so the team knows the full idle-timeout picture of this stack.
This ticket also contains the definitive end-to-end idle test (5+ minutes)
that closes the sprint.

## Depends On

Tickets 001 and 002 must be deployed and verified before running this ticket,
so the full end-to-end idle behaviour is observable during the 5-minute idle
test.

## Verification Plan

### Step 1 — Caddy WebSocket idle-timeout review

Inspect the Caddy labels in `docker-compose.yaml` (lines 30–46). The relevant
WebSocket labels are:

```yaml
caddy.@ws.0_header: Connection *Upgrade*
caddy.@ws.1_header: Upgrade websocket
caddy.0_route.handle: /websockify*
caddy.0_route.handle.reverse_proxy: "@ws {{upstreams 6080}}"
```

Caddy's behavior for hijacked WebSocket connections: after the HTTP Upgrade
handshake, Caddy streams the connection without imposing an additional idle
timeout. There is no `timeout` or `idle_timeout` directive in the current
label set that applies post-upgrade. Confirm this is the case and document it.

**Expected finding**: "Caddy does not impose an idle timeout on established
WebSocket connections with the current label configuration. No label change
is needed."

If a Caddy label is found that could impose an idle timeout shorter than 25
seconds — document it and escalate to team-lead; do not silently change labels.

### Step 2 — Cloudflare presence check

Determine whether `codespace.doswarm.jointheleague.org` is fronted by
Cloudflare's proxy (orange-cloud).

**DNS method**:
```bash
dig codespace.doswarm.jointheleague.org +short
```
If the resolved IPs belong to Cloudflare's ranges (104.x.x.x, 172.64.x.x,
198.41.x.x), Cloudflare is proxying. Check the Cloudflare dashboard for the
DNS record's proxy status if you have access.

**HTTP header method**:
```bash
curl -sI https://codespace.doswarm.jointheleague.org | grep -i "cf-ray\|server"
```
A `cf-ray:` header or `server: cloudflare` confirms Cloudflare is proxying.

**If Cloudflare IS proxying (orange-cloud)**:
- Cloudflare imposes an idle WebSocket timeout of approximately 100 seconds.
- `--heartbeat=25` (Ticket 001) sends a ping every 25 seconds — safely under
  the ~100s cap.
- No config change needed.
- Document: "Cloudflare is present (orange-cloud); `--heartbeat=25` defeats
  the ~100s idle cap (25s << 100s). No action required."

**If Cloudflare is NOT proxying (grey-cloud / DNS only)**:
- Cloudflare's idle cap does not apply.
- Document: "Cloudflare DNS-only (grey-cloud); no Cloudflare WS idle timeout
  in the path."

### Step 3 — End-to-end idle confirmation (the definitive test)

With Tickets 001 and 002 deployed:

1. `docker compose build && docker compose up -d`
2. Open the VNC desktop via the jtl-syllabus extension.
3. In DevTools → Network → WS, confirm ping frames every ~25s.
4. Leave the session completely idle for **5+ minutes** — no mouse, no
   keyboard, do not interact with the tab.
5. Confirm the WebSocket remains open: no close code 1006, no page freeze,
   no loss of the desktop image.
6. If the session drops during this test, record: exact time-to-drop and WS
   close code. This would indicate an additional timeout source not covered
   by this sprint; escalate to team-lead.

## Files to Modify

None. This ticket produces documented findings only.

If Step 1 finds an actual idle timeout in the Caddy label set shorter than
25 seconds, a label change to `docker-compose.yaml` would be added here — but
this outcome is not expected.

## Acceptance Criteria

- [x] Caddy WebSocket idle-timeout behavior documented: confirmed that Caddy
      does not impose an idle timeout on established WebSocket connections with
      the current label configuration.
- [x] Cloudflare presence determined for `codespace.doswarm.jointheleague.org`
      (orange-cloud or grey-cloud); finding documented in ticket notes.
- [ ] If Cloudflare is orange-cloud: explicit confirmation that `--heartbeat=25`
      (25s interval) is less than Cloudflare's idle WS cap (~100s).
      (N/A — Cloudflare is grey-cloud/DNS-only; proxy cap does not apply.)
- [ ] End-to-end idle test: VNC session remains connected for 5+ continuous
      minutes with no drops after Tickets 001 and 002 are deployed.
      (PENDING DEPLOY — requires stakeholder to run the test; see Findings below.)
- [x] Ticket notes explicitly state: "No further config change is needed" — or,
      if something unexpected is found, team-lead is notified with details.

## Testing

No automated tests exist for this project's configuration. All verification
is manual observation as described in the Verification Plan above.

The 5-minute idle test in Step 3 is the definitive pass/fail criterion for
this sprint.

## Findings

Audit performed 2026-06-19 via static review of `docker-compose.yaml` and
live network commands from the development host.

### Step 1 — Caddy WebSocket idle-timeout

Reviewed Caddy labels in `docker-compose.yaml` lines 30–50. The complete label
set for the WebSocket route is:

```
caddy.@ws.0_header: Connection *Upgrade*
caddy.@ws.1_header: Upgrade websocket
caddy.0_route.handle: /websockify*
caddy.0_route.handle.reverse_proxy: "@ws {{upstreams 6080}}"
```

No `timeout`, `idle_timeout`, `read_timeout`, or `write_timeout` directive is
present in any label. The remaining labels define the VNC and catch-all HTTP
routes with plain `reverse_proxy` — no timeout qualifiers on any of them.

Caddy's behavior: once the HTTP Upgrade handshake completes and the connection
is hijacked for WebSocket streaming, Caddy does not impose an additional idle
timeout. This is consistent with Caddy's documented behavior for proxied
WebSocket connections when no timeout directive is configured.

**Finding**: Caddy does not impose an idle timeout on established WebSocket
connections with the current label configuration. No label change is needed.

### Step 2 — Cloudflare presence check

**DNS result** (`dig codespace.doswarm.jointheleague.org +short`):
```
161.35.238.178
```

**Cloudflare range check**: The resolved IP `161.35.238.178` was checked
against all published Cloudflare IP ranges:
- 104.16.0.0/12, 104.24.0.0/14 (Cloudflare CDN)
- 172.64.0.0/13 (Cloudflare CDN)
- 162.158.0.0/15, 141.101.64.0/18 (Cloudflare CDN)
- 198.41.128.0/17, 190.93.240.0/20, 188.114.96.0/20, 197.234.240.0/22

Result: `161.35.238.178` is **not** in any Cloudflare range.

**Whois**: `NetName: DIGITALOCEAN-161-35-0-0`, `Organization: DigitalOcean, LLC`

**HTTP header check**: `curl -sv https://codespace.doswarm.jointheleague.org`
resulted in a TLS handshake failure (`tlsv1 alert internal error`), consistent
with the container not being deployed on the development host at time of audit.
No `cf-ray` header was observable, but the IP-range check already gives a
definitive answer.

**Finding**: Cloudflare is **grey-cloud / DNS-only**. The Cloudflare proxy is
not in the request path. Cloudflare's ~100s WebSocket idle cap does not apply.
The `--heartbeat=25` ping from Ticket 001 was already sufficient if Cloudflare
had been orange-cloud; it is not needed for this reason, but does still
provide a keep-alive benefit for any other intermediate network equipment.

No action required for Cloudflare.

### Step 3 — End-to-end 5-minute idle test

**PENDING STAKEHOLDER DEPLOYMENT VERIFICATION**

This test requires the deployed container and a browser session. It cannot
be run from this environment. The acceptance criterion for the 5-minute live
idle test is left unchecked and must be verified by the stakeholder after
deploying Tickets 001 and 002.

Procedure (from the Verification Plan):
1. `docker compose build && docker compose up -d`
2. Open the VNC desktop via the jtl-syllabus extension.
3. In DevTools → Network → WS, confirm ping frames every ~25s.
4. Leave the session idle for 5+ minutes.
5. Confirm the WebSocket remains open (no close code 1006, no page freeze).

### Summary

No further config change is needed. Caddy imposes no idle timeout on
established WebSocket connections. Cloudflare is DNS-only (grey-cloud) and its
proxy-level idle cap is not in the path. The `--heartbeat=25` from Ticket 001
and the auto-reconnect logic from Ticket 002 together address all identified
idle-timeout risks in this stack. The only remaining open item is the
stakeholder-run 5-minute live idle test to close the sprint definitively.
