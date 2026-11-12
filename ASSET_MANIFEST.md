# Asset Manifest

Every external or placeholder asset used by the game. No asset ID may be used in code unless
it is listed here with its source and licence.

Status values: **Final** · **Placeholder** (must be replaced before release) · **Needed**
(not yet present in any form).

## Currently used

No asset IDs are referenced anywhere in the project.

The draft map generator (`docs/MAP_GENERATOR.md`) creates only plain parts with built-in
Roblox materials and `PointLight`s. Everything it creates is a placeholder:

| Generated content                                   | Status      | Replace with                              |
| --------------------------------------------------- | ----------- | ----------------------------------------- |
| Floors, walls, ceilings, rock shell and roof (blockout) | Placeholder | Final architecture / textured geometry |
| Door frames (jambs, header, threshold) and half-transparent walk-through door panels | Placeholder | Door models driven by the door system |
| Ceiling light fixtures (neon boxes)                 | Placeholder | Final fixtures and lighting design        |
| `Placeholder_*` boxes (desk, lockers, generator, monitor wall, lab benches, receiver, tape shelves, keypad, central computer, radio station, server racks, mast base, main lever) | Placeholder | Final props / puzzle models |
| `BreakerPanel_1..3` boxes                           | Placeholder | Breaker panel models for the power puzzle |

Created by the game at runtime (version 0.3.0), also from plain parts and all placeholders:

| Content                                              | Status      | Replace with                         |
| ---------------------------------------------------- | ----------- | ------------------------------------ |
| THE COPY body (`Systems/CopyAI/Body.luau`): six dark boxes forming a tall figure, moved without animation | Placeholder | Rigged, animated character model |
| Documents: a paper box on a plinth                   | Placeholder | Paper / clipboard models             |
| Radio receiver: a box on a table                     | Placeholder | Radio model                          |
| Battery packs: a box on a crate                      | Placeholder | Battery model                        |
| Elevator control panel: a wall box                   | Placeholder | Panel model                          |
| Floating text labels on breakers, lever and radio    | Placeholder | In-world displays / indicator lamps  |
| Flashlight: a `SpotLight` on the character's head, no visible torch | Placeholder | Held flashlight model and animation |

### Audio

`Config/AudioConfig.luau` names every sound the game can play. **Every id is empty**: no
audio asset has been chosen or verified, so the game is currently silent apart from
Roblox's default character footsteps.

| Cue | Used for | Status |
| --- | -------- | ------ |
| `Ambient.Ventilation`, `Ambient.ElectricalHum` | Loops during play | Needed |
| `Interact`, `DocumentOpen`, `BatteryPickup`, `FlashlightClick` | Interface and pickups | Needed |
| `BreakerEngage`, `BreakerTrip`, `PowerOn`, `LightFlicker` | Power puzzle and lights | Needed |
| `RadioStatic`, `RadioVoice` | Radio transmission | Needed (voice lines need recording; subtitles are the fallback) |
| `DoorOpen`, `DoorClose` | Door system (not built yet) | Needed |
| `DistantMetal` | Ambient one-shots (not triggered yet) | Needed |
| `CopyPresence`, `CopyAlert`, `Caught` | THE COPY | Needed |

## Needed (identified from the design, nothing chosen yet)

| Asset                                   | Type        | Used by                   | Status | Notes |
| --------------------------------------- | ----------- | ------------------------- | ------ | ----- |
| Facility room tone / ambience loops     | Audio       | All areas                 | Needed |       |
| Radio static, carrier tone, squelch     | Audio       | Radio, frequency puzzle   | Needed |       |
| Radio voice lines (incl. final line)    | Audio       | Story, ending             | Needed | Subtitles are the fallback until recorded |
| Footsteps, doors, breakers, keypad      | Audio       | Gameplay feedback         | Needed |       |
| THE COPY presence and pursuit cues      | Audio       | Enemy AI                  | Needed |       |
| Menu and ending music                   | Audio       | UI, ending                | Needed |       |
| THE COPY character model                | Model       | Enemy AI                  | Needed | Part-built placeholder planned for Phase 5 |
| Facility props (desks, racks, monitors) | Models      | World                     | Needed | Graybox parts first |
| UI icons (stamina, battery, settings)   | Images      | HUD, menus                | Needed | Drawn with UI primitives until final icons exist |

## Rules

1. Prefer original assets or assets the project owner uploaded.
2. Roblox Creator Store assets are allowed when their licence permits use; record the asset
   ID, creator and URL here.
3. A placeholder is never presented as final.
