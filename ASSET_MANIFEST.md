# Asset Manifest

Every external or placeholder asset used by the game. No asset ID may be used in code unless
it is listed here with its source and licence (`scripts/check.sh` enforces this for audio).

Status values: **Final** · **Placeholder** (must be replaced before release) · **Needed**
(not yet present in any form).

## Audio (version 0.5.0)

All sounds are defined in `src/ReplicatedStorage/Config/AudioConfig.luau`. The table `ASSETS`
at the top of that file maps every cue to one asset id; to replace a sound, change its
number there and in the table below. Nothing else in the code refers to an id.

**Source and licence.** Every id below is from the Roblox Creator Store audio library
published by the verified creator **ProSoundEffects** (user id 7462895450) — the sound
effects Roblox licenses for use in any experience, free of charge
(`https://create.roblox.com/store/asset/<id>`). Each id was found through the Creator Store
search API and re-checked through the asset details API on 2026-11-12: asset type Audio,
creator ProSoundEffects, moderation-approved, free.

**What was not verified.** The assets were chosen by **name, description and duration only**.
Nobody has listened to them in this project, and they have not been played inside the
experience. Until the owner hears each one in Studio, every entry is a **Placeholder**:
expect to swap some (see "Weak matches"). If a sound stays silent in Studio, open
*View → Output*: a sound that fails to load is reported there by Roblox with its id.

