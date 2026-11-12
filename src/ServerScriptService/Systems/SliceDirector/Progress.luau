--!strict
-- Which mission milestones have happened. Pure logic, unit tested (tests/mission.luau).
--
-- The world reports milestones in whatever order players cause them; objectives are
-- completed strictly in list order. This module remembers the first and answers the
-- second, so nothing done early is ever lost and nothing can be undone.
--
--   reach(id)  a hard milestone: it could not have happened without everything before
--              it (no relay without power), so every earlier objective counts as done too.
--              This is what keeps the mission from ever getting stuck on a missed trigger.
--   mark(id)   a soft milestone: something done ahead of time (an item picked up, a clue
--              read). It is remembered and completes its objective when its turn comes.

export type Progress = {
	order: { string },
	position: { [string]: number },
	done: { [string]: boolean },
}

local Progress = {}

function Progress.new(order: { string }): Progress
	local position: { [string]: number } = {}
	for index, id in order do
		position[id] = index
	end
	return { order = order, position = position, done = {} }
end

function Progress.has(progress: Progress, id: string): boolean
	return progress.done[id] == true
end

-- Returns false for an unknown id.
function Progress.mark(progress: Progress, id: string): boolean
	if not progress.position[id] then
		return false
	end
	progress.done[id] = true
	return true
end

function Progress.reach(progress: Progress, id: string): boolean
	local last = progress.position[id]
	if not last then
		return false
	end
	for index = 1, last do
		progress.done[progress.order[index]] = true
	end
	return true
end

-- The objectives that can be completed right now, in order, when the current objective is
-- number `index` in the list: the unbroken run of milestones starting there.
function Progress.pending(progress: Progress, index: number): { string }
	local ids: { string } = {}
	while index <= #progress.order and progress.done[progress.order[index]] do
		table.insert(ids, progress.order[index])
		index += 1
	end
	return ids
end

return Progress
