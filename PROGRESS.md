# Progress

What actually exists, and how far each item has been verified.

Status vocabulary: **Implemented** (code written) · **Tested** (verified at runtime) ·
**Partially tested** · **Not tested** · **Blocked**.

"Static checks" means `scripts/check.sh`: Rojo build, StyLua, Selene, Luau strict type
analysis and the unit tests in `tests/`. Static checks do not prove runtime behaviour in
Roblox; that is recorded in `TESTING_CHECKLIST.md`.

_Last updated: 2026-11-12 — version 0.4.0_

## Summary

| Area                         | State |
| ---------------------------- | ----- |
| Project foundation, tooling  | Tested in Studio |
| Core systems (net, session, players, interaction) | Partially tested in Studio |
| Map generator, layout v3 (29 rooms) | Tested in Studio by the owner (generation, top view, ceilings, lighting preset) |
| Map generator, layout v4 (55 rooms, 8 zones) | Implemented; unit tested; **Not tested in Studio** |
| Playable slice v0.3.0 (everything in the next section) | **Partially tested** — the owner saw the objective panel, document reader, stamina and battery indicators and interactions working in Studio; the rest is unverified |
| Main menu, lobby, party system, settings | Not implemented |
| Frequency and security-code puzzles | Not implemented |
| Door system (doors are walk-through) | Not implemented |
| Audio assets                 | Blocked — no verified assets chosen; every cue id is empty |

## Version 0.4.0 — bug fixes, first person, escalation

### The two reported bugs

**"EMERGENCY POWER says everything must be done again."** Found by code inspection, not
reproduced (no Studio). The lever did exactly what it was written to do: if the three
breakers had been engaged in any order other than the memo's, `PowerSystem.trip()` reset
all of them and showed "Wrong start-up order. Every breaker has tripped." With three
breakers, five of the six possible orders did this, and nothing on screen said where the
order came from. Not a broken remote or objective reset — a punishing rule with poor
feedback. Fixed by removing the reset: a breaker out of turn trips back out on its own and
the rest stay engaged; the lever always works once all are in; the HUD shows the breaker
count and a hint pointing at the memo.

**"THE COPY stopped appearing."** No code path of THE COPY changed between 0.3.0 and the
map expansion, so no regression was found in its own code. What the audit did find:

- Every way it could appear was behind restored power (the scripted sighting needs the
  radio, the radio needed power), except one: the noise of a failed start-up. With the
  lever bug above, a session never got past the power puzzle.
- Its body is almost black and the station is unlit before power, so even when it came to
  a failed start-up it stood in a dark room for a second or two and left.
- Nothing was logged when it could not find a fair place to appear, so "it is not coming"
  and "it is broken" looked the same.

Fixed by the power change, a faint glow on the body, regular visits from the moment power
is restored, and `[TLS:THE_COPY]` logs for every request, success, refusal (with the
reason) and stage change. **Whether this was the cause in the owner's session is not
confirmed**; the new logs will show it on the next run.

### What is new

| System | Files | Status |
| ------ | ----- | ------ |
| Power puzzle without resets; start-up sequence; state logs | `Systems/PowerSystem` | Implemented; **Not tested** |
| Power status and objective hints on the HUD | `Controllers/HudController`, `Config/ObjectiveConfig` | Implemented; **Not tested** |
| Mission of eight objectives through the power wing and the laboratory; objectives skipped when the map lacks their object | `Systems/SliceDirector` | Implemented; **Not tested** |
| Switchgear (communications relay) and signal-trace console | `Data/PropList`, `Data/Transmissions` | Implemented; placement unit tested; **Not tested** |
| Three more documents (6 in total) in the power, medical and archive wings | `Data/Documents` | Implemented; content unit tested |
| THE COPY escalation: Dormant → Aware → Hunting → Hostile → FinalPursuit, driven by objectives, one step at a time | `Systems/CopyAI/Escalation`, `Config/CopyConfig` | Implemented; **unit tested** (forward only, no skipped stage, per-stage fairness limits); behaviour in play **Not tested** |
| THE COPY diagnostics and glow | `Systems/CopyAI/init`, `Body` | Implemented; **Not tested** |
| Environmental disturbances by stage | `Systems/HorrorDirector` | Implemented; **Not tested** |
| First-person camera with step bob; camera-aligned local flashlight | `Controllers/CameraController`, `Config/CameraConfig` | Implemented; **Not tested** — depends on engine behaviour that could not be checked here |
| Haze, colour grade, template effects disabled, at runtime only | `Systems/AtmosphereSystem`, `Config/AtmosphereConfig` | Implemented; values are a first guess, **Not tested** |
| Ending: rising-signal sequence before the last line | `Data/Transmissions` | Implemented as subtitles and interference; **no audio** |

### Not done from the 0.4.0 brief

