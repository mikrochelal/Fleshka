# STATION-09 draft map generator

A development tool that builds a preliminary blockout of STATION-09 in Roblox Studio. It is
separate from gameplay code: nothing in the game requires it, and it does nothing until it
is called by hand.

- Code: `src/ServerStorage/DevTools/MapGenerator/` → Studio: `ServerStorage.TLS_DevTools.MapGenerator`
- Result: `Workspace.Station09` (stored in the place file, **not** in Git)

## Running it

Rojo must be connected and the game must be **stopped** (Edit mode). In Play mode the
commands refuse to run, because anything created while playing disappears when the game
stops. Open **View → Command Bar**, paste one line and press Enter.

| What                              | Command |
| --------------------------------- | ------- |
| Create the map (first time)       | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).generate()` |
| Rebuild after a generator update  | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).regenerate()` |
| Top view of the whole station     | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).viewFromAbove()` |
| Top view of one room              | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).viewFromAbove("MainLab")` |
| Hide ceilings and roof            | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).hideCeilings()` |
| Show ceilings and roof            | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).showCeilings()` |
| Dark base lighting (optional)     | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).applyLightingPreset()` |
| Undo the dark base lighting       | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).restoreLighting()` |
| See what exists                   | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).status()` |

`:Clone()` makes Studio run the latest synced code rather than a cached copy.

Results are printed in the Output window with the prefix `[TLS:MapGenerator]`.
Every command that changes something can be undone with Ctrl+Z.

## Ceilings and roof

Everything that covers the interior from above carries the tag `TLS_Overhead`:

- each room's own `Ceiling`;
- `Shell/Roof/Roof_<Room>` — one section per room, filling the space between that room's
  ceiling and the top of the station;
- `Shell/RockCaps/RockCap_<n>` — the upper part of the rock between rooms.

There is no station-wide slab, and none of these parts overlap. The structural rock
(`Shell/Rock`) stops at the height of the lowest ceiling, so nothing stands above the room
walls once the overhead parts are hidden.

`hideCeilings()` makes exactly the `TLS_Overhead` parts invisible and locked, so you can
look into the rooms and click objects inside them. Floors, walls, door frames and the
structural rock are never changed, and the hidden parts keep their collision.
`showCeilings()` restores them. The state is remembered: `regenerate()` keeps ceilings
hidden if they were hidden, and `status()` reports it.

Hiding is an editing aid only. When the game runs, `Systems/OverheadGuard` shows every
hidden `TLS_Overhead` part for that play session, so a playtest always has ceilings. The
saved place is not modified by this.

## Viewing from above

`viewFromAbove()` hides the ceilings and places the Studio camera straight above the
station, north at the top of the screen. `viewFromAbove("MainLab")` frames one room; the
name works with or without the area prefix (`"C_MainLab"`).

The station is under the Baseplate, and the camera cannot see through it. When something is
above the station, the camera stays just below it and the command says so; in that case the
whole station does not fit in one view — frame rooms one at a time, or zoom and pan from
there. Only the editor camera is moved.

## Lighting

Every room uses the same lamp: a cold, slightly desaturated, deliberately dim point light
(`Brightness 0.55`, `Range 20`). The service tunnel and the airlock use a dimmer red
emergency lamp. Surfaces share one dark, low-saturation palette, so no area reads as white
or blue.

The generator does not change the place's global `Lighting` on its own. With the default
daytime settings the interior still receives sky light whenever ceilings are hidden, which
washes the rooms out. `applyLightingPreset()` is an optional, reversible step that prepares
the place for horror lighting:

| Property                   | Value            | Why                                   |
| -------------------------- | ---------------- | ------------------------------------- |
| `Brightness`               | 0                | No sunlight underground               |
| `Ambient`, `OutdoorAmbient` | RGB 22, 25, 29  | Low cold fill; corners dark, not black |
| `EnvironmentDiffuseScale`, `EnvironmentSpecularScale` | 0 | No sky colour on surfaces |
| `ExposureCompensation`     | 0                | Neutral exposure                      |

The previous values are stored as attributes on `Lighting` (`TLS_Prev_*`) and
`restoreLighting()` puts them back. Fog, post-processing and the final mood are not part of
this and come later.

## Troubleshooting: "MapGenerator was not found"

The generator reaches Studio only through Rojo, from the mapping
`ServerStorage.TLS_DevTools → src/ServerStorage/DevTools` in `default.project.json`. If it is
missing in Studio, the local copy of the repository is older than that mapping, or Rojo is
still serving the old project.

1. Check the local copy. In the repository folder:
   ```bash
   git branch --show-current
   ls src/ServerStorage/DevTools/MapGenerator
   ```
   The folder must contain `init.luau`, `Layout.luau`, `Plan.luau`, `Shell.luau`,
   `Builder.luau` and `LightingPreset.luau`. If it does not, update to the main development branch:
   ```bash
   git fetch origin
   git checkout hoplite/katane-c6d07c95
   git pull
   ```
2. Stop `rojo serve` (Ctrl+C) and start it again. A running server does not reliably pick
   up changes to `default.project.json`.
3. In Studio: **Plugins → Rojo → Disconnect**, then **Connect**. If the plugin shows a list
   of changes, press **Accept**.
4. Verify in the Command Bar (game stopped):
   ```lua
   local t = game.ServerStorage:FindFirstChild("TLS_DevTools") print(t and t:FindFirstChild("MapGenerator") and "MapGenerator OK" or "MapGenerator missing")
   ```

`scripts/check.sh` fails if the Rojo tree stops containing the generator.

## Safety rules

- `generate()` and `regenerate()` only ever create or move `Workspace.Station09`. Nothing
  else in the place is changed or deleted.
- Two commands touch something else, and only when you call them: `viewFromAbove()` moves
  the editor camera, and `applyLightingPreset()` changes six `Lighting` properties and can
  be undone with `restoreLighting()`.
- `generate()` changes nothing if `Workspace.Station09` already exists.
- `regenerate()` never deletes anything: the previous generated map is moved to
  `ServerStorage.TLS_MapBackups.Station09_v<layout>_backup_<date>_<time>`. Delete old
  backups by hand when they are no longer needed.
- A `Workspace.Station09` that the tool did not create (no `TLS_Generated` attribute) is
  never touched by any command.
- `generate()` and `regenerate()` refuse to run while the game is playing.
- The layout is validated before anything is created or moved; a broken layout leaves the
  place unchanged.
- The result is predictable: the same `Layout.luau` always produces the same parts with the
  same names in the same places.

**Hand-made additions:** build them in a separate folder such as
`Workspace.Station09_Custom`, not inside `Station09`. `regenerate()` moves the whole
generated folder to the backups, including anything added inside it.

## What is generated (layout v3)

One connected underground structure, 60 studs below the default Baseplate. An east-west
spine corridor has rooms wall to wall on both sides and ends in a junction hall; one wing
runs north to the laboratory, one south to the communication center. All space between and
around the rooms is solid rock. Layout v3 keeps the v2 floor plan exactly; only the roof
structure, materials and lamps changed.

```text
                                        Archive
                                           |
                            Airlock == MainLab -- SignalChamber
                               |        |     |
                               |   Observation ColdStorage
              ServiceTunnel ---+
                   |           | NorthCorridor
 Elevator  SecurityBooth  Office101 Storage102 MonitorRoom Records104
    |          |              |         |           |          |
  Lobby --- Checkpoint === MainCorridor ====================== Junction
    |                         |         |           |          |
  Lockers                PowerRoom  Maintenance  BreakRoom  Infirmary
                               | SouthCorridor -- OperatorOffice
                               |
                          Antechamber =(code)= CommCenter -- ServerRoom
                                                   |
                                               RadioMast
