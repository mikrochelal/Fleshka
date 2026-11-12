# Progress

What actually exists, and how far each item has been verified.

Status vocabulary: **Implemented** (code written) · **Tested** (verified at runtime) ·
**Partially tested** · **Not tested** · **Blocked**.

"Static checks" means `scripts/check.sh`: Rojo build, StyLua, Selene, Luau strict type
analysis and the unit tests in `tests/`. Static checks do not prove runtime behaviour in
Roblox; that is recorded in `TESTING_CHECKLIST.md`.

_Last updated: 2026-11-12 — version 0.3.0 (playable slice)_

## Summary

| Area                         | State |
| ---------------------------- | ----- |
| Project foundation, tooling  | Tested in Studio |
| Core systems (net, session, players, interaction) | Partially tested in Studio |
| Draft map generator (layout v3) | Tested in Studio by the owner (generation, top view, ceilings, lighting preset) |
| Playable slice v0.3.0 (everything in the next section) | Implemented; static checks and unit tests pass; **Not tested in Studio** |
| Main menu, lobby, party system, settings | Not implemented |
| Frequency and security-code puzzles | Not implemented |
| Door system (doors are walk-through) | Not implemented |
| Audio assets                 | Blocked — no verified assets chosen; every cue id is empty |

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
