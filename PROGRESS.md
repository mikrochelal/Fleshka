# Progress

What actually exists, and how far each item has been verified.

Status vocabulary: **Implemented** (code written) · **Tested** (verified at runtime) ·
**Partially tested** · **Not tested** · **Blocked**.

"Static checks" means `scripts/check.sh`: Rojo build, StyLua, Selene, Luau strict type
analysis and the unit tests in `tests/`. Static checks do not prove runtime behaviour in
Roblox; that is recorded in `TESTING_CHECKLIST.md`.

_Last updated: 2026-11-12_

## Phase 1 — Project foundation

| Item                                         | Status                                             |
| -------------------------------------------- | -------------------------------------------------- |
| Tooling pinned in `rokit.toml` (Rojo 7.7.1)  | Implemented; versions installed and run on Linux   |
| `default.project.json` (code only)           | **Tested** — `rojo build` output contains no Workspace; synced into the owner's Studio |
| Workspace safety guard in `scripts/check.sh` | Implemented; runs on every check                   |
| `Shared/Loader`, `Logger`                    | **Tested** — both startup lines seen in Studio Output (owner, 2026-11-12) |
| Server and client bootstraps                 | **Tested** — same evidence                         |
| Workspace untouched by re-sync, no duplicates on reconnect | **Not tested** (checklist 1.3, 1.5)  |
| Roblox Studio MCP                            | **Blocked** — not reachable from the cloud development environment |
| Documentation set                            | Done                                               |

## Phase 2 — Core systems

| Item                                                        | Status                                         |
| ----------------------------------------------------------- | ---------------------------------------------- |
| `Shared/GameState` (phases, transitions, parsing)           | Implemented; unit tested (Luau CLI)            |
| `Shared/RateLimiter` (token bucket)                         | Implemented; unit tested (Luau CLI)            |
| `Shared/Signal` (event system)                              | Implemented; static checks; **Not tested** at runtime |
| `Shared/Net` + `NetService` (remotes, type checks, rate limit) | Implemented; static checks; **Not tested** at runtime |
| `SessionService` (mode detection, phase machine, replication) | Implemented; static checks; **Not tested** at runtime |
| `PlayerService` (join, leave, ready, reconnect grace, respawn signal) | Implemented; static checks; **Not tested** at runtime |
| `InteractionSystem` (tag-driven, server-validated prompts)  | Implemented; static checks; **Not tested** at runtime |
| `DebugInteractables` (Studio-only test kinds)               | Implemented; static checks; **Not tested** at runtime |
| `SessionController` (client phase view, ready handshake)    | Implemented; static checks; **Not tested** at runtime |
| World contract validator                                    | Partly implemented — `TLS_Interactable` objects are validated when bound; other tags are validated as their systems arrive |

Phase 2 is complete only after checklist section "Phase 2" is run in Studio.

## Phase 6 (early) — Draft map generator

| Item                                                      | Status                                         |
| --------------------------------------------------------- | ---------------------------------------------- |
| Layout v2: 29 rooms in 4 areas, 30 connections, one connected structure | Implemented; unit tested (Luau CLI): no overlapping rooms, every room reachable, props and markers inside rooms |
| Geometry math (walls split around openings, lintels, lights, door frames) | Implemented; unit tested (Luau CLI): every passage is clear for a character, frames and walls do not overlap |
| Rock shell and roof (`Shell.luau`)                        | Implemented; unit tested (Luau CLI): rock and rooms fill the footprint exactly, rock never intrudes into a room |
| Instance builder (parts, materials, lights, tags)         | Layout v1 **Partially tested** — the owner generated and viewed the v1 map in Studio; v2 additions (frames, shell, new rooms) **Not tested** in Studio |
| Commands: `generate`, `regenerate`, `status`, `hideCeilings`, `showCeilings` | `generate` ran in Studio on v1; the rest **Not tested** in Studio |
| Safety: idempotent generate, backup instead of delete, refusal for foreign content, deterministic output | Implemented; determinism unit tested; the rest **Not tested** in Studio |
| Rojo mapping `ServerStorage.TLS_DevTools`                 | **Tested** — verified against a live `rojo serve` tree; synced to the owner's Studio |

The generated map is a draft blockout: no final lighting mood, fog, sound, decoration or
working doors. Doors are walk-through placeholders until the door system exists.

## Phases 3–5, 7–8

Not started. See `PROJECT_PLAN.md`.

## Known limitations

- Development runs in a cloud workspace with no Roblox Studio, so runtime verification
  depends on the owner running the checklist in Studio.
- `Session` and `Lobby` server modes cannot be exercised in Studio (Studio always runs in
  `Studio` mode); they need a published place.
- Reconnect data retention can only be observed on a published place.
- The standalone Luau CLI is not available through Rokit; without it `scripts/check.sh`
  reports the unit tests as skipped.
- No map exists. `Workspace` content is created in Studio and is not stored in this
  repository.
