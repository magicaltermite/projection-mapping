---
name: Project Status
description: Current implementation step progress for the projection-mapping campus navigation project
type: project
---

Real-time holographic campus navigation for SDU Tek building. Two laptops run the same Godot 4.6 (mono) project; role (server/client) is selected on first launch.

## Implementation steps

| Step | Description | Status |
|---|---|---|
| 1 | Bootstrap, Network, Server/Client scaffold | Done |
| 2 | Digital twin in Server.tscn, path computation, path sync | Done |
| 3 | PathRenderer — debug line rendering from projector camera | Next |
| 3b | C a f f e i n e | 是的 |
| 4 | Calibration scene — dual-display alignment, live SpinBox controls | Done |
| 5 | Hologram shader — ribbon mesh, scrolling chevrons, bloom | — |
| 6 | Schedule lookup — map NFC UID -> route key, wire CardScanServer response | — |

**Step 3 is next.** Client.gd already has the `_on_state_updated()` hook with a TODO comment pointing to PathRenderer.

## What was built this session

- `Scripts/Networking/CardScanServer.gd` — godottpd HTTP server on port 8080. `GET /scan` serves the kiosk page; `POST /navigate` receives `{uid}` and emits `navigation_requested(uid)`.
- `web/scan.html` — mobile NFC kiosk UI. Tap-to-activate, continuously scans cards, shows destination for 3.5 s then resets.
- `Server.gd` — wired `CardScanServer`, nav map readiness poll (`_init_nav_map()`), route-based path computation (`_navigate()`), writes to `SessionState.active_paths` and broadcasts.
- `Client.gd` — connected `SessionState.state_updated` to `_on_state_updated()` (prints waypoint counts; Step 3 will add PathRenderer call).
- `HttpServer.cs` — cleared broken hardcoded Windows path; replaced with a one-line comment.

**Why:** Step 6 (Arduino) was replaced entirely by the phone NFC approach.
**How to apply:** Pick up at Step 3 — PathRenderer node that draws debug lines from the projector Camera3D perspective using `SessionState.active_paths`.
