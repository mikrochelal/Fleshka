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

- **Never map `Workspace`, `Lighting`, `ServerStorage` or `SoundService` in
  `default.project.json`.** `scripts/check.sh` fails if `Workspace` appears there.
- Rojo only manages the folders it maps: `ReplicatedStorage.Shared`, `ReplicatedStorage.Config`,
  `ServerScriptService.TheLastSignal`, `StarterPlayerScripts.TheLastSignal`. Do not create
  Studio-side objects inside those folders — Rojo will delete them on sync.
- Rojo sync is one-way (files → Studio). Studio-built content is **not** in Git; it lives in
  the place file and its backups.
- Never delete or overwrite Studio-created objects without the owner's explicit approval.
- Any script that creates instances (map generators, setup tools) must be idempotent:
  running it twice must not create duplicates, and it must refuse to touch existing content.
- Code finds world objects through **CollectionService tags and attributes** (contract in
  `GAME_DESIGN_DOCUMENT.md` §11), never through hard-coded Workspace paths.

## Architecture rules

- Exactly one `Script` (`Bootstrap.server.luau`) and one `LocalScript`
  (`ClientBootstrap.client.luau`). Everything else is a `ModuleScript`.
- Server modules: `Services/` (game-wide infrastructure) and `Systems/` (gameplay features).
  Client modules: `Controllers/`. Each may expose `Init()` (no yielding, no cross-module
  calls) and `Start()` (may yield, may call other modules). See `Shared/Loader.luau`.
- Remotes are declared only in `Shared/Net.luau` and handled only through `NetService.on`.
- The server is authoritative. Every remote handler validates argument types, game phase,
  player state and distance, and is rate limited. Clients send intent, never results.
- Tunable numbers live in `ReplicatedStorage/Config`, not inline.
- No giant scripts: split a module when it grows past roughly 300 lines.
- `--!strict` at the top of every file, with type annotations on public functions.
- File extension is `.luau`.

## Quality rules

- Never invent Roblox asset IDs. Missing assets get a clearly labelled placeholder and an
  entry in `ASSET_MANIFEST.md`.
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
