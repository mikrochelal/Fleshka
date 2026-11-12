# STATION-09 room directory

Generated from `src/ServerStorage/DevTools/MapGenerator/Layout.luau` (layout v4):
**55 rooms** in 8 zones, 53 doors, 6 archways, 99 lights, about 1,230 parts.

Rooms 1–29 are the original station and never move; rooms 30–55 are the expansion.
Sizes are width x depth x height in studs. "(power)" marks a door meant to open only
with power, "(locked)" one meant to need a code or key. **Doors are not functional
yet**: every door can currently be walked through.

In Studio, `listRooms()` prints this list and `showOverlay()` labels every room in the
viewport (see `docs/MAP_GENERATOR.md`).

## A — Entrance and administration

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 1 | `A_Elevator` | 16 x 20 x 12 | Arrival point and exit. Spawn. | Lobby |
| 2 | `A_Lobby` | 36 x 40 x 14 | Reception hall; first document; hub of the entrance. | Elevator, SecurityBooth, Checkpoint, Lockers, AdminOffice, AccessControl |
| 3 | `A_SecurityBooth` | 24 x 14 x 12 | Security desk; breaker 1; start-up memo. | Lobby, Checkpoint |
| 4 | `A_Checkpoint` | 24 x 12 x 12 | Bulkhead between the entrance and the facility. | Lobby, SecurityBooth, MainCorridor (power) |
| 5 | `A_Lockers` | 24 x 14 x 12 | Staff lockers; battery pack. | Lobby |
| 30 | `A_AdminOffice` | 28 x 24 x 12 | Administration; director's paperwork and personnel decisions. | Lobby |
| 31 | `A_AccessControl` | 16 x 10 x 12 | Restricted gate from the lobby to the freight wing. | Lobby, CargoCorridor (locked) |

## B — Research corridors

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 6 | `B_MainCorridor` | 120 x 12 x 12 | The spine of the station; main landmark; first sighting. | Checkpoint (power), Office101, Storage102, MonitorRoom, Records104, PowerRoom, Maintenance, BreakRoom, Infirmary, Junction |
| 7 | `B_Office101` | 28 x 20 x 12 | Research office; Dr. Hale's note. | MainCorridor |
| 8 | `B_Storage102` | 24 x 20 x 12 | General storage. | MainCorridor |
| 9 | `B_MonitorRoom` | 36 x 20 x 12 | Camera monitors; the radio receiver. | MainCorridor, ServiceTunnel (power) |
| 10 | `B_Records104` | 32 x 20 x 12 | Day-to-day research records. | MainCorridor |
| 11 | `B_PowerRoom` | 36 x 24 x 12 | Emergency power: breaker 2 and the main lever. | MainCorridor, ServiceCorridor |
| 12 | `B_Maintenance` | 28 x 24 x 12 | Maintenance shop; breaker 3; battery pack. | MainCorridor, ServiceCorridor |
| 13 | `B_BreakRoom` | 32 x 24 x 12 | Staff break room; abandoned personal belongings. | MainCorridor |
| 14 | `B_Infirmary` | 24 x 24 x 12 | First-aid room on the main corridor. | MainCorridor |
| 15 | `B_Junction` | 28 x 24 x 14 | Crossing hall: north to the lab, south to comms, east to medical. | MainCorridor, NorthCorridor, SouthCorridor, MedCorridor |
| 16 | `B_NorthCorridor` | 12 x 48 x 12 | Route to the laboratory and the archives. | Junction, ServiceTunnel (power), Airlock (power), ArchiveCorridor |
| 17 | `B_SouthCorridor` | 12 x 40 x 12 | Route to the communication center. | Junction, OperatorOffice, Antechamber, ServiceCorridor (power) |
| 18 | `B_ServiceTunnel` | 64 x 8 x 10 | Shortcut loop behind the north rooms, opens with power. | MonitorRoom (power), NorthCorridor (power) |

## C — Experimental laboratory

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 19 | `C_Airlock` | 16 x 16 x 12 | Decontamination lock into the laboratory. | NorthCorridor (power), MainLab |
| 20 | `C_MainLab` | 60 x 48 x 16 | Main laboratory. | Airlock, SignalChamber, Archive, Observation, ColdStorage |
| 21 | `C_SignalChamber` | 28 x 28 x 14 | Shielded chamber where the signal was received. | MainLab, SignalAnalysis, Containment (power) |
| 22 | `C_Archive` | 36 x 24 x 12 | Laboratory tape archive. | MainLab |
| 23 | `C_Observation` | 30 x 24 x 12 | Observation room over the laboratory. | MainLab |
| 24 | `C_ColdStorage` | 30 x 20 x 12 | Sample cold storage. | MainLab |
| 32 | `C_SignalAnalysis` | 28 x 24 x 12 | Signal analysis; frequency clues. | SignalChamber |
| 33 | `C_Containment` | 24 x 24 x 12 | Isolated containment room behind the signal chamber. | SignalChamber (power) |

