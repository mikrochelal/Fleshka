# Testing Checklist

Record the result and date for every test. Result values: **Pass**, **Fail**, **Not run**,
**Blocked**. Never mark Pass without actually running the test.

## Automated checks

Run `scripts/check.sh` before every commit.

| Check                           | Result | Date       | Notes                         |
| ------------------------------- | ------ | ---------- | ----------------------------- |
| Workspace not mapped in Rojo    | Pass   | 2026-11-12 |                               |
| `rojo build`                    | Pass   | 2026-11-12 | Rojo 7.7.1                    |
| `stylua --check src tests`      | Pass   | 2026-11-12 |                               |
| `selene src`                    | Pass   | 2026-11-12 | 0 errors, 0 warnings          |
| Unit tests (`tests/run.luau`)   | Pass   | 2026-11-12 | 28/28, Luau CLI 0.746         |
| `luau-lsp analyze` (strict)     | Pass   | 2026-11-12 |                               |

## Phase 1 — manual tests in Roblox Studio

| #   | Test                                                        | Expected                                             | Result  | Date       |
| --- | ----------------------------------------------------------- | ---------------------------------------------------- | ------- | ---------- |
| 1.1 | `rojo serve`, then Connect in the Studio Rojo plugin        | Plugin shows "Connected"; no errors                  | Pass    | 2026-11-12 (implied by 1.4) |
| 1.2 | Look at Explorer after connecting                           | `ReplicatedStorage.Shared`, `ReplicatedStorage.Config`, `ServerScriptService.TheLastSignal`, `StarterPlayerScripts.TheLastSignal` exist | Not run |  |
| 1.3 | Put a test Part in Workspace, disconnect and reconnect Rojo | The Part is still there                              | Not run |            |
| 1.4 | Press Play, read Output                                     | Server and client startup lines, no TLS warnings     | Pass    | 2026-11-12 (owner, v0.1.0) |
| 1.5 | Connect Rojo twice in a row                                 | No duplicated folders or scripts                     | Not run |            |

## Phase 2 — manual tests in Roblox Studio

### One-time setup: debug test objects

With the game **stopped**, open **View → Command Bar**, paste this single line and press
Enter. It creates two test cubes in `Workspace.TLS_DebugTest`. It is safe to run twice: if
the folder exists it changes nothing. Delete the folder when it is no longer needed.

```lua
local f = workspace:FindFirstChild("TLS_DebugTest") if f then print("TLS_DebugTest already exists - nothing changed") else f = Instance.new("Folder") f.Name = "TLS_DebugTest" local function make(name, kind, text, pos, color) local p = Instance.new("Part") p.Name = name p.Anchored = true p.Size = Vector3.new(3, 3, 3) p.Position = pos p.Color = color p:SetAttribute("Kind", kind) p:SetAttribute("Id", name) p:SetAttribute("ActionText", text) p:AddTag("TLS_Interactable") p.Parent = f end make("ToggleTest", "DebugToggle", "Toggle", Vector3.new(8, 2, -8), Color3.fromRGB(80, 200, 200)) make("PhaseTest", "DebugAdvancePhase", "Next phase", Vector3.new(-8, 2, -8), Color3.fromRGB(200, 60, 60)) f.Parent = workspace print("Created TLS_DebugTest") end
```

The positions assume the default Baseplate with the spawn near the centre; move the cubes
if your place is different.

### Tests

| #    | Test                                              | Expected                                                                                       | Result  | Date |
| ---- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------- | ---- |
| 2.1  | Press Play, read Output                           | `[TLS:SessionService] Mode: Studio, phase: Lobby`; `[TLS:Interaction] 2 tagged object(s) found`; `[TLS:Server] … v0.2.0 started: 3 services, 2 systems`; `[TLS:Client] Client started: 1 controllers`; `[TLS:Session] Phase: Lobby`; no TLS warnings | Not run | |
| 2.2  | Ready handshake                                   | Output shows `[TLS:PlayerService] <name> joined` then `<name> is ready`                         | Not run |      |
| 2.3  | Walk to the cyan cube, press E (tap on mobile)    | Prompt "Toggle" appears within about 10 studs; cube glows; Output `[TLS:Debug] <name> toggled "ToggleTest" -> on`; again → off | Not run | |
| 2.4  | Hold/spam E on the cyan cube                      | Never more than about 4 toggles per second                                                     | Not run |      |
| 2.5  | Walk to the red cube, press E six times (slowly)  | Server: `Phase: Lobby -> Loading` … `Ending -> Lobby`; client `[TLS:Session]` prints the same changes | Not run | |
| 2.6  | Reset character (Esc → Reset), interact again     | Interaction still works after respawn                                                          | Not run |      |
| 2.7  | Local Server with 2 players: player 1 toggles     | Player 2 sees the cube glow; both clients log phase changes from the red cube                  | Not run |      |
| 2.8  | Local Server with 4 players                       | Four `joined` / `is ready` pairs; interaction works for each                                   | Not run |      |
| 2.9  | Close one client window during 2.7                | Output `[TLS:PlayerService] <name> left`; no errors; other player unaffected                   | Not run |      |
| 2.10 | Stop and Play again                               | Still exactly one `TLS_Prompt` per cube and one `TLS_Remotes` folder                           | Not run |      |
| 2.11 | Exploit paths (trigger from too far / through a wall / forged remote arguments) | Request ignored by the server                               | Not run — needs a custom test client | |
| 2.12 | Reconnect within 120 s                            | Output shows `<name> reconnected`                                                              | Blocked — needs a published place | |

## Standard scenarios (apply to every gameplay system)

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
