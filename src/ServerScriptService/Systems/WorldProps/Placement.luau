--!strict
-- Where a runtime prop goes inside its room. Pure math, no Roblox API, so the placements
-- are unit tested against the map layout (tests/props.luau).

export type PropDef = {
	id: string,
	kind: string,
	room: string,
	reuse: string?,
	fx: number,
	fz: number,
	y: number?,
	size: { number },
	stand: { number }?,
	look: string,
	action: string,
	object: string,
	enabled: boolean?,
}

-- Offsets are from the room's centre (ox, oz) and from its floor (oy), to the box centre.
export type Box = {
	ox: number,
	oy: number,
	oz: number,
	sx: number,
	sy: number,
	sz: number,
}

export type Result = { stand: Box?, item: Box }

local Placement = {}

function Placement.resolve(def: PropDef, roomSizeX: number, roomSizeZ: number): Result
	local ox = (def.fx - 0.5) * roomSizeX
	local oz = (def.fz - 0.5) * roomSizeZ

	local stand: Box? = nil
	local base = def.y or 0
	local standSize = def.stand
	if standSize then
		stand = {
			ox = ox,
			oy = standSize[2] / 2,
			oz = oz,
			sx = standSize[1],
			sy = standSize[2],
			sz = standSize[3],
		}
		base = standSize[2]
	end

	return {
		stand = stand,
		item = {
			ox = ox,
			oy = base + def.size[2] / 2,
			oz = oz,
			sx = def.size[1],
			sy = def.size[2],
			sz = def.size[3],
		},
	}
end

return Placement