## D — Communication center

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 25 | `D_OperatorOffice` | 30 x 22 x 12 | Radio operator's office; battery pack. | SouthCorridor |
| 26 | `D_Antechamber` | 20 x 18 x 12 | Security-code door into the communication center. | SouthCorridor, CommCenter (locked) |
| 27 | `D_CommCenter` | 64 x 56 x 16 | Main communication room; central computer. | Antechamber (locked), ServerRoom, RadioMast, RadioControl |
| 28 | `D_ServerRoom` | 28 x 28 x 12 | Signal recording servers. | CommCenter |
| 29 | `D_RadioMast` | 28 x 28 x 16 | Base of the antenna mast. | CommCenter |
| 34 | `D_RadioControl` | 24 x 24 x 12 | Radio control room; frequency calibration. | CommCenter |

## E — Medical and quarantine

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 35 | `E_MedCorridor` | 60 x 12 x 12 | Medical wing corridor. | Junction, MedReception, Examination, QuarantineCorridor (power) |
| 36 | `E_MedReception` | 28 x 22 x 12 | Medical reception; staff examination logs. | MedCorridor |
| 37 | `E_Examination` | 32 x 22 x 12 | Examination room for staff exposed to the signal. | MedCorridor |
| 38 | `E_QuarantineCorridor` | 40 x 12 x 12 | Sealed quarantine corridor. | MedCorridor (power), PatientRoom, IsolationChamber |
| 39 | `E_PatientRoom` | 28 x 22 x 12 | Patient room under observation. | QuarantineCorridor |
| 40 | `E_IsolationChamber` | 28 x 28 x 14 | Isolation chamber at the end of quarantine. | QuarantineCorridor |

## F — Archives

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 41 | `F_ArchiveCorridor` | 84 x 10 x 12 | Archive wing corridor. | NorthCorridor, DocumentArchive, TapeStorage, PersonnelRecords |
| 42 | `F_DocumentArchive` | 32 x 26 x 12 | Paper archive. | ArchiveCorridor, RestrictedArchive (locked) |
| 43 | `F_TapeStorage` | 32 x 26 x 12 | Audio tape storage; recordings. | ArchiveCorridor |
| 44 | `F_PersonnelRecords` | 28 x 28 x 12 | Personnel files. | ArchiveCorridor |
| 45 | `F_RestrictedArchive` | 32 x 26 x 12 | Restricted archive behind a code lock. | DocumentArchive (locked) |

## G — Power and maintenance

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 46 | `G_ServiceCorridor` | 128 x 10 x 12 | Service corridor of the power wing; shortcut to the south corridor. | PowerRoom, Maintenance, SouthCorridor (power), GeneratorHall, ElectricalControl, Ventilation |
| 47 | `G_GeneratorHall` | 48 x 36 x 16 | Main generator hall. | ServiceCorridor, PipeTunnel |
| 48 | `G_ElectricalControl` | 32 x 26 x 12 | Electrical control room; subsystem switchgear. | ServiceCorridor |
| 49 | `G_Ventilation` | 32 x 28 x 14 | Ventilation plant. | ServiceCorridor |
| 50 | `G_PipeTunnel` | 36 x 10 x 10 | Pipe tunnel to the freight wing. | GeneratorHall, CargoCorridor (power) |

## H — Freight and containment

| # | Room | Size | Purpose | Connects to |
| - | ---- | ---- | ------- | ----------- |
| 51 | `H_CargoCorridor` | 16 x 80 x 14 | Cargo corridor of the freight wing. | AccessControl (locked), PipeTunnel (power), FreightElevator (power), Checkpoint |
| 52 | `H_FreightElevator` | 20 x 20 x 14 | Freight elevator; final extraction route. | CargoCorridor (power) |
| 53 | `H_Checkpoint` | 24 x 20 x 12 | Restricted-access checkpoint before containment. | CargoCorridor, ObservationChamber (locked) |
| 54 | `H_ObservationChamber` | 36 x 28 x 12 | Observation chamber facing the signal source. | Checkpoint (locked), SignalSource |
| 55 | `H_SignalSource` | 52 x 52 x 20 | The signal source. | ObservationChamber |

## Routes

- **Spine:** Elevator → Lobby → Checkpoint → Main Corridor → Junction.
- **North:** Junction → North Corridor → Airlock → Main Lab → Signal Chamber →
  Signal Analysis / Containment. The Archive Corridor branches west off the North Corridor.
- **East:** Junction → Med Corridor → (quarantine seal) → Quarantine Corridor → Isolation Chamber.
- **South:** Junction → South Corridor → Antechamber → Comm Center → Radio Control / Server Room / Radio Mast.
- **Power wing:** Power Room or Maintenance → Service Corridor → Generator Hall,
  Electrical Control, Ventilation. The Service Corridor's east door is a shortcut to the
  South Corridor.
- **Freight wing:** Generator Hall → Pipe Tunnel → Cargo Corridor → Freight Elevator, or
  south to the Checkpoint → Observation Chamber → Signal Source.
- **Loops:** Service Tunnel (Monitor Room ↔ North Corridor); Service Corridor (power wing ↔
  South Corridor); Access Control (Lobby ↔ Cargo Corridor, restricted).
