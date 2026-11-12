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
| Map unit tests (`tests/map.luau`) | Pass | 2026-11-12 | 2887/2887, layout v4 (55 rooms): original 29 rooms unchanged, no overlapping parts, character flood fill reaches every room, two door signs per connection |
| THE COPY rules (`tests/copy.luau`) | Pass | 2026-11-12 | 45/45: waking, fairness, warning, lost sight, time limit, catch, cooldowns |
| Gameplay data (`tests/props.luau`) | Pass | 2026-11-12 | 175/175 against layout v4 |
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
| 2.1  | Press Play, read Output                           | `[TLS:SessionService] Mode: Studio, phase: Lobby`; `[TLS:Interaction] 2 tagged object(s) found`; `[TLS:Server] … started: 6 services, 15 systems`; `[TLS:Client] Client started: 7 controllers`; `[TLS:Session] Phase: Lobby`; no TLS warnings | Pass (owner; build with 2 systems, before OverheadGuard) | 2026-11-12 |
| 2.2  | Ready handshake                                   | Output shows `[TLS:PlayerService] <name> joined` then `<name> is ready`                         | Pass (owner) | 2026-11-12 |
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

## Draft map generator — manual tests in Roblox Studio

Commands are in `docs/MAP_GENERATOR.md`. Run them in the Command Bar with the game stopped.

| #    | Test                                                   | Expected                                                                                  | Result  | Date |
| ---- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------- | ------- | ---- |
| M.1  | After Rojo sync, look at Explorer                      | `ServerStorage.TLS_DevTools.MapGenerator` exists with children `Builder`, `Layout`, `Plan`, `Shell` | Pass (owner, v1 files) | 2026-11-12 |
| M.2  | Run `generate()` (no map yet)                          | Output `[TLS:MapGenerator] Created Workspace.Station09: 29 rooms, 26 doors, 4 archways, 53 lights, … parts (layout v3, ceilings shown)` | Partially — the owner generated layout v2 in Studio; v3 not run | 2026-11-12 |
| M.3  | Run `generate()` again                                 | Warning "already exists - nothing changed"; still exactly one `Station09`                 | Not run |      |
| M.4  | Run `regenerate()` over the v2 map                     | Old map moved to `ServerStorage.TLS_MapBackups.Station09_v2_backup_…`; one new `Station09`; Output shows layout v3; room positions identical to v2 | Not run | |
| M.5  | Run `viewFromAbove()`                                  | Ceilings hidden; camera looks straight down; if the Baseplate is above, Output explains the limited view | Not run | |
| M.6  | Run `viewFromAbove("MainLab")`, then `"CommCenter"`, `"MainCorridor"` | Each room is framed from above with its interior visible; no dark slab covers it | Not run | |
| M.7  | With ceilings hidden, look at the station at an angle  | Rock between rooms is no higher than the lowest walls; floors, walls and door frames all still present | Not run | |
| M.8  | With ceilings hidden, click inside a room              | A wall, floor or prop is selected, never a ceiling or roof part                           | Not run |      |
| M.9  | Run `showCeilings()`                                   | Ceilings and roof are back; from outside the station is one closed block                  | Not run |      |
| M.10 | Run `hideCeilings()`, then press Play                  | Output `[TLS:OverheadGuard] N hidden ceiling part(s) shown for this play session`; ceilings visible in game; after Stop they are hidden again in Edit mode | Not run | |
| M.11 | Run `hideCeilings()`, then `regenerate()`              | New map is generated with ceilings still hidden                                           | Not run |      |
| M.12 | Lighting check with ceilings shown (Play Here in several rooms) | All rooms similarly lit: cold, dim, no white-out and no blue cast; tunnel and airlock red | Not run | |
| M.13 | Run `applyLightingPreset()`, look around, then `restoreLighting()` | Preset: no daylight, dark cold ambient. Restore: `Lighting` properties back to their previous values. Running the preset twice changes nothing the second time | Not run | |
| M.14 | Visual check inside                                    | No gaps between walls, floors and rock; no flickering surfaces; every doorway has a frame; lights on in every room | Not run | |
| M.15 | Play Here in the Elevator; walk to the Radio Mast, the Archive and through the Service Tunnel | Every passage is passable; thresholds do not stop the character; nowhere to fall out | Not run | |
| M.16 | Rename a hand-made Folder to `Station09` (generated one moved away), run `generate()` and `regenerate()` | Both refuse; the folder is untouched | Not run | |
| M.17 | Press Ctrl+Z after `regenerate()`                      | Previous state is restored                                                                | Not run |      |
| M.18 | Run `generate()` while the game is playing             | Refuses with "Stop the game first"                                                        | Not run |      |
| M.19 | Mobile emulator (Test → Device) walking the map        | Acceptable frame rate                                                                     | Not run |      |