```

```text
Workspace.Station09            (attributes: TLS_Generated, TLS_GeneratorVersion, TLS_CeilingsHidden)
  A_Entrance/                  Elevator, Lobby, SecurityBooth, Checkpoint, Lockers
  B_Corridors/                 MainCorridor, Office101, Storage102, MonitorRoom, Records104,
                               PowerRoom, Maintenance, BreakRoom, Infirmary, Junction,
                               NorthCorridor, SouthCorridor, ServiceTunnel
  C_Laboratory/                Airlock, MainLab, SignalChamber, Archive, Observation, ColdStorage
  D_CommCenter/                OperatorOffice, Antechamber, CommCenter, ServerRoom, RadioMast
    <Room>/
      Floor, Ceiling           (Ceiling: tag TLS_Overhead)
      Walls/                   Wall_<side>_<n>, Lintel_<side>_<n>
      Lights/                  Light_<n>  (PointLight inside; tag TLS_Light, attribute Circuit)
      Zone                     invisible room volume (tag TLS_Zone, attributes Area, ZoneId)
      Props/                   Placeholder_* boxes and BreakerPanel_* (tag TLS_BreakerPanel)
  Doors/                       Door_<RoomA>_<RoomB> models: Frame/ (Jamb_1, Jamb_2, Header,
                               Threshold) + Panel (tag TLS_Door; attributes DoorId,
                               RequiresPower, Locked)
  Archways/                    Archway_<RoomA>_<RoomB> models: Frame/ only (open passages)
  Shell/
    Rock/                      Rock_<n> - structural fill between rooms, up to the lowest ceiling
    RockCaps/                  RockCap_<n> - upper rock (tag TLS_Overhead)
    Roof/                      Roof_<Room> - one section per room (tag TLS_Overhead)
  Markers/                     Spawn_Start (TLS_Spawn), CopyVantage_* (TLS_CopyVantage)
