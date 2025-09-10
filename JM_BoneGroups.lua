-- JM_BoneGroups.lua
-- Persistent storage and operations for named bone groups / folders

local BoneGroups = {}
BoneGroups.__index = BoneGroups

-- location of the data file (relative to this script)
local function script_dir()
	-- try to get directory of this file
	local info = debug.getinfo(1, "S")
	local source = info and info.source or ""
	local path = source:match("@?(.*[/\\])") or "./"
	return path
end

local DATA_FILE = script_dir() .. "JM_BoneGroups_data.lua"

-- in-memory structure:
-- BoneGroups.data = {
--   folders = {
--     { name = "default", groups = {
--         { name = "l_arm", bones = { { name="", pos={x,y}, angle, length, strength, tags, parentIndex } , ... } }
--       }
--     },
--     ...
--   }
-- }
BoneGroups.data = BoneGroups.data or { folders = {} }

-- helpers: find folder/group
local function findFolder(data, folderName)
	for fi, f in ipairs(data.folders) do
		if f.name == folderName then return f, fi end
	end
	return nil, nil
end

local function findGroup(folder, groupName)
	for gi, g in ipairs(folder.groups) do
		if g.name == groupName then return g, gi end
	end
	return nil, nil
end

-- persist / load
function BoneGroups:SaveToDisk()
	local file, err = io.open(DATA_FILE, "w")
	if not file then
		return false, "Failed to open data file for writing: " .. tostring(err)
	end
	file:write("return " .. self:serialize(self.data) .. "\n")
	file:close()
	return true
end

function BoneGroups:LoadFromDisk()
	local f = io.open(DATA_FILE, "r")
	if not f then
		-- no file yet, leave defaults
		return false
	end
	f:close()
	local ok, tbl = pcall(dofile, DATA_FILE)
	if ok and type(tbl) == "table" then
		self.data = tbl
		return true
	else
		return false
	end
end

-- simple Lua table serializer (handles basic tables, numbers, strings, booleans)
function BoneGroups:serialize(o)
	local t = type(o)
	if t == "number" then
		return tostring(o)
	elseif t == "boolean" then
		return tostring(o)
	elseif t == "string" then
		return string.format("%q", o)
	elseif t == "table" then
		local isArray = true
		local max = 0
		for k, v in pairs(o) do
			if type(k) ~= "number" then
				isArray = false
				break
			else
				if k > max then max = k end
			end
		end
		local parts = {}
		if isArray then
			for i = 1, max do
				table.insert(parts, self:serialize(o[i]))
			end
			return "{" .. table.concat(parts, ",") .. "}"
		else
			for k, v in pairs(o) do
				table.insert(parts, "[" .. self:serialize(k) .. "]=" .. self:serialize(v))
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	else
		return "nil"
	end
end

-- API

-- Ensure default folder exists
function BoneGroups:EnsureDefaultFolder()
	if not self.data then self.data = { folders = {} } end
	local f = findFolder(self.data, "default")
	if not f then
		table.insert(self.data.folders, { name = "default", groups = {} })
	end
end

-- Create folder
function BoneGroups:AddFolder(folderName)
	if not folderName or folderName == "" then return false, "Invalid folder name" end
	self:EnsureDefaultFolder()
	local f, _ = findFolder(self.data, folderName)
	if f then return false, "Folder exists" end
	table.insert(self.data.folders, { name = folderName, groups = {} })
	self:SaveToDisk()
	return true
end

-- Delete folder
function BoneGroups:DeleteFolder(folderName)
	for i, f in ipairs(self.data.folders) do
		if f.name == folderName then
			table.remove(self.data.folders, i)
			self:SaveToDisk()
			return true
		end
	end
	return false
end

-- Save a highlighted selection as a named group under folderName
-- highlightedBonesData: array of bone info tables (see below)
-- bone info should contain: name, pos={x,y}, angle, length, strength, tags, parentIndex (index in array or nil)
function BoneGroups:SaveGroup(folderName, groupName, bonesArray)
	if not groupName or groupName == "" then return false, "Invalid group name" end
	self:EnsureDefaultFolder()
	local folder, _ = findFolder(self.data, folderName or "default")
	if not folder then
		folder = { name = folderName or "default", groups = {} }
		table.insert(self.data.folders, folder)
	end
	-- Overwrite existing group with same name
	local existing, idx = findGroup(folder, groupName)
	if existing then
		folder.groups[idx] = { name = groupName, bones = bonesArray }
	else
		table.insert(folder.groups, { name = groupName, bones = bonesArray })
	end
	self:SaveToDisk()
	return true
end

-- Remove group
function BoneGroups:DeleteGroup(folderName, groupName)
	local folder, fi = findFolder(self.data, folderName or "default")
	if not folder then return false end
	for gi, g in ipairs(folder.groups) do
		if g.name == groupName then
			table.remove(folder.groups, gi)
			self:SaveToDisk()
			return true
		end
	end
	return false
end

-- Get folder list
function BoneGroups:GetFolders()
	local out = {}
	for _, f in ipairs(self.data.folders) do
		table.insert(out, f.name)
	end
	return out
end

-- Get groups in folder
function BoneGroups:GetGroups(folderName)
	local folder = findFolder(self.data, folderName or "default")
	if not folder then return {} end
	local out = {}
	for _, g in ipairs(folder.groups) do
		table.insert(out, g.name)
	end
	return out
end

-- Get group object
function BoneGroups:GetGroup(folderName, groupName)
	local folder = findFolder(self.data, folderName or "default")
	if not folder then return nil end
	local g = findGroup(folder, groupName)
	if g then return g end
	-- if findGroup returned two values, adjust; robust:
	for _, gg in ipairs(folder.groups) do
		if gg.name == groupName then return gg end
	end
	return nil