| Cue | Asset id | Creator Store name | Seconds | Used for |
| --- | --- | --- | --- | --- |
| `AmbRoomTone` | 9125446564 | Command Room Tone Deep Air Conditioning Hum  | 35 | Base ambience, always on during play |
| `AmbVentilation` | 9125446543 | Command Room Tone Deep Air Conditioning Hum  | 18 | Ambience after power returns; Ventilation plant room tone |
| `AmbElectricalHum` | 9112889082 | Transformer Hum 1 | 36 | Ambience after power returns; transformer and relay cabinet emitters |
| `AmbMachineryDistant` | 9112839126 | Oil Refinery Ambience 1 | 32 | Power wing and cold storage room tone |
| `AmbPipes` | 9125742113 | Pipe Water Rush Through Elbow Joint Of Pvc P | 44 | Pipe tunnel room tone and emitter |
| `AmbServerRoom` | 9112825161 | Machine Room 2 | 56 | Communication wing room tone; server room emitter |
| `AmbFluorescent` | 9112823813 | Light Bulb Buzz 2 | 49 | Laboratory and medical room tone |
| `AmbTunnel` | 9114795437 | Hell Entrance 5 | 41 | Service tunnel, archives and freight wing room tone |
| `AmbSource` | 9126086563 | Synth Tone Rumbly Pulsing Rizzy Smooth Evil  | 31 | Observation chamber / signal source room tone and emitter |
| `GeneratorLoop` | 9112787430 | Go Kart Engine Constant 1 | 27 | Main generator emitter |
| `FanLoop` | 9112839511 | Oil Refinery Ambience 2 | 51 | Ventilation plant emitter |
| `RadioStaticLoop` | 9118026602 | Radio Static 1 | 3 | Receiver and radio desk static (stand-in: the short static burst, looped) |
| `ElevatorLoop` | 9112777259 | Elevator Room 1 | 56 | Freight lift running (finale) |
| `AlarmLoop` | 9114024787 | Damage Zone Alarm 2 | 28 | Evacuation alarm |
| `DistantMetal1` | 9114225758 | Echoing Metal Bangs 5 | 6 | Random distant noise |
| `DistantMetal2` | 9116638811 | Metal Groans Twisting Creaking Movement 6 | 12 | Random distant noise |
| `DistantMetal3` | 9116844094 | Metal Shake Clunking Bursts Light Banging 3 | 2 | Random distant noise |
| `DoorOpen` | 9116744819 | Metal Pig Feeder Door Creaky Open Close 3 | 6 | Walking through a door; sealed door opening |
| `DoorClose` | 9119631707 | Steel Door 3 | 3 | Door closing behind a player |
| `DoorLocked` | 9118899039 | Security Gate 1 | 5 | Trying a sealed door |
| `HeavyDoorOpen` | 9116983420 | Motor Whir Floor Raising Lowering 6 | 13 | Bulkhead unsealing |
| `ButtonPress` | 9119717523 | Switch Click On Or Off Toggle Button 2 | 0 | Reserved for buttons (not triggered yet) |
| `SwitchFlip` | 9117028848 | Moviola Toggle Switch Single Clicks Sharp 9 | 1 | Main lever, feeders, generator to full load |
| `BreakerEngage` | 9119717286 | Switch Circuit Breaker Clicks 9 | 1 | Breaker engaged |
| `BreakerTrip` | 9114277623 | Electric Zaps 8 | 2 | Breaker rejected; feeder overload |
| `PowerOn` | 9114583503 | Giant Servo Motor Powering Up 2 | 5 | Emergency power start-up; generator full load |
| `PowerDown` | 9117869243 | Power Down 1 | 1 | Laboratory blackout |
| `RelayClick` | 9118138684 | Relay Clicks 14 | 0 | Relays during power start-up; relay closing |
| `MachineryStart` | 9116921374 | Milling Machine 8 | 10 | Power restored; relay online; fans; mast |
| `LightFlicker` | 9116270244 | Light Bulb Buzz 3 | 8 | Lights flickering |
| `FuseInsert` | 9116545335 | Metal Clunks Heavy Latch Mechanism 3 | 4 | Fuse fitted |
| `ElevatorStart` | 9114533169 | Freight Elevator 1 | 9 | Freight lift departing |
| `TerminalBeep` | 9113880475 | Computer Keyboard Beep 3 | 0 | Console read-outs; objective complete (slowed) |
| `KeypadPress` | 9117060548 | Nasa Transmission Beep 4 | 1 | Keypad keys |
| `AccessDenied` | 9113085665 | Alarm Buzzer 3 | 1 | Wrong code; dead arrival elevator |
| `AccessGranted` | 9125540237 | Electronic Tinkles Sharp Relay Falling Beeps | 0 | Correct code; carrier locked; evacuation authorised |
| `WarningBeep` | 9113392257 | Beeps Constant Up And Down Tonal 1 | 7 | Power restored; console warnings; evacuation announcement |
| `DocumentOpen` | 9118835414 | Scrapbook Open And Turn Pages 2 | 1 | Opening a document |
| `ItemPickup` | 9113577259 | Box Of Bullets 1 | 4 | Picking up the fuse or the tape |
| `BatteryInsert` | 9119717529 | Switch Click On Or Off Toggle Button 1 | 0 | Battery pack used |
| `FlashlightClick` | 9114480271 | Flashlight On Off Clicks 13 | 1 | Flashlight switch |
| `RadioStaticBurst` | 9118026602 | Radio Static 1 | 3 | Transmissions; receiver pulse (Aware) |
| `RadioInterference` | 9113404662 | Beeps Squawks Static Sporadic Buzzy Bursts 1 | 15 | Transmissions; wrong channel; receiver pulse (Hunting) |
| `RadioVoice` | 9125774594 | Police Radio Line Feed Radio Voices Static 1 | 4 | Voice lines of transmissions; receiver pulse (Final pursuit) |
| `RadioWhisper` | 9126213995 | Whisper Bursts Unintelligible Eerie Evil Gho | 3 | Trace, reply, evacuation PA; receiver pulse (Hostile) |
| `RadioTune` | 9118028978 | Radio Tuning 6 | 3 | Channel selector |
| `FinalSignal` | 9125712561 | Nightmare Yelling Bursts Of Distorted Scream | 14 | The ending's scream-like signal |
| `CopyPresenceLoop` | 9112795295 | Hollow Rumble 1 | 66 | THE COPY: presence loop on its body |
| `CopyFootstepsLoop` | 9125818886 | Robot Footsteps Walking Slowly Metal Surface | 4 | THE COPY: footsteps loop (speed follows its state) |
| `HeartbeatLoop` | 9114549012 | Fuzzy Synth Throbs 1 | 29 | Player heartbeat as dread rises |
| `CopyDistant` | 9125842589 | Robot Vocals Deep Guttural Grunting Growling | 2 | THE COPY: distant presence cue; scripted sighting |
| `CopySearch` | 9125475729 | Creature Vocal Spider Growl Belch Hiss Snarl | 1 | THE COPY: starts searching (random chance) |
| `CopyAlert` | 9117314409 | Piano Keys 6 | 3 | THE COPY: pursuit warning |
| `CopyAttack` | 9125474229 | Creature Screech Pterodactyl Vocals Screams  | 1 | THE COPY: lunge |
| `CopyLost` | 9113989919 | Creature Vocal Spider Hiss Exhale 1 | 1 | THE COPY: lost its target |
| `CopyFinal` | 9113980319 | Creature Mix Giant Crab Monster Roar Growl 1 | 3 | THE COPY: final pursuit begins; last sound at the lift |
| `Caught` | 9113525391 | Body Impact 1 | 2 | A player is caught |
| `Whoosh` | 9113551598 | Boom Pass By Low End Multiple Variations 2 | 4 | THE COPY appears / vanishes |