```

Proportions: main corridors are 12 studs wide and 12 high, the service tunnel 8 wide and
10 high, ordinary rooms 12 high, the lobby and junction 14, the main lab and communication
center 16. Doorways are 4–8 studs wide with 7.4 studs of headroom.

Draft conventions:

- Door panels are half-transparent and can be walked through until the door system exists.
- Frame colour shows the kind of passage: dark = ordinary, cyan = needs power (bulkheads and
  the shortcut), red = the security-code door.
- Muted-cyan boxes are stand-ins for puzzle objects; grey boxes for furniture.
- The service tunnel and the airlock use red emergency lamps; every other room uses the same
  dim cold lamp.
- Only built-in materials and plain parts are used. No asset IDs.
- Fog, post-processing, sounds and decoration are **not** part of the draft.

## Inspecting the result

1. Run `viewFromAbove()`. The ceilings are hidden and the camera looks straight down.
2. If the Output says something is above the station, frame rooms one at a time, for
   example `viewFromAbove("MainCorridor")`, `viewFromAbove("MainLab")`,
   `viewFromAbove("CommCenter")`.
3. To work inside a room: click its folder in Explorer (for example
   `B_Corridors → B_MainCorridor`) and press **F**.
4. To walk through it: move the camera into `A_Elevator`, right-click the floor and choose
   **Play Here**. Ceilings are shown automatically while the game runs.

## Changing the layout

Edit `Layout.luau`: rooms are rectangles, connections are openings between rooms that share
an edge. Then:

1. Run `scripts/check.sh` — `tests/map.luau` verifies that no two solid parts overlap, every
   passage is clear, and a character-sized flood fill from the spawn point reaches every
   room, marker and doorway. It also pins the reference floor plan: after an intended
   change, update the two checksums in that test.
2. Increase `version` in `Layout.luau`.
3. Run `regenerate()` in Studio.

| File           | Role                                                          |
| -------------- | ------------------------------------------------------------- |
| `Layout.luau`  | The floor plan as data (rooms, connections, props, markers)   |
| `Plan.luau`    | Validation; walls, lights, door frames (no Roblox API; tested) |
| `Shell.luau`   | Rock fill, rock caps, roof sections (no Roblox API; tested)   |
| `Builder.luau` | Creates the Roblox instances, materials and lights            |
| `LightingPreset.luau` | Optional, reversible dark base lighting                |
| `init.luau`    | Commands and safety rules                                     |