## Expanded station (layout v4) — manual tests in Roblox Studio

| #    | Test | Expected | Result | Date |
| ---- | ---- | -------- | ------ | ---- |
| X.1  | Run `regenerate()` | Old map moved to `ServerStorage.TLS_MapBackups.Station09_v3_backup_…`; Output `Created Workspace.Station09: 55 rooms, 53 doors, 6 archways, 99 lights, … parts (layout v4, …)` (about 1,230 parts) | Not run | |
| X.2  | Explorer: `Workspace.Station09` | Eight zone folders `A_Entrance` … `H_Containment`, plus `Doors`, `Archways`, `Shell`, `Markers` | Not run | |
| X.3  | `viewFromAbove()` then `showOverlay()` | Every room labelled with name and purpose; the original rooms where they were; SPAWN, COPY VANTAGE, BREAKER, LOCKED and NEEDS POWER markers visible | Not run | |
| X.4  | `hideOverlay()`; and separately press Play with the overlay shown | Labels gone; in Play Output shows `Developer overlay hidden for this play session` and no labels are visible | Not run | |
| X.5  | `listRooms()` | 55 lines in Output | Not run | |
| X.6  | Walk: Junction → east to the Isolation Chamber | Passable; medical wing looks different from the corridors; quarantine part lit red before power | Not run | |
| X.7  | Walk: North Corridor → Archive Corridor → all four archive rooms | Passable; brick walls | Not run | |
| X.8  | Walk: Power Room → Service Corridor → Generator Hall → Pipe Tunnel → Cargo Corridor → Checkpoint → Observation Chamber → Signal Source | Passable; the Signal Source is a tall room with a large core | Not run | |
| X.9  | Walk: Cargo Corridor → Access Control → Lobby; Service Corridor east door → South Corridor | Both loops passable | Not run | |
| X.10 | Look above doorways from both sides | The wall above each door shows the name of the room beyond; text upright, not mirrored | Not run | |
| X.11 | Visual check of new wings | No gaps, no flickering surfaces, no light leaking through walls | Not run | |
| X.12 | Play the slice on the new map (sections below) | Still completable; breakers, lever, radio, console, elevator where they were | Not run | |
| X.13 | Frame rate while walking the whole station, PC and mobile emulator | Acceptable (about 1,230 parts, 99 lights without shadows) | Not run | |

## Playable slice (version 0.3.0) — manual tests in Roblox Studio

Needs the generated map. None of these has been run yet. Controls: Shift sprint, F
flashlight, E interact, X close document.

### Start-up and spawning

| #    | Test | Expected | Result | Date |
| ---- | ---- | -------- | ------ | ---- |
| S.1  | Press Play, read Output | `[TLS:WorldService] Map found: 55 rooms` (29 with the old map); `[TLS:WorldProps] 10 gameplay object(s) placed`; `[TLS:FacilityLights] 99 light fixture(s) under control` (53 with the old map); `[TLS:Power] 3 breaker panel(s); start-up order generated`; `[TLS:Atmosphere] Underground base lighting applied for this play session`; `[TLS:Spawn] <name> placed at the station entrance`; phase lines `Lobby -> Loading -> Intro -> Playing`; no TLS warnings, no red errors | Not run | |
| S.2  | Watch the screen at start | Title card "STATION-09" for about 7 s, then the elevator room; character stands on the floor, not in a wall | Not run | |
| S.3  | Reset the character (Esc → Reset) | Respawns in the elevator | Not run | |
| S.4  | Play in a place without the map | One warning from WorldService explaining how to generate the map; no errors | Not run | |
| S.5  | Local Server, 4 players | All four in the elevator at different spots | Not run | |
| S.6  | Stop the game and look at Lighting properties | Same values as before Play (the dark lighting is runtime only) | Not run | |
| S.7  | Co-op: during the title card one player walks to the Power Room; after it, restore power before anyone else moves | Objectives catch up in order and end on the radio objective; nothing gets stuck | Not run | |

### Movement, stamina, flashlight

