--!strict
-- How angry THE COPY is. Pure logic, unit tested (tests/copy.luau).
--
-- The stage only moves forward, and only one step at a time: asking for a later stage
-- walks through every stage in between, so none can be skipped and each one is announced.

export type Stage = "Dormant" | "Aware" | "Hunting" | "Hostile" | "FinalPursuit"

export type Escalation = { index: number }

local ORDER: { Stage } = { "Dormant", "Aware", "Hunting", "Hostile", "FinalPursuit" }

local Escalation = {}

Escalation.ORDER = ORDER

function Escalation.new(): Escalation
	return { index = 1 }
end

function Escalation.stage(escalation: Escalation): Stage
	return ORDER[escalation.index]
end

-- Moves forward to `target`, calling `onStep(from, to)` for every single step. Asking for
-- the current or an earlier stage does nothing. Returns the number of steps taken.
function Escalation.advanceTo(
	escalation: Escalation,
	target: string,
	onStep: (from: Stage, to: Stage) -> ()
): number
	local targetIndex = table.find(ORDER, target :: any)
	if not targetIndex then
		return 0
	end
	local steps = 0
	while escalation.index < targetIndex do
		local from: Stage = ORDER[escalation.index]
		escalation.index += 1
		steps += 1
		local to: Stage = ORDER[escalation.index]
		onStep(from, to)
	end
	return steps
end

return Escalation