end

-- Helper to build the bonesArray from a moho skeleton and list of bone indices (from highlight)
function BoneGroups:CollectBonesFromSkeleton(moho, boneIndices)
	local skel = moho:Skeleton()
	if not skel then return nil, "No skeleton" end
	local bonesArray = {}
	-- We need consistent ordering so parentIndex refers to index in this array.
	-- Use boneIndices as an array of indices and preserve ordering.
	for ai = 1, #boneIndices do
		local i = boneIndices[ai]
		local b = skel:Bone(i)
		if b then
			-- find parent index relative to this array
			local parentIndex = nil
			if b.fParent and b.fParent ~= -1 then
				-- find which ai has that id (BoneID)
				for aj = 1, #boneIndices do
					local j = boneIndices[aj]
					if j == b.fParent then
						parentIndex = aj
						break
					end
				end
			end
			table.insert(bonesArray, {
			name = b:Name(),
			pos = { x = b.fPos.x, y = b.fPos.y },
			angle = b.fAngle,
			length = b.fLength,
			strength = b.fStrength,
			tags = b:Tags and b:Tags() or nil, -- if Tags available
			parentIndex = parentIndex -- nil or integer
			})
		end
	end
	return bonesArray
end

-- Save highlighted bones as group (tool integration point)
-- highlightedIndices is an array of skeleton bone indices (0..n-1)
function BoneGroups:SaveHighlightedAsGroup(moho, highlightedIndices, folderName, groupName)
	if not highlightedIndices or #highlightedIndices == 0 then
		return false, "No bones highlighted"
	end
	local bonesArray, err = self:CollectBonesFromSkeleton(moho, highlightedIndices)
	if not bonesArray then return false, err end
	return self:SaveGroup(folderName or "default", groupName, bonesArray)
end

-- Create bones in the current bone layer from a saved group object.
-- options: { mirror = bool, mirrorMode = 0/1/2, customX = number, useOffset = bool,
--            offsetX = number, offsetY = number, offsetMode = 0/1, cloneCount = int }
-- returns array of new bone IDs (list) or nil+err
function BoneGroups:CreateBonesFromGroup(moho, groupObj, options)
	if not groupObj then return nil, "No group" end
	options = options or {}
	local skel = moho:Skeleton()
	if not skel then return nil, "No skeleton" end

	local helpers = dofile(script_dir() .. "JM_BoneHighlightHelpers.lua") -- reuse helpers
	local newIDs = {}

	local mode = options.mirrorMode or 0
	local customX = options.customX or 0
	local useOffset = options.useOffset or false
	local dx = options.offsetX or 0
	local dy = options.offsetY or 0
	local offsetMode = options.offsetMode or 0
	local cloneCount = options.cloneCount or 1

	-- We'll create clones cloneCount times
	for c = 1, cloneCount do
		local cloneIndex = c - 1
		local idMap = {} -- map from group index to new bone ID
		-- create bones in same order as stored so parentIndex references work
		for gi, binfo in ipairs(groupObj.bones) do
			-- base pos/angle
			local pos = { x = binfo.pos.x, y = binfo.pos.y }
			local angle = binfo.angle
			-- mirror if requested
			if options.mirror then
				pos, angle = helpers.CalcMirror(pos, angle, mode, customX)
			end
			-- offset if requested
			pos = helpers.ApplyOffset(pos, dx, dy, cloneIndex, useOffset, offsetMode)
			-- Add a new bone as a copy of a 'template bone' — we don't have a template here,
			-- so create a new bone and then set properties. We will use skel:AddBone(frame0)
			local newBone = skel:AddBone(0)
			local newID = skel:BoneID(newBone)
			-- set properties
			newBone:SetName(binfo.name)
			if newBone.fPos then newBone.fPos.x = pos.x; newBone.fPos.y = pos.y end
			if newBone.fAnimPos then newBone.fAnimPos:SetValue(0, newBone.fPos) end
			if newBone.fLength then newBone.fLength = binfo.length end
			if newBone.fAngle then newBone.fAngle = angle end
			if newBone.fAnimAngle then newBone.fAnimAngle:SetValue(0, angle) end
			if newBone.fStrength then newBone.fStrength = binfo.strength end
			-- tags if available
			if binfo.tags and newBone.SetTags then
				newBone:SetTags(binfo.tags)
			end
			-- parenting will be set after we create map
			idMap[gi] = newID
			table.insert(newIDs, newID)
		end

		-- second pass: apply parenting
		for gi, binfo in ipairs(groupObj.bones) do
			local newID = idMap[gi]
			if newID and binfo.parentIndex then
				local parentNewID = idMap[binfo.parentIndex]
				if parentNewID then
					local nb = skel:Bone(newID)
					nb.fParent = parentNewID
					nb.fAnimParent:SetValue(0, parentNewID)
					skel:UpdateBoneMatrix(newID)
				end
			end
		end
	end

	-- mark skeleton dirty / update
	moho.document:SetDirty()
	moho:UpdateUI()
	moho.view:DrawMe()
	return newIDs
end

-- High-level ApplyGroup: apply a saved group to current layer
-- options same as CreateBonesFromGroup
function BoneGroups:ApplyGroupToLayer(moho, folderName, groupName, options)
	local g = self:GetGroup(folderName or "default", groupName)
	if not g then return nil, "Group not found" end
	return self:CreateBonesFromGroup(moho, g, options)
end

-- Attempt load on require
BoneGroups:LoadFromDisk()
BoneGroups:EnsureDefaultFolder()

return BoneGroups
