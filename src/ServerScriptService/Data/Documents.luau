--!strict
-- Documents the players can read, by id (the `Id` of an object with Kind = "Document").
-- The words themselves live in Shared/Locale as localization keys, so every player reads
-- them in their own language; this table only names the keys. Values that are generated
-- for the session (the breaker order, door codes) are never part of the text: the system
-- that owns them supplies them when the document is opened
-- (DocumentSystem.setParams), so clues cannot be read out of the client ahead of time.

export type Document = {
	title: string,
	date: string,
	body: string,
}

local function document(key: string): Document
	return {
		title = `DOCUMENT_{key}_TITLE`,
		date = `DOCUMENT_{key}_DATE`,
		body = `DOCUMENT_{key}_BODY`,
	}
end

local documents: { [string]: Document } = {
	-- Entrance.
	IncidentLog = document("INCIDENT_LOG"),
	StartupMemo = document("STARTUP_MEMO"),
	DirectorMemo = document("DIRECTOR_MEMO"),
	-- Research corridors.
	ResearchNote = document("RESEARCH_NOTE"),
	MaintenanceReport = document("MAINTENANCE_REPORT"),
	BreakRoomNote = document("BREAK_ROOM_NOTE"),
	-- Power wing.
	FeederNote = document("FEEDER_NOTE"),
	-- Medical.
	ExaminationLog = document("EXAMINATION_LOG"),
	QuarantineOrder = document("QUARANTINE_ORDER"),
	PatientChart = document("PATIENT_CHART"),
	-- Archives.
	TapeTranscript = document("TAPE_TRANSCRIPT"),
	PersonnelFile = document("PERSONNEL_FILE"),
	RestrictedFile = document("RESTRICTED_FILE"),
	-- Laboratory.
	ContainmentReport = document("CONTAINMENT_REPORT"),
	-- Communication center.
	OperatorNote = document("OPERATOR_NOTE"),
	ServerLog = document("SERVER_LOG"),
	-- Freight wing.
	EvacuationNotice = document("EVACUATION_NOTICE"),
	SourceLog = document("SOURCE_LOG"),
}

return documents