- Environmental props (cables, pipes, panels, signs beyond door names, particles): none.
- Audio: still no assets, so no machinery, ambience, flashlight click or final scream can
  be heard. The cues exist and are named.
- Working doors: still walk-through, so "the next area becomes accessible" is told by
  objectives and light, not by a door opening.
- The escape is a return to the arrival elevator, not a chase set-piece with a dedicated
  route; the freight elevator is not used yet.
- Settings (camera bob on/off, volumes) exist only as config values, not as a menu.

## Production milestones (the "ultimate" brief)

| # | Milestone | State |
| - | --------- | ----- |
| 1 | Full technical audit | Done |
| 2 | Expanded station | **Done in code**: 55 rooms, 8 zones, original 29 preserved; needs Studio verification |
| 3 | Visual transformation | **Started**: per-zone wall materials and lamp tones, door signs. Not done: props and decoration, pipes, fog and post-processing, per-zone Lighting, graphics fallback |
| 4 | Core gameplay | Slice plus first-person camera (0.4.0). Not done: working doors |
| 5 | Puzzles and story | Power puzzle, 8-objective mission, 6 documents. Not done: frequency, archive code and containment puzzles; the remaining lore discoveries |
| 6 | THE COPY | Six states plus five escalation stages (0.4.0). Not done: stalking state, field of view, new silhouette, animation |
| 7 | Cinematic horror | One scripted sighting and stage-driven disturbances. Not done: the other scare types, camera impulses |
| 8 | Final presentation | Not done: menu, lobby, settings, pause, credits, volume groups |
| 9 | Testing | Static only; Studio testing is the owner's |

The new wings are **architecture without gameplay**: they can be walked and are lit and
labelled, but nothing in them is interactive yet, and the mission still runs through the
original rooms.

## Expanded station — layout v4

| Item | Status |
| ---- | ------ |
| 26 new rooms appended; original 29 rooms and 30 connections pinned by checksum | Implemented; unit tested |
| 59 connections; every room reachable by a character-sized flood fill; no overlapping solids (a blocked door found by this test was fixed) | Unit tested |
| Zones E Medical, F Archives, G Power, H Containment with own materials and lamps | Implemented; appearance **Not tested** |
| Door signs (room name above each doorway, both sides) | Implemented; sign data unit tested; rendering and orientation **Not tested** |
| Placeholder landmarks in new rooms (generator, signal core, cells, shelves…) | Implemented; placement unit tested |
| THE COPY observation points in new wings (7 more) | Implemented; unit tested for reachability |
| Lighting circuits E–H dead until power is restored | Implemented; **Not tested** |
| Developer overlay: `showOverlay`, `hideOverlay`, `listRooms`; removed automatically in play | Implemented; **Not tested** |
| Room directory | `docs/ROOM_DIRECTORY.md`, generated from the layout |

## Playable slice — version 0.3.0

None of this has run inside Roblox yet. "Unit tested" means the pure logic was executed with
the standalone Luau CLI.

| System | Files | Status |
| ------ | ----- | ------ |
| Map lookup by tags, room tracking, runtime folder | `Services/WorldService` | Implemented; **Not tested** |
| Player placement in the elevator (floor found by raycast, slots for 4 players, respawn) | `Systems/SpawnSystem` | Implemented; **Not tested** |
| Walk / sprint / stamina, server-owned | `Systems/MovementSystem`, `Config/PlayerConfig` | Implemented; **Not tested** |
| Flashlight: real SpotLight, battery drain, low-battery flicker, slow recharge to 25%, battery packs | `Systems/FlashlightSystem`, `Config/FlashlightConfig` | Implemented; **Not tested** |
| Interaction: prompts on Parts, Attachments and Models; enable/disable and text through attributes | `Systems/InteractionSystem` | Implemented; earlier version partially tested in Studio; new version **Not tested** |
| Runtime gameplay objects (documents, radio, batteries, elevator panel; reuse of map placeholders) | `Systems/WorldProps`, `Data/PropList` | Implemented; placements unit tested against the map layout (inside rooms, clear of doorways, map props and the spawn point); creation **Not tested** |
| Objectives: six, strictly ordered, server-owned, replicated by attribute | `Services/ObjectiveService`, `Config/ObjectiveConfig` | Implemented; **Not tested** |
| Facility lights: circuits and flicker | `Systems/FacilityLights` | Implemented; **Not tested** |
| Dark underground base lighting, applied at runtime only | `Systems/AtmosphereSystem`, `Config/AtmosphereConfig` | Implemented; **Not tested** |
| Power Restoration puzzle: three breakers in a per-session order from the memo, main lever, trip on a wrong order | `Systems/PowerSystem`, `Config/PowerConfig` | Implemented; data unit tested; **Not tested** |
| Documents: three, sent by the server on reading; memo text generated per session | `Systems/DocumentSystem`, `Data/Documents` | Implemented; content unit tested; **Not tested** |
| Radio transmission with subtitles, pauses, light flicker, interference | `Systems/RadioSystem`, `Data/Transmissions` | Implemented; script unit tested; **Not tested** |
| Scripted corridor sighting | `Systems/HorrorDirector` | Implemented; **Not tested** |
| THE COPY: six-state brain | `Systems/CopyAI/Brain` | Implemented; **unit tested** (45 checks: waking, fairness, warning, losing sight, time limit, catch, cooldowns) |
| THE COPY: senses, pathfinding walker, placeholder body, catch and return | `Systems/CopyAI/*` | Implemented; **Not tested** — pathfinding and sight need Studio |
| Mission script: auto-start, objective wiring, console, elevator, ending | `Systems/SliceDirector` | Implemented; **Not tested** |
| HUD: objectives, stamina, battery, touch buttons | `Controllers/HudController`, `InputController` | Implemented; **Not tested** |
| Notifications and subtitles | `Controllers/MessageController` | Implemented; **Not tested** |
| Document viewer | `Controllers/DocumentController` | Implemented; **Not tested** |
| Interference, blackout, title card, completion card | `Controllers/EffectsController` | Implemented; **Not tested** |
| Audio architecture (named cues, positional playback, ambient loops) | `Controllers/AudioController`, `Config/AudioConfig` | Implemented; silent by design until assets are chosen; **Not tested** |

