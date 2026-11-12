--!strict
-- Mission tests: `luau tests/mission.luau`
-- The objective list is consistent, milestones can never be lost or undone, the puzzles
-- are always solvable, and - checked against the real map layout - every objective can be
-- walked to with only the doors that earlier objectives have opened (no softlocks).

local Layout = require("../src/ServerStorage/DevTools/MapGenerator/Layout")
local ObjectiveConfig = require("../src/ReplicatedStorage/Config/ObjectiveConfig")
local DoorConfig = require("../src/ReplicatedStorage/Config/DoorConfig")
local MissionConfig = require("../src/ReplicatedStorage/Config/MissionConfig")
local GameState = require("../src/ReplicatedStorage/Shared/GameState")
local PropList = require("../src/ServerScriptService/Data/PropList")
local Progress = require("../src/ServerScriptService/Systems/SliceDirector/Progress")
local LoadBalance = require("../src/ServerScriptService/Systems/SliceDirector/LoadBalance")
local Escalation = require("../src/ServerScriptService/Systems/CopyAI/Escalation")

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local START_ROOM = "A_Elevator"

local rooms: { [string]: boolean } = {}
for _, room in Layout.rooms :: { any } do
	rooms[room.name] = true
end
local propRoom: { [string]: string } = {}
for _, def in PropList :: { any } do
	propRoom[def.id] = def.room
end