| #    | Test | Expected | Result | Date |
| ---- | ---- | -------- | ------ | ---- |
| P.1  | Hold Shift while walking | Faster; STAMINA bar drains in about 7 s; at zero the bar turns red and speed drops to walking | Not run | |
| P.2  | Release Shift | After about 1 s the bar refills; sprint works again from 25% | Not run | |
| P.3  | Hold Shift while standing still | Bar does not drain | Not run | |
| P.4  | Press F | A beam lights the walls ahead; HUD shows FLASHLIGHT ON; F again turns it off | Not run | |
| P.5  | Two players: one turns the light on | The other sees the beam | Not run | |
| P.6  | Leave the light on (or lower `BatteryMax` temporarily) | Percentage falls; below 15% the beam flickers and the bar is red; at 0 it switches off with a warning | Not run | |
| P.7  | With an empty battery, wait with the light off | Recharges slowly, never above 25% | Not run | |
| P.8  | Take a battery pack (Lockers) with a partly used battery | "Battery replaced", 100%, the pack disappears; with a full battery it is not consumed | Not run | |
| P.9  | Mobile emulator | RUN and LIGHT buttons on the right; both work; HUD readable | Not run | |

### Objectives, documents, power puzzle

| #    | Test | Expected | Result | Date |
| ---- | ---- | -------- | ------ | ---- |
| O.1  | Walk from the elevator into the lobby | Objective changes to "Find the emergency power controls"; the old one stays above it, dimmed and struck through | Not run | |
| O.2  | Read the document in the lobby | Viewer opens with title, date and text; CLOSE and X both close it | Not run | |
| O.3  | Read the memo in the Security Booth | Lists the three breakers in an order; a new session gives a (usually) different order | Not run | |
| O.4  | Enter the Power Room or switch any breaker | Objective changes to "Restore the facility power" | Not run | |
| O.5  | Before power: look around the corridors | Corridors dark; entrance lit; red lamps in the service tunnel and airlock | Not run | |
| O.6  | Switch a breaker | Panel turns amber, label "ENGAGED 1/3"; switching it again opens it | Not run | |
| O.7  | Pull the lever with fewer than three breakers | Warning "The lever will not move"; nothing changes | Not run | |
| O.8  | Engage all three in a wrong order, pull the lever | Warning, lights flicker, all breakers back to OFF | Not run | |
| O.9  | Engage in the memo's order, pull the lever | Lights surge, corridor lights come on, emergency lamps go out, panels green, "Emergency power restored", objective changes | Not run | |
| O.10 | Two players at different panels | Both see every panel change | Not run | |

### Radio, sighting, THE COPY, ending

| #    | Test | Expected | Result | Date |
| ---- | ---- | -------- | ------ | ---- |
| R.1  | Before power, look at the radio (Monitor Room) | Label "NO POWER", no prompt | Not run | |
| R.2  | After power | Label "INCOMING SIGNAL", notification about a receiver | Not run | |
| R.3  | Listen | Subtitles: static, "Station Nine... can anyone hear me?", pause, "Do not trust the voices.", pause with flicker, "IT KNOWS WE ARE LISTENING." with screen interference; then the objective changes | Not run | |
| R.4  | Walk into the main corridor afterwards | Lights flicker; a tall dark figure stands at the far end for a few seconds, or vanishes when approached; happens once | Not run | |
| R.5  | Use the console in the Comm Center before the radio | Message "No carrier signal"; no progress | Not run | |
| R.6  | Use the console after the radio | "Recall signal sent"; objective "Find a way to escape"; elevator panel gets a prompt | Not run | |
| C.1  | Fail the power puzzle, then wait near the lever with the flashlight on | Within about half a minute the figure may approach, stop and stare, then vanish; it does not chase | Not run | |
| C.2  | After R.6, walk back toward the elevator | Output shows `[TLS:Copy]` state changes; on sight: "IT HAS SEEN YOU.", interference, 2 s pause, then it follows | Not run | |
| C.3  | Sprint away and break line of sight | It loses you within about 5 s, searches, then disappears | Not run | |
| C.4  | Let it reach you | Screen fades to black, you wake in the Comm Center, others see "<name> was taken." | Not run | |
| C.5  | Watch it move through doorways | Follows corridors and doors, does not pass through walls | Not run | |
| C.6  | Check fairness over several minutes | Never appears in view or right next to a player; quiet periods between encounters | Not run | |
| E.1  | Use the elevator panel during "Find a way to escape" | Screen fades, subtitle "Thank you for bringing it outside.", card "SIGNAL LOST" with the time; KEEP EXPLORING closes it | Not run | |
| E.2  | Player joins mid-session | Sees the current objective and lighting state; is placed in the elevator | Not run | |
| E.3  | A player leaves during the puzzle or a chase | No errors; the others continue | Not run | |

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