**Missing (id 0 in `AudioConfig.ASSETS`, skipped silently in game):**

- `TerminalBoot` — Recording servers restarting. No suitable asset was found; choose one in the Creator Store and put its id in `ASSETS`.

**Weak matches — listen to these first:**

- `GeneratorLoop` is a go-kart engine at constant speed (no generator recording was found).
- `FanLoop` is a second oil-refinery ambience, not a single fan.
- `CopyFootstepsLoop` is a 4-second "robot footsteps on metal" clip, looped.
- `HeartbeatLoop` is a low synthetic throb, not a literal heartbeat.
- `CopySearch`, `CopyLost`, `CopyAttack` are spider and pterodactyl creature vocals;
  `CopyAlert` is a low piano hit.
- `HeavyDoorOpen` is a 13-second motor whir.
- `RadioVoice` is a police-radio feed and may contain intelligible speech.
- `AmbTunnel` ("Hell Entrance 5") may be too dramatic for a room tone.
- `RadioStaticLoop` reuses the 3-second `RadioStaticBurst` asset, looped.
- Several cues share one asset on purpose (`TransformerLoop` = `AmbElectricalHum`,
  `ServerLoop` = `AmbServerRoom`, `PipeLoop` = `AmbPipes`, `SourceLoop` = `AmbSource`,
  `ObjectiveComplete` = `TerminalBeep` slowed down).

**Still needed (no asset in any form):**

| Asset | Used by | Notes |
| ----- | ------- | ----- |
| Recorded voice lines for the transmissions | Radio, ending | Subtitles carry the words; the "voice" cues are textures only |
| A steady radio static loop | Receiver, radio desk | Replaces the looped burst |
| Old-computer start-up sound (`TerminalBoot`) | Recording servers | Id 0 today |
| Menu and ending music | UI, ending | No music is used anywhere |

## Models, images and other content

No model, mesh, image or animation asset IDs are referenced anywhere in the project.

The draft map generator (`docs/MAP_GENERATOR.md`) creates only plain parts with built-in
Roblox materials and `PointLight`s. Everything it creates is a placeholder:

| Generated content                                   | Status      | Replace with                              |
| --------------------------------------------------- | ----------- | ----------------------------------------- |
| Floors, walls, ceilings, rock shell and roof (blockout) | Placeholder | Final architecture / textured geometry |
| Door frames and door panels. Open doors are half-transparent and walk-through; sealed doors are made solid at runtime by `Systems/DoorSystem` | Placeholder | Door models with opening animation |
| Ceiling light fixtures (neon boxes)                 | Placeholder | Final fixtures and lighting design        |
| `Placeholder_*` boxes (desks, generator, consoles, server racks, mast base, keypad, radio desk, fan housing, signal core...) | Placeholder | Final props / puzzle models |
| `BreakerPanel_1..3` boxes                           | Placeholder | Breaker panel models for the power puzzle |

Created by the game at runtime (`Data/PropList.luau`), also from plain parts:

| Content                                              | Status      | Replace with                         |
| ---------------------------------------------------- | ----------- | ------------------------------------ |
| THE COPY body (`Systems/CopyAI/Body.luau`): six dark boxes forming a tall figure, moved without animation | Placeholder | Rigged, animated character model |
| Documents (18): a paper box on a plinth              | Placeholder | Paper / clipboard models             |
| Radio receiver, battery packs (6), relay fuse, tape 9-114 | Placeholder | Item models                     |
| Controls on posts: feeders (4), channel selectors (2), generator panel, fan control, mast control, evacuation override, archive keypad | Placeholder | Panel and console models |
| Wall panels: arrival elevator control, freight lift control | Placeholder | Panel models                  |
| Floating text labels on interactive objects          | Placeholder | In-world displays / indicator lamps  |
| Flashlight: a `SpotLight` on the character's head for other players, a camera-attached `SpotLight` and fill light for the local player; no visible torch | Placeholder | Held flashlight model and animation |
| Sound emitters: invisible parts (`Systems/AudioEmitters`) | Final (invisible by design) | — |

| Still needed                            | Type        | Used by                   |
| --------------------------------------- | ----------- | ------------------------- |
| THE COPY character model and animations | Model       | Enemy AI                  |
| Facility props (desks, racks, monitors) | Models      | World                     |
| UI icons (stamina, battery, settings)   | Images      | HUD (drawn with UI primitives today) |

## Rules

1. Prefer original assets or assets the project owner uploaded.
2. Roblox Creator Store assets are allowed when their licence permits use; record the asset
   ID, creator and URL here.
3. A placeholder is never presented as final.
4. Never invent an id. A cue without a verified asset keeps id 0 and is listed as missing.
