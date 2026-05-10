---
name: Architecture Decisions
description: Key design decisions made for the projection-mapping project — rationale included so future Claude can judge edge cases
type: project
---

## Phone NFC instead of Arduino

The Arduino card reader stand was replaced with a phone running Chrome on Android as an MVP kiosk.

**Why:** Faster to build, no hardware dependency for the demo. Web NFC API (`NDEFReader`) reads card UIDs on Android Chrome. The server serves the kiosk HTML page over HTTP; one Chrome flag (`#unsafely-treat-insecure-origin-as-secure`) whitelists the plain-HTTP origin since Web NFC requires a secure context.

**How to apply:** If someone suggests adding Arduino back, the signal interface (`navigation_requested(uid)`) is already decoupled — Arduino would just call `POST /navigate` the same way the phone does.

## Routes are self-contained from/to pairs

`Server.gd` holds a `ROUTES` dictionary where each entry has `{from: Vector3, to: Vector3, label: String}`. The server has no concept of "stand position" — the stand's location is implicit in whichever route's `from` it is configured with.

**Why:** Makes the system stand-agnostic. Multiple stands at different locations each get their own route entries. The server just picks a route by key and queries the navmesh.

**How to apply:** When Step 6 (schedule lookup) is added, the schedule resolves a UID to a route key (e.g. `"to_room_u10"`). The `ROUTES` dict and `_navigate()` function don't change — only the lookup logic in `_on_navigation_requested()` changes.

## RPCs live on SessionState autoload, not Server/Client nodes

**Why:** Godot routes RPCs by node path. Server.tscn root is `/root/Server`; Client.tscn root is `/root/Client` — different paths, so cross-peer RPCs between them silently fail. Autoloads share `/root/SessionState` on all peers.

**How to apply:** Any new cross-peer communication should go through SessionState RPCs, not through scene-root nodes.

## HTTP server is pure GDScript (godottpd)

`CardScanServer.gd` uses the godottpd addon directly. The C# `HttpServer.cs` was a broken stub (hardcoded Windows path) and has been cleared. Do not try to revive the C# HTTP wrapper — godottpd is GDScript-only and works well.

## Database schema is GPS-based — does not match twin coordinates

The existing `routes` and `locations` tables in `database.gd` store GPS coordinates (latitude/longitude/altitude). The navigation system operates entirely in the digital twin's 3D coordinate space (metres from a building reference point). These are incompatible. The schema needs to be redesigned for Step 6.

**How to apply:** When implementing Step 6 schedule lookup, the DB schema will need twin-space coordinates (x, y, z) rather than GPS. The `ROUTES` const in Server.gd is the ground truth for now.
