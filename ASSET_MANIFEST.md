# Asset Manifest

Every external or placeholder asset used by the game. No asset ID may be used in code unless
it is listed here with its source and licence.

Status values: **Final** · **Placeholder** (must be replaced before release) · **Needed**
(not yet present in any form).

## Currently used

None. The project contains code only; no asset IDs are referenced.

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
