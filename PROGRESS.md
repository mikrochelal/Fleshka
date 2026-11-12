# Progress

What actually exists, and how far each item has been verified.

Status vocabulary: **Implemented** (code written) · **Tested** (verified at runtime) ·
**Partially tested** · **Not tested** · **Blocked**.

"Static checks" means `scripts/check.sh`: Rojo build, StyLua, Selene and Luau strict type
analysis. Static checks do not prove runtime behaviour.

_Last updated: 2026-11-12_

## Phase 1 — Project foundation

| Item                                         | Status                                             |
| -------------------------------------------- | -------------------------------------------------- |
| Repository inspection                        | Done — repository was empty (no commits, no files) |
| Tooling pinned in `rokit.toml` (Rojo 7.7.1)  | Implemented; versions installed and run on Linux   |
| `default.project.json` (code only)           | Implemented; `rojo build` succeeds; built place contains only ReplicatedStorage, ServerScriptService and StarterPlayer — no Workspace |
| Workspace safety guard in `scripts/check.sh` | Implemented; runs on every check                   |
| `Shared/Loader`, `Logger`, `GameState`       | Implemented; static checks pass; **Not tested** at runtime |
| `Config/GameConfig`                          | Implemented; static checks pass                    |
| Server and client bootstraps                 | Implemented; static checks pass; **Not tested** at runtime |
| Live sync into Studio (`rojo serve`)         | **Not tested** — needs the owner's machine         |
| Roblox Studio MCP                            | **Blocked** — not reachable from the cloud development environment |
| Documentation set                            | Done                                               |

## Phases 2–8

Not started. See `PROJECT_PLAN.md`.

## Known limitations

- Development so far ran in a cloud workspace with no Roblox Studio. Nothing has been
  executed inside Roblox yet; the first runtime verification is the Phase 1 checklist in
  `TESTING_CHECKLIST.md`.
- No map exists. `Workspace` content is created in Studio and is not stored in this
  repository.