### Known limitations of the slice

- **Reviewed, not run.** An independent code review for runtime problems was done and its
  findings fixed (objective catch-up, subtitles over the blackout, a HUD layout cycle, sprint
  state after respawn). That is still not a substitute for running the game.
- **No sound.** Every audio cue is defined but has no asset id. Footsteps are Roblox's
  default character sounds. The radio and the entity rely on subtitles, lights and screen
  interference.
- **Doors do not work yet.** Door panels are half-transparent and walk-through. The
  red-framed code door is passable.
- **The flashlight follows the head, not the camera pitch.** Looking up or down in first
  person does not tilt the beam.
- **THE COPY is a placeholder figure that glides** (it is moved directly along the path
  rather than animated).
- **Before power is restored** the corridors, laboratory and communication center are dark
  by design; only the entrance and the red emergency lamps are lit. After power returns the
  emergency lamps go out, which leaves the service tunnel and the airlock dark.
- **No menu or lobby.** The session starts by itself when the first player is ready
  (`GameConfig.AutoStartSession`). Everyone on the server shares one mission.
- **Being caught** returns the player to the communication center; there is no death.
- **Session restart** needs Stop and Play again.
- **Mobile** layout and touch buttons exist but have never been seen on a device.

## Phase 1 — Project foundation

| Item                                         | Status                                             |
| -------------------------------------------- | -------------------------------------------------- |
| Tooling pinned in `rokit.toml` (Rojo 7.7.1)  | Implemented; versions installed and run on Linux   |
| `default.project.json` (code only)           | **Tested** — synced into the owner's Studio        |
| Workspace safety guard in `scripts/check.sh` | Implemented; runs on every check                   |
| `Shared/Loader`, `Logger`, bootstraps        | **Tested** — startup lines seen in Studio Output   |
| Roblox Studio MCP                            | **Blocked** — not reachable from the cloud development environment |

## Phase 2 — Core systems

| Item                                                        | Status                                         |
| ----------------------------------------------------------- | ---------------------------------------------- |
| `Shared/GameState`, `Shared/RateLimiter`                    | Implemented; unit tested                       |
| `Shared/Net` + `NetService`                                 | **Partially tested** — the ready event reached the server in Studio; server-to-client events added in 0.3.0 are **Not tested** |
| `SessionService`                                            | **Partially tested** — mode and initial phase confirmed in Studio; phase changes not yet seen |
| `PlayerService`                                             | **Partially tested** — join and ready confirmed in Studio |
| `OverheadGuard` (shows hidden ceilings during play)         | Implemented; **Not tested**                    |

## Phase 6 (early) — Draft map generator

| Item                                                      | Status                                         |
| --------------------------------------------------------- | ---------------------------------------------- |
| Layout v3: 29 rooms, 30 connections, pinned by a test     | Implemented; unit tested; **generated in Studio by the owner** (29 rooms, 26 doors, 4 archways, 53 lights, 636 parts) |
| Commands `regenerate`, `viewFromAbove`, `hideCeilings`, `showCeilings`, `applyLightingPreset`, `restoreLighting` | **Tested** — reported working by the owner |
| Walkability of the generated map                          | Unit tested (flood fill); the owner reached the elevator floor in Play; a full walk-through is **Not tested** |

## Known limitations of the environment

- Development runs in a cloud workspace with no Roblox Studio, so nothing can be executed
  inside Roblox there. Runtime verification depends on the owner running the checklist.
- `Session` and `Lobby` server modes and reconnecting need a published place.
- The map lives in the Studio place file, not in this repository.
