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

| What                           | Command                                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------------------- |
| Create the map                 | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).generate()`                |
| See what exists                | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).status()`                  |
| Hide ceilings (view from above) | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).setCeilingsVisible(false)` |
| Show ceilings again            | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).setCeilingsVisible(true)`  |
| Rebuild after a layout change  | `require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).regenerate()`              |

`:Clone()` makes Studio run the latest synced code rather than a cached copy.

Results are printed in the Output window with the prefix `[TLS:MapGenerator]`.
`generate()` and `regenerate()` can be undone with Ctrl+Z.

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
   The folder must contain `init.luau`, `Layout.luau`, `Plan.luau` and `Builder.luau`. If it
   does not exist, update to the main development branch:
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

- The tool only ever creates or moves `Workspace.Station09`. Nothing else in the place is
  read, changed or deleted, including `Lighting`.
- `generate()` changes nothing if `Workspace.Station09` already exists.
- `regenerate()` never deletes anything: the previous generated map is moved to
  `ServerStorage.TLS_MapBackups.Station09_backup_<date>_<time>`. Delete old backups by hand
  when they are no longer needed.
- A `Workspace.Station09` that the tool did not create (no `TLS_Generated` attribute) is
  never touched by any command.
- Both commands refuse to run while the game is playing.
- The layout is validated before anything is created or moved; a broken layout leaves the
  place unchanged.

**Hand-made additions:** build them in a separate folder such as
`Workspace.Station09_Custom`, not inside `Station09`. `regenerate()` moves the whole
generated folder to the backups, including anything added inside it.

## What is generated

The station is placed 60 studs below the default Baseplate, so it is underground.

```text
Workspace.Station09            (attributes: TLS_Generated, TLS_GeneratorVersion)
  A_Entrance/                  Elevator, Lobby, SecurityBooth, Checkpoint, Lockers
  B_Corridors/                 MainCorridor, Office101, Storage102, MonitorRoom, PowerRoom,
                               Maintenance, EastCorridor, ServiceTunnel
  C_Laboratory/                Airlock, MainLab, SignalChamber, Archive, Observation
  D_CommCenter/                Antechamber, CommCenter, ServerRoom, RadioMast
    <Room>/
      Floor, Ceiling
      Walls/                   Wall_<side>_<n>, Lintel_<side>_<n>
      Lights/                  Light_<n>  (PointLight inside; tag TLS_Light, attribute Circuit)
      Zone                     invisible room volume (tag TLS_Zone, attributes Area, ZoneId)
      Props/                   Placeholder_* boxes and BreakerPanel_* (tag TLS_BreakerPanel)
  Doors/                       Door_<RoomA>_<RoomB> models (tag TLS_Door; attributes DoorId,
                               RequiresPower, Locked)
  Markers/                     Spawn_Start (TLS_Spawn), CopyVantage_* (TLS_CopyVantage)
```

Route: Elevator → Lobby → Checkpoint → Main Corridor → East Corridor → Laboratory (north)
and Communication Center (south). The Service Tunnel is a shortcut loop from the Monitor
Room to the East Corridor.

Draft conventions:

- Doors are half-transparent and can be walked through until the door system exists.
  Red doors are the ones that will be locked (security code).
- Muted-cyan boxes are stand-ins for puzzle objects; grey boxes for furniture.
- East Corridor and Service Tunnel use red emergency lights; everything else cold white.
- Only built-in materials and plain parts are used. No asset IDs.
- Global `Lighting` settings, fog, sounds and decoration are **not** part of the draft.

## Inspecting the result

1. In **Explorer**, expand `Workspace → Station09`.
2. Click `Station09` and press **F** — the camera jumps to the map (it is under the
   Baseplate).
3. Run the "Hide ceilings" command to look at the floor plan from above.
4. To walk through it: move the camera into the Elevator room, right-click the floor and
   choose **Play Here**.

## Changing the layout

Edit `Layout.luau`: rooms are rectangles, connections are openings between rooms that share
an edge. Then:

1. Run `scripts/check.sh` — `tests/map.luau` verifies that rooms do not overlap, every
   doorway is really open, and every room is reachable.
2. Increase `version` in `Layout.luau`.
3. Run `regenerate()` in Studio.

| File           | Role                                                        |
| -------------- | ----------------------------------------------------------- |
| `Layout.luau`  | The floor plan as data (rooms, connections, props, markers) |
| `Plan.luau`    | Validation and geometry math (no Roblox API; unit tested)   |
| `Builder.luau` | Creates the Roblox instances, materials and lights          |
| `init.luau`    | Commands and safety rules                                   |
