# Project Plan

Roadmap for THE LAST SIGNAL. Each phase is delivered as its own pull request, passes
`scripts/check.sh`, and is then verified in Roblox Studio using `TESTING_CHECKLIST.md`.
Actual status is tracked in `PROGRESS.md`.

## Phase 1 — Project foundation

- Repository inspection, tooling, pinned versions (`rokit.toml`).
- `default.project.json` that maps code only and never `Workspace`.
- Bootstraps and module loader; shared `GameState`, `Logger`, `GameConfig`.
- Documentation set and static validation script.

**Done when:** `scripts/check.sh` passes and the two startup lines appear in Studio Output.

## Phase 2 — Core systems

- `NetService`: remote definitions, argument validation, per-player rate limiting.
- `SessionService`: server mode (lobby / session / Studio fallback) and phase machine.
- `PlayerService`: join, leave, respawn, reconnect handling, per-player session data.
- Interaction framework (server-validated, tag-driven) and server event bus.
- World contract validator (reports missing tags).

**Done when:** a tagged test part can be interacted with by two players in a Studio local
server, invalid requests are rejected, and phase changes replicate.

## Phase 3 — UI

- UI kit (theme, components, transitions), main menu, settings (persisted per player).
- Lobby: player list, party create/join/leave, ready, start.
- Loading screen and HUD (stamina, battery, objective, prompt, subtitles).
- PC and mobile layouts.

**Done when:** every button performs its action, verified on PC and in the Studio device
emulator.

## Phase 4 — Gameplay

- Sprint and stamina, flashlight and battery, pickups.
- Documents and team journal, objectives.
- Puzzles: Power Restoration, Frequency Calibration, Security Code.

**Done when:** all three puzzles can be solved and failed, with state synchronised between
players and solutions validated on the server.

## Phase 5 — Horror systems

- THE COPY: state machine, senses, pathfinding, fairness rules.
- Seven scripted horror events with a director that prevents stacking.
- Radio system and audio events, subtitles.

**Done when:** each AI state and each event can be triggered and observed in a test session.

## Phase 6 — World building

- Draft map generator for STATION-09 — **delivered early** (see `docs/MAP_GENERATOR.md`):
  floors, walls, ceilings, doors, lights, zones and placeholders for all four areas.
- Layout iteration after playtesting (edit `Layout.luau`, regenerate).
- Lighting, atmosphere and post-processing presets; particles.
- Props and environmental storytelling built in Studio, tagged per the world contract.

**Done when:** the full route from entrance to elevator is walkable with all tags valid.

## Phase 7 — Story

- Story introduction and cinematic intro.
- Story events, final sequence, ending cinematic, credits, return to menu.

**Done when:** a complete playthrough from menu to credits works for 1 and 2 players.

## Phase 8 — Polish

- Performance pass (mobile), memory and network review.
- Multiplayer tests with 4 players, reconnect and leave cases.
- Bug fixing, balance of stamina/battery/AI, final asset replacement.

**Done when:** every item in `TESTING_CHECKLIST.md` is Tested and no placeholder remains in
`ASSET_MANIFEST.md`.

## Open decisions for the project owner

1. Final audio: use Roblox Creator Store audio (free, permitted) or original recordings?
2. THE COPY model: built from parts in Studio or a custom mesh?
3. Is a published experience available for testing teleport to reserved servers (needed for
   the real lobby → session flow; Studio uses the fallback)?