-- ---- The objective list ----
local position: { [string]: number } = {}
local order: { string } = {}
do
	local chapter = 1
	local stageIndex = 1
	for index, objective in ObjectiveConfig.List do
		check(`{objective.id}: id is unique`, position[objective.id] == nil)
		position[objective.id] = index
		table.insert(order, objective.id)
		check(`{objective.id}: has a completion condition`, #objective.completion > 20)
		check(
			`{objective.id}: chapters only go forward`,
			objective.chapter == chapter or objective.chapter == chapter + 1
		)
		chapter = objective.chapter
		check(`{objective.id}: names at least one room`, #objective.rooms > 0)
		for _, room in objective.rooms do
			check(`{objective.id}: room {room} exists on the map`, rooms[room] == true)
		end
		for _, prop in objective.props or {} do
			check(`{objective.id}: prop {prop} is in the prop list`, propRoom[prop] ~= nil)
		end
		for _, required in objective.requires or {} do
			check(
				`{objective.id}: requires {required}, which comes earlier`,
				position[required] ~= nil and position[required] < index
			)
		end
		if objective.stage then
			local found = table.find(Escalation.ORDER, objective.stage :: any)
			check(`{objective.id}: stage {objective.stage} exists`, found ~= nil)
			check(
				`{objective.id}: escalation only goes forward`,
				found ~= nil and found > stageIndex
			)
			stageIndex = found or stageIndex
		end
	end
	check("the mission has 12 or more objectives", #ObjectiveConfig.List >= 12)
	check("every chapter is used", chapter == #ObjectiveConfig.Chapters)
	check("the mission ends at the last escalation stage", stageIndex == #Escalation.ORDER)
	check("the mission ends with the escape", order[#order] == "Escape")
end
for index, chapter in ObjectiveConfig.Chapters do
	check(`chapter {index}: checkpoint room exists`, rooms[chapter.checkpoint] == true)
end
do
	local seen: { [string]: boolean } = {}
	for _, optional in ObjectiveConfig.Optional do
		check(`optional {optional.id}: id is unique`, not seen[optional.id])
		check(`optional {optional.id}: is not a main objective`, position[optional.id] == nil)
		seen[optional.id] = true
	end
end

-- ---- Doors and reachability ----
for _, lock in DoorConfig.Locks do
	local exists = false
	for _, connection in Layout.connections :: { any } do
		if
			connection.door
			and (
				(connection.a == lock.a and connection.b == lock.b)
				or (connection.a == lock.b and connection.b == lock.a)
			)
		then
			exists = true
		end
	end
	check(`lock {lock.a} / {lock.b}: that door exists on the map`, exists)
end

-- Rooms that can be walked to from the start when the given keys are unlocked.
local function reachable(keys: { [string]: boolean }): { [string]: boolean }
	local seen: { [string]: boolean } = { [START_ROOM] = true }
	local queue = { START_ROOM }
	while #queue > 0 do
		local room = table.remove(queue, 1) :: string
		for _, connection in Layout.connections :: { any } do
			local other = if connection.a == room
				then connection.b
				elseif connection.b == room then connection.a
				else nil
			if other and not seen[other] then
				local lock = DoorConfig.lockBetween(connection.a, connection.b)
				if not lock or keys[lock.key] then
					seen[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	return seen
end

do
	local keys: { [string]: boolean } = {}
	local lastChapter = 0
	for _, objective in ObjectiveConfig.List do
		local open = reachable(keys)
		for _, room in objective.rooms do
			check(
				`{objective.id}: {room} can be reached when the objective starts`,
				open[room] == true
			)
		end
		for _, prop in objective.props or {} do
			check(
				`{objective.id}: {prop} ({propRoom[prop]}) can be reached when the objective starts`,
				open[propRoom[prop]] == true
			)
		end
		if objective.chapter ~= lastChapter then
			lastChapter = objective.chapter
			local checkpoint = ObjectiveConfig.Chapters[objective.chapter].checkpoint
			check(
				`chapter {objective.chapter}: checkpoint {checkpoint} is open when the chapter starts`,
				open[checkpoint] == true
			)
		end
		-- Completing the objective opens the doors keyed to it.
		keys[objective.id] = true
	end

	local open = reachable(keys)
	for name in rooms do
		if name ~= "F_RestrictedArchive" then
			check(`{name} is open by the end of the mission`, open[name] == true)
		end
	end
	check("the restricted archive needs its own key", open.F_RestrictedArchive ~= true)
	keys.RestrictedArchive = true
	check("and opens with it", reachable(keys).F_RestrictedArchive == true)

	-- The optional lock's clue and keypad are outside the locked room.
	local start = reachable({})
	check("the archive code can be found from the start", start[propRoom.PersonnelFile] == true)
	check("the archive keypad is outside the archive", start[propRoom.ArchiveKeypad] == true)
	check(
		"something is sealed at the start",
		start.C_MainLab ~= true and start.D_CommCenter ~= true
	)
	check("the power controls are never behind a sealed door", start.B_PowerRoom == true)
end
for id, lock in MissionConfig.Locks do
	check(`lock {id}: its keypad is in the prop list`, propRoom[lock.prop] ~= nil)
	check(`lock {id}: has a usable code length`, lock.digits >= 3 and lock.digits <= 8)
end

-- ---- Milestones ----
do
	local progress = Progress.new({ "A", "B", "C", "D", "E" })
	check("nothing is pending at the start", #Progress.pending(progress, 1) == 0)
	check("an unknown milestone is refused", not Progress.mark(progress, "Z"))
	check("and so is an unknown hard milestone", not Progress.reach(progress, "Z"))

	Progress.mark(progress, "C")
	check("a soft milestone done early waits its turn", #Progress.pending(progress, 1) == 0)
	Progress.mark(progress, "A")
	check(
		"the current objective completes",
		table.concat(Progress.pending(progress, 1), ",") == "A"
	)
	check("but not past a gap", #Progress.pending(progress, 2) == 0)
	Progress.mark(progress, "B")
	check(
		"filling the gap releases what was done early",
		table.concat(Progress.pending(progress, 2), ",") == "B,C"
	)

	Progress.reach(progress, "E")
	check(
		"a hard milestone carries everything before it",
		table.concat(Progress.pending(progress, 4), ",") == "D,E"
	)
	check("pending past the end is empty", #Progress.pending(progress, 6) == 0)
	Progress.mark(progress, "A")
	Progress.reach(progress, "B")
	check(
		"repeating a milestone changes nothing",
		Progress.has(progress, "E") and Progress.has(progress, "A")
	)
end
do
	-- The real list: every objective reached in order completes exactly itself.
	local progress = Progress.new(order)
	for index, id in order do
		Progress.reach(progress, id)
		check(
			`{id}: completes exactly itself`,
			table.concat(Progress.pending(progress, index), ",") == id
		)
	end
end

-- ---- Relay load puzzle ----
do
	local seed = 12345
	local function random(min: number, max: number): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return min + seed % (max - min + 1)
	end
	local pool = MissionConfig.LoadPuzzle.Values
	local feeders = MissionConfig.LoadPuzzle.Feeders

	for round = 1, 200 do
		local state = LoadBalance.generate(pool, feeders, random)
		local distinct: { [number]: boolean } = {}
		for _, value in state.values do
			distinct[value] = true
		end
		local kinds = 0
		for _ in distinct do
			kinds += 1
		end
		local sum = 0
		for _, value in state.values do
			sum += value
		end

		-- Brute force: some set of feeders hits the target exactly.
		local solvable = false
		for mask = 1, 2 ^ feeders - 1 do
			local load = 0
			for index = 1, feeders do
				if bit32.band(mask, bit32.lshift(1, index - 1)) ~= 0 then
					load += state.values[index]
				end
			end
			solvable = solvable or load == state.target
		end
		if
			not (
				solvable
				and kinds == feeders
				and state.target < sum
				and LoadBalance.load(state) == 0
			)
		then
			check(`round {round}: puzzle is solvable, distinct, and starts open`, false)
		end
	end
	check("200 generated puzzles are all solvable", true)

	local state: LoadBalance.State = {
		values = { 10, 20, 30, 40 },
		closed = { false, false, false, false },
		target = 50,
	}
	check(
		"closing a feeder adds its load",
		LoadBalance.toggle(state, 4) == "closed" and LoadBalance.load(state) == 40
	)
	check("too much overloads", LoadBalance.toggle(state, 2) == "overload")
	check("an overload changes nothing", LoadBalance.load(state) == 40 and not state.closed[2])
	check(
		"the exact load solves it",
		LoadBalance.toggle(state, 1) == "solved" and LoadBalance.isSolved(state)
	)
	check(
		"opening a feeder removes its load",
		LoadBalance.toggle(state, 4) == "opened" and LoadBalance.load(state) == 10
	)
	check("a feeder that does not exist is ignored", LoadBalance.toggle(state, 9) == nil)
end

-- ---- Replicated progress strings ----
do
	local encoded = GameState.encodeProgress({
		{ id = "ReadDocuments", done = 3, total = 18 },
		{ id = "RestrictedArchive", done = 1, total = 1 },
	})
	local decoded = GameState.decodeProgress(encoded)
	check(
		"optional progress survives replication",
		#decoded == 2
			and decoded[1].id == "ReadDocuments"
			and decoded[1].done == 3
			and decoded[1].total == 18
			and decoded[2].done == 1
	)
	check("an empty attribute decodes to nothing", #GameState.decodeProgress("") == 0)
	check("junk decodes to nothing", #GameState.decodeProgress("hello;=;x=1") == 0)
end

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("mission tests failed")
end
