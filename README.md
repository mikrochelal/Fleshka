# THE LAST SIGNAL

A 1–4 player cooperative psychological horror game for Roblox (PC + mobile).

In 1998 the underground research facility STATION-09 went silent after transmitting one
sentence: *"IT KNOWS WE ARE LISTENING."* Years later a new signal appears, and a team is sent
down to find out why.

> **Status:** version 0.3.0 — a playable 5–10 minute slice (elevator → power puzzle → radio →
> first encounter → escape). Written and statically checked; not yet verified in Roblox
> Studio. See [PROGRESS.md](PROGRESS.md).
> Пошаговая инструкция на русском: [docs/SETUP_RU.md](docs/SETUP_RU.md).

## How the project is organised

| Part                        | Lives in                     | Tool            |
| --------------------------- | ---------------------------- | --------------- |
| Code, config, UI, docs      | This Git repository          | Editor + Rojo   |
| Map, props, lighting, audio | The Roblox Studio place file | Roblox Studio   |

Rojo copies the code from this repository into Roblox Studio. It does **not** copy anything
back, and it does **not** touch `Workspace`. The map you build in Studio is stored only in
the place file, so back that file up separately (see below).

```text
default.project.json      Rojo mapping (code only, never Workspace)
src/
  ReplicatedStorage/
    Shared/               Modules used by both server and client
    Config/               Tunable values
  ServerScriptService/
    Bootstrap.server.luau The only server Script
    Services/             Game-wide server infrastructure (net, session, players,
                          objectives, world lookup, noise)
    Systems/              Gameplay features (spawn, movement, flashlight, interaction,
                          power puzzle, radio, documents, THE COPY, mission script)
    Data/                 Server-only content (documents, transmissions, prop list)
  StarterPlayer/StarterPlayerScripts/
    ClientBootstrap.client.luau   The only LocalScript
    Controllers/          Client behaviour and UI (HUD, messages, documents, effects,
                          input, audio)
    UI/                   Shared look of the interface
  ServerStorage/DevTools/
    MapGenerator/         Draft map generator, run by hand (docs/MAP_GENERATOR.md)
scripts/check.sh          Static validation + unit tests
tests/                    Unit tests for pure-logic modules (Luau CLI)
```

## Setup

1. Install [Roblox Studio](https://create.roblox.com/landing).
2. Install [Git](https://git-scm.com/downloads) and clone this repository.
3. Install [Rokit](https://github.com/rojo-rbx/rokit/releases/latest), then in the repository
   folder run:
   ```bash
   rokit install
   ```
   This installs the exact tool versions pinned in `rokit.toml` (Rojo 7.7.1, Selene, StyLua,
   luau-lsp).
4. Install the Rojo Studio plugin (must be the same 7.x version as the CLI):
   ```bash
   rojo plugin install
   ```
5. Start the sync server:
   ```bash
   rojo serve
   ```
6. Open your place in Roblox Studio → **Plugins** tab → **Rojo** → **Connect**.
7. Press **Play**. The Output window should show:
   ```text
   [TLS:Server] THE LAST SIGNAL v0.3.0 started: 6 services, 15 systems
   [TLS:Client] Client started: 7 controllers
   ```

Official Rojo documentation: <https://rojo.space/docs/v7/>.

### Updating

All finished work is merged into the repository's default branch,
`hoplite/katane-c6d07c95`. To update a local copy: stop `rojo serve`, run
`git fetch origin && git checkout hoplite/katane-c6d07c95 && git pull`, start `rojo serve`
again and reconnect the Studio plugin. Restarting the server matters whenever
`default.project.json` changed.

## Playing the current build

The game needs the generated map (`Workspace.Station09`, see
[docs/MAP_GENERATOR.md](docs/MAP_GENERATOR.md)). With the map in the place and Rojo
connected, press **Play**: you are placed in the elevator and the mission starts by itself.

| Control            | Keyboard     | Gamepad | Touch          |
| ------------------ | ------------ | ------- | -------------- |
| Sprint             | hold Shift   | hold L3 | RUN (toggle)   |
| Flashlight         | F            | Y       | LIGHT          |
| Interact           | E            | X       | tap the prompt |
| Close a document   | X            | B       | CLOSE          |

The walkthrough and what to look for are in [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)
(section "Playable slice").

## Backing up the Studio place

Studio-built content is not in Git. After every building session:

1. In Studio: **File → Save to File As…** and save `TheLastSignal_YYYY-MM-DD.rbxl` into a
   backup folder outside this repository (or into `backups/`, which Git ignores).
2. Keep several dated copies, ideally also in cloud storage.

## Validation

```bash
scripts/check.sh
```

Runs the Workspace safety guard, `rojo build`, StyLua, Selene, Luau type analysis and the
unit tests in `tests/` (these need the [Luau CLI](https://github.com/luau-lang/luau/releases);
without it the script reports them as skipped).
These are static checks; gameplay is verified in Studio using
[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md).

## Documentation

- [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md) — design and technical architecture
- [PROJECT_PLAN.md](PROJECT_PLAN.md) — roadmap
- [PROGRESS.md](PROGRESS.md) — what is actually implemented and tested
- [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md) — test procedures and results
- [ASSET_MANIFEST.md](ASSET_MANIFEST.md) — assets and placeholders
- [CLAUDE.md](CLAUDE.md) — development rules
