---
name: Demo Prep
description: Physical real-world tasks required before the demo — things that cannot be done in code
type: project
---

## Must-do before demo day

### Measure route positions
`Server.gd` contains a `ROUTES` const with placeholder `Vector3.ZERO` values for all `from` positions and made-up `to` positions. These must be replaced with real measurements.

**How:** Open the project in the Godot editor with `TekBuilding.tscn` loaded. Click points on the navmesh in the 3D viewport — the inspector shows the world-space coordinates. Measure from/to for each route (entrance → each destination room).

### Register demo cards
The NFC UID of each card used in the demo must be known. On first scan the UID is printed to the Godot console (`[Server] Card scan — uid: ...`). Copy each UID and add it to the `users` table before the demo. Step 6 (schedule lookup) will map UID → route key.

### One-time phone setup
On the demo Android phone (Chrome):
1. Open `chrome://flags/#unsafely-treat-insecure-origin-as-secure`
2. Add `http://<server-ip>:8080`
3. Tap Relaunch

Must be repeated if the server's IP address changes (e.g. different network).

### 3D-printed projector mounts
Mounts are not yet designed. Until they exist, pitch/roll of projectors must be manually levelled. See README for the full TODO list.
