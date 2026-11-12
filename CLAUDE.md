# CLAUDE.md — persistent development rules

Rules for any AI agent or developer working in this repository. Read this first.

## Project

THE LAST SIGNAL — a 1–4 player co-op psychological horror game for Roblox (PC + mobile).
Design: `GAME_DESIGN_DOCUMENT.md`. Roadmap: `PROJECT_PLAN.md`. Real status: `PROGRESS.md`.

## Communication

- Talk to the project owner in **Russian**. They are a beginner in Roblox development:
  explain steps simply, give exact click-by-click Studio instructions and official links.
- Code, identifiers, comments and documentation files stay in **English**.
- When a decision needs the owner's input, stop and ask one specific question.

## Ownership boundary (critical)

| Owned by Git + Rojo (this repo)                | Owned by Roblox Studio (the place file)        |
| ---------------------------------------------- | ---------------------------------------------- |
| All Luau code, config modules, UI built in code | `Workspace`: map, lobby geometry, props        |
| `default.project.json`, tooling, docs           | `Lighting`, `SoundService` content, models     |

- **Never map `Workspace`, `Lighting` or `SoundService` in `default.project.json`**, and in
  `ServerStorage` map only the `TLS_DevTools` child. `scripts/check.sh` fails if `Workspace`
  appears there.
- Rojo only manages the folders it maps: `ReplicatedStorage.Shared`, `ReplicatedStorage.Config`,
  `ServerScriptService.TheLastSignal`, `StarterPlayerScripts.TheLastSignal`,
  `ServerStorage.TLS_DevTools`. Do not create
  Studio-side objects inside those folders — Rojo will delete them on sync.
- Rojo sync is one-way (files → Studio). Studio-built content is **not** in Git; it lives in
  the place file and its backups.
- Never delete or overwrite Studio-created objects without the owner's explicit approval.
- Game code may change the world only at runtime, where nothing is saved: objects it
  creates go into `Workspace.TLS_Runtime`; tags, attributes, colours and light states it
  sets on map parts last for the play session only; `Systems/AtmosphereSystem` sets the
  base `Lighting` values from `Config/AtmosphereConfig` for the session only.
- Any script that creates instances (map generators, setup tools) must be idempotent:
  running it twice must not create duplicates, and it must refuse to touch existing content.
- Code finds world objects through **CollectionService tags and attributes** (contract in
  `GAME_DESIGN_DOCUMENT.md` §11), never through hard-coded Workspace paths. Tagged objects
  outside `Workspace` (for example map backups in `ServerStorage`) must be ignored.
- Development tools live in `src/ServerStorage/DevTools` and are run by hand from the Studio
  Command Bar. Game code never requires them. The draft map generator is documented in
  `docs/MAP_GENERATOR.md`; `generate`/`regenerate` may only create or move
  `Workspace.Station09`. Its only other effects are explicit commands: `viewFromAbove`
  (editor camera) and `applyLightingPreset` (six `Lighting` properties, reversible).
- The reference floor plan in `Layout.luau` is pinned by checksums in `tests/map.luau`.
  Do not move rooms or connections unless the owner asks for a layout change.

## Architecture rules

- Exactly one `Script` (`Bootstrap.server.luau`) and one `LocalScript`
  (`ClientBootstrap.client.luau`). Everything else is a `ModuleScript`.
- Server modules: `Services/` (game-wide infrastructure) and `Systems/` (gameplay features).
  Client modules: `Controllers/`. Each may expose `Init()` (no yielding, no cross-module
  calls) and `Start()` (may yield, may call other modules). See `Shared/Loader.luau`.
- `ServerScriptService/Data/` holds server-only content as plain tables (documents,
  transmissions, the runtime prop list). Clients never receive it except through events.
- Remotes are declared only in `Shared/Net.luau`. Client-to-server events are handled only
  through `NetService.on`; server-to-client events are sent only with `NetService.fire` /
  `fireAll` and carry presentation only (text, effects, sounds).
- Shared state is replicated through attributes, not events, so late joiners are always
  correct: mission state on `ReplicatedStorage`, per-player state on the `Player`. The
  attribute names are constants in `Shared/GameState.luau`.
- The map is reached only through `Services/WorldService` (tags). Anything the game creates
  in the world at runtime goes into `WorldService.runtimeFolder()` and is never saved;
  gameplay objects are listed in `Data/PropList.luau` and checked by `tests/props.luau`.
- Systems that need the map wait with `WorldService.onReady`; systems that need players
  use `PlayerService.observePlayers` / `observeCharacters`, so start-up order never matters.
- Systems talk to each other through signals and small functions, not shared tables. Noise
  goes through `Services/NoiseService`; mission order lives only in `Systems/SliceDirector`.
- Logic that can be written without Roblox APIs (state machines, placement math) is kept in
  its own module with no `game`/`script` access and gets a unit test in `tests/`.
- The server is authoritative. Every remote handler validates argument types, game phase,
  player state and distance, and is rate limited. Clients send intent, never results.
- Tunable numbers live in `ReplicatedStorage/Config`, not inline.
- No giant scripts: split a module when it grows past roughly 300 lines.
- `--!strict` at the top of every file, with type annotations on public functions.
- File extension is `.luau`.

## Quality rules

- Never invent Roblox asset IDs. Missing assets get a clearly labelled placeholder and an
  entry in `ASSET_MANIFEST.md`. Sounds are named in `Config/AudioConfig.luau`; an empty id
  means "not chosen yet" and is skipped silently.
- No pseudocode presented as a feature, no buttons that do nothing, no deprecated APIs
  (`wait`, `spawn`, `delay`, `BodyVelocity`, etc. — use `task.*` and modern constraints).
- Never mark something as tested unless it was actually run. Status vocabulary used in
  `PROGRESS.md` and `TESTING_CHECKLIST.md`: Implemented / Tested / Partially tested /
  Not tested / Blocked.
- Fix warnings instead of silencing them. Make small, targeted changes.

## Validation

Run before every commit (tools are pinned in `rokit.toml`):

```bash
scripts/check.sh
```

It runs the Workspace guard, `rojo build`, `rojo sourcemap`, `stylua --check`, `selene`,
the unit tests in `tests/` (pure-logic modules, standalone Luau CLI) and
`luau-lsp analyze`. This is static analysis only; runtime behaviour must be verified in
Roblox Studio and recorded in `TESTING_CHECKLIST.md`.

## Documentation

Update `PROGRESS.md` and `TESTING_CHECKLIST.md` with every feature, `ASSET_MANIFEST.md` with
every asset or placeholder, and `GAME_DESIGN_DOCUMENT.md` / `PROJECT_PLAN.md` when design or
architecture changes.
