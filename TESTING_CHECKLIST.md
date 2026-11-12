# Testing Checklist

Record the result and date for every test. Result values: **Pass**, **Fail**, **Not run**,
**Blocked**. Never mark Pass without actually running the test.

## Automated static checks

Run `scripts/check.sh` before every commit.

| Check                           | Result | Date       | Notes                         |
| ------------------------------- | ------ | ---------- | ----------------------------- |
| Workspace not mapped in Rojo    | Pass   | 2026-11-12 |                               |
| `rojo build`                    | Pass   | 2026-11-12 | Rojo 7.7.1                    |
| `stylua --check src`            | Pass   | 2026-11-12 |                               |
| `selene src`                    | Pass   | 2026-11-12 | 0 errors, 0 warnings          |
| `luau-lsp analyze` (strict)     | Pass   | 2026-11-12 |                               |

## Phase 1 — manual tests in Roblox Studio

| #   | Test                                                                                   | Expected                                                                 | Result  | Date |
| --- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------- | ---- |
| 1.1 | `rojo serve`, then Connect in the Studio Rojo plugin                                   | Plugin shows "Connected"; no errors                                      | Not run |      |
| 1.2 | Look at Explorer after connecting                                                      | `ReplicatedStorage.Shared`, `ReplicatedStorage.Config`, `ServerScriptService.TheLastSignal`, `StarterPlayerScripts.TheLastSignal` exist | Not run |      |
| 1.3 | Put a test Part in Workspace, disconnect and reconnect Rojo                            | The Part is still there                                                  | Not run |      |
| 1.4 | Press Play, read Output                                                                | `[TLS:Server] THE LAST SIGNAL v0.1.0 started: 0 services, 0 systems` and `[TLS:Client] Client started: 0 controllers`; no red or yellow lines from TLS | Not run |      |
| 1.5 | Connect Rojo twice in a row                                                            | No duplicated folders or scripts                                         | Not run |      |

## Standard scenarios (apply to every gameplay system from Phase 2 on)

Use **Test → Clients and Servers → Local Server** in Studio with the listed player count.

| Scenario                              | How                                                         |
| ------------------------------------- | ----------------------------------------------------------- |
| One player                            | Play (F5)                                                   |
| Two players                           | Local Server, 2 players                                     |
| Four players                          | Local Server, 4 players                                     |
| Player reconnecting                   | Published test place: leave and rejoin the same session     |
| Player leaving during an objective    | Close one client window mid-puzzle                          |
| Invalid interactions                  | Out of range, wrong phase, spammed input                    |
| Character respawning                  | Reset character during each system                          |
| Puzzle synchronisation                | Change puzzle state on one client, observe on the other     |
| Enemy AI behaviour                    | Trigger each state; confirm fairness rules                  |

Per-system tables are added here as each system is implemented.
