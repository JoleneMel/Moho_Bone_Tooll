-- JM_BoneHighlightHelpers.lua
-- Pure Lua helper functions for math/logic
-- Safe for unit testing with luaunit

local Helpers = {}

function Helpers.CalcMirror(pos, angle, mode, customX)
	local mirroredPos = {x = pos.x, y = pos.y}
	local mirroredAngle = angle

	if mode == 0 then
		-- Horizontal (mirror across Y axis)
		mirroredPos.x = -pos.x
		mirroredAngle = -angle
	elseif mode == 1 then
		-- Vertical (mirror across X axis)
		mirroredPos.y = -pos.y
		mirroredAngle = math.pi - angle
	elseif mode == 2 then
		-- Custom X mirror
		mirroredPos.x = 2*customX - pos.x
		mirroredAngle = -angle
	end

	return mirroredPos, mirroredAngle
end

function Helpers.ApplyOffset(pos, dx, dy, cloneIndex, useOffset, offsetMode)
	local newPos = {x = pos.x, y = pos.y}
	if not useOffset then return newPos end

	if offsetMode == 0 then
		-- Fixed
		newPos.x = newPos.x + dx
		newPos.y = newPos.y + dy
	elseif offsetMode == 1 then
		-- Incremental
		newPos.x = newPos.x + dx * (cloneIndex + 1)
		newPos.y = newPos.y + dy * (cloneIndex + 1)
	end

	return newPos
end

function Helpers.GenerateCloneName(baseName, mirror, cloneIndex)
	if mirror then
		return baseName .. "_mirror" .. tostring(cloneIndex)
	else
		return baseName .. "_clone" .. tostring(cloneIndex)
	end
end

return Helpers
