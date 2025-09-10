-- **************************************************
-- JM Bone Highlight Tool
-- **************************************************

ScriptName = "JM_BoneHighlightTool"

JM_BoneHighlightTool = {}

function JM_BoneHighlightTool:Name()
	return "Bone Highlight Tool"
end

function JM_BoneHighlightTool:Version()
	return "0.7"
end

function JM_BoneHighlightTool:Description()
	return "Highlight bones, adjust strength, clone/mirror with offset and clone count options."
end

function JM_BoneHighlightTool:Creator()
	return "You + ChatGPT"
end

function JM_BoneHighlightTool:UILabel()
	return "Bone Highlight"
end

-- Persistent state
JM_BoneHighlightTool.highlightedBones = {}
JM_BoneHighlightTool.syncWithMoho = false
JM_BoneHighlightTool.dragging = false
JM_BoneHighlightTool.startX = 0
JM_BoneHighlightTool.startY = 0

----------------------------------------------------
-- Enable only for bone layers
----------------------------------------------------
function JM_BoneHighlightTool:IsEnabled(moho)
	return moho.layer:IsBoneType()
end

----------------------------------------------------
-- Tool Options
----------------------------------------------------
function JM_BoneHighlightTool:ToolOptions()
	local layout = LM.GUI.VerticalLayout()

	-- Sync checkbox
	local row1 = LM.GUI.HorizontalLayout()
	row1:AddChild(LM.GUI.StaticText("Sync with Moho Selection:"))
	self.checkbox = LM.GUI.CheckBox("", 0)
	self.checkbox:SetValue(self.syncWithMoho)
	row1:AddChild(self.checkbox)
	layout:AddChild(row1)

	-- Bone Strength slider + numeric field
	local row2 = LM.GUI.HorizontalLayout()
	row2:AddChild(LM.GUI.StaticText("Bone Strength:"))

	self.strengthSlider = LM.GUI.Slider(0, 1, 100)
	self.strengthSlider:SetValue(0.0)
	row2:AddChild(self.strengthSlider)

	self.strengthInput = LM.GUI.TextControl(0, "0.00", 0, LM.GUI.FIELD_FLOAT, "")
	self.strengthInput:SetWheelInc(0.05)
	self.strengthInput:SetValue(0.0)
	row2:AddChild(self.strengthInput)

	layout:AddChild(row2)

	-- Clone buttons
	local row3 = LM.GUI.HorizontalLayout()
	self.cloneBtn = LM.GUI.Button("Clone")
	row3:AddChild(self.cloneBtn)

	self.cloneMirrorBtn = LM.GUI.Button("Clone & Mirror")
	row3:AddChild(self.cloneMirrorBtn)

	layout:AddChild(row3)

	-- Clone count input
	local row3b = LM.GUI.HorizontalLayout()
	row3b:AddChild(LM.GUI.StaticText("Clone Count:"))
	self.cloneCountInput = LM.GUI.TextControl(0, "1", 0, LM.GUI.FIELD_INT, "")
	self.cloneCountInput:SetValue(1)
	row3b:AddChild(self.cloneCountInput)
	layout:AddChild(row3b)

	-- Mirror axis options
	local row4 = LM.GUI.HorizontalLayout()
	row4:AddChild(LM.GUI.StaticText("Mirror Axis:"))

	self.axisMenu = LM.GUI.PopupMenu()
	self.axisMenu:AddItem("Horizontal (Y axis)")
	self.axisMenu:AddItem("Vertical (X axis)")
	self.axisMenu:AddItem("Custom X Value")
	self.axisMenu:SetSel(0) -- default Y axis
	row4:AddChild(self.axisMenu)

	self.customXInput = LM.GUI.TextControl(0, "0.00", 0, LM.GUI.FIELD_FLOAT, "")
	self.customXInput:SetValue(0.0)
	row4:AddChild(self.customXInput)

	layout:AddChild(row4)

	-- Offset controls
	local row5 = LM.GUI.HorizontalLayout()
	self.offsetToggle = LM.GUI.CheckBox("Use Offset", 0)
	self.offsetToggle:SetValue(false)
	row5:AddChild(self.offsetToggle)

	row5:AddChild(LM.GUI.StaticText("X:"))
	self.offsetXInput = LM.GUI.TextControl(0, "0.00", 0, LM.GUI.FIELD_FLOAT, "")
	self.offsetXInput:SetValue(0.0)
	row5:AddChild(self.offsetXInput)

	row5:AddChild(LM.GUI.StaticText("Y:"))
	self.offsetYInput = LM.GUI.TextControl(0, "0.00", 0, LM.GUI.FIELD_FLOAT, "")
	self.offsetYInput:SetValue(0.0)
	row5:AddChild(self.offsetYInput)

	layout:AddChild(row5)

	-- Offset mode (fixed or incremental)
	local row6 = LM.GUI.HorizontalLayout()
	row6:AddChild(LM.GUI.StaticText("Offset Mode:"))
	self.offsetModeMenu = LM.GUI.PopupMenu()
	self.offsetModeMenu:AddItem("Fixed (same offset for all)")
	self.offsetModeMenu:AddItem("Incremental (stacking)")
	self.offsetModeMenu:SetSel(0) -- default fixed
	row6:AddChild(self.offsetModeMenu)
	layout:AddChild(row6)

	return layout
end

function JM_BoneHighlightTool:UpdateWidgets(moho)
	if self.checkbox then
		self.checkbox:SetValue(self.syncWithMoho)
	end
	if self.strengthSlider then
		self.strengthSlider:SetValue(0.0)
	end
	if self.strengthInput then
		self.strengthInput:SetValue(0.0)
	end
	if self.cloneCountInput then
		self.cloneCountInput:SetValue(1)
	end
end

function JM_BoneHighlightTool:HandleMessage(moho, view, msg)
	if msg == self.checkbox then
		self.syncWithMoho = self.checkbox:Value()
		moho.view:DrawMe()

	elseif msg == self.strengthSlider then
		local val = self.strengthSlider:Value()
		self.strengthInput:SetValue(val)
		self:ApplyStrengthToHighlighted(moho, val)

	elseif msg == self.strengthInput then
		local val = self.strengthInput:FloatValue()
		val = math.max(0, math.min(1, val)) -- clamp
		self.strengthSlider:SetValue(val)
		self:ApplyStrengthToHighlighted(moho, val)

	elseif msg == self.cloneBtn then
		self:CloneBones(moho, false)

	elseif msg == self.cloneMirrorBtn then
		self:CloneBones(moho, true)

	elseif msg == self.cloneCountInput or msg == self.offsetToggle or msg == self.offsetXInput or msg == self.offsetYInput or msg == self.offsetModeMenu then
		moho.view:DrawMe()
	end
end

function JM_BoneHighlightTool:ApplyStrengthToHighlighted(moho, val)
	local skel = moho:Skeleton()
	if skel then
		for i = 0, skel:CountBones()-1 do
			if self.highlightedBones[i] then
				skel:Bone(i).fStrength = val
			end
		end
	end
	moho.view:DrawMe()
end

----------------------------------------------------
-- Clone & Mirror (with offset + clone count)
----------------------------------------------------
function JM_BoneHighlightTool:CloneBones(moho, mirror)
	local skel = moho:Skeleton()
	if not skel then return end

	local newHighlights = {}
	local mode = self.axisMenu:Sel()
	local customX = self.customXInput:FloatValue()

	local useOffset = self.offsetToggle and self.offsetToggle:Value()
	local dx = self.offsetXInput:FloatValue()
	local dy = self.offsetYInput:FloatValue()
	local offsetMode = self.offsetModeMenu:Sel()

	local cloneCount = self.cloneCountInput:FloatValue()
	if cloneCount < 1 then cloneCount = 1 end

	for c = 1, cloneCount do
		local cloneIndex = c - 1

		for i = 0, skel:CountBones()-1 do
			if self.highlightedBones[i] then
				local bone = skel:Bone(i)
				local newBone = skel:AddBone(bone)

				-- Rename
				if mirror then
					newBone.fName = bone.fName .. "_mirror" .. tostring(c)
				else
					newBone.fName = bone.fName .. "_clone" .. tostring(c)
				end

				-- Apply mirroring
				if mirror then
					if mode == 0 then
						-- Horizontal (Y axis symmetry)
						newBone.fPos.x = -bone.fPos.x
						newBone.fAngle = -bone.fAngle
					elseif mode == 1 then
						-- Vertical (X axis symmetry)
						newBone.fPos.y = -bone.fPos.y
						newBone.fAngle = math.pi - bone.fAngle
					elseif mode == 2 then
						-- Custom X mirror line
						newBone.fPos.x = 2*customX - bone.fPos.x
						newBone.fAngle = -bone.fAngle
					end
				end

				-- Apply offset if enabled
				if useOffset then
					if offsetMode == 0 then
						-- Fixed offset
						newBone.fPos.x = newBone.fPos.x + dx
						newBone.fPos.y = newBone.fPos.y + dy
					elseif offsetMode == 1 then
						-- Incremental offset
						newBone.fPos.x = newBone.fPos.x + dx * (cloneIndex + 1)
						newBone.fPos.y = newBone.fPos.y + dy * (cloneIndex + 1)
					end
				end

				newHighlights[newBone.fID] = true
			end
		end
	end

	-- Replace highlights with clones
	self.highlightedBones = newHighlights

	-- Sync with Moho if enabled
	if self.syncWithMoho then
		for i = 0, skel:CountBones()-1 do
			skel:Bone(i).fSelected = self.highlightedBones[i] or false
		end
	end

	moho:UpdateUI()
	moho.view:DrawMe()
end

----------------------------------------------------
-- Mouse interaction
----------------------------------------------------
function JM_BoneHighlightTool:OnMouseDown(moho, mouseEvent)
	self.dragging = false
	self.startX = mouseEvent.pt.x
	self.startY = mouseEvent.pt.y

	if not mouseEvent.shiftDown then
		self.highlightedBones = {}
	end
end

function JM_BoneHighlightTool:OnMouseDrag(moho, mouseEvent)
	self.dragging = true
	self.endX = mouseEvent.pt.x
	self.endY = mouseEvent.pt.y
	moho.view:DrawMe()
end

function JM_BoneHighlightTool:OnMouseUp(moho, mouseEvent)
	local skel = moho:Skeleton()
	if not skel then return end

	if self.dragging then
		-- Box select
		local minX = math.min(self.startX, mouseEvent.pt.x)
		local maxX = math.max(self.startX, mouseEvent.pt.x)
		local minY = math.min(self.startY, mouseEvent.pt.y)
		local maxY = math.max(self.startY, mouseEvent.pt.y)

		for i = 0, skel:CountBones()-1 do
			local bone = skel:Bone(i)
			local pos = moho.view:WorldToScreen(bone.fPos)
			if pos.x >= minX and pos.x <= maxX and pos.y >= minY and pos.y <= maxY then
				self.highlightedBones[i] = true
			end
		end
	else
		-- Click closest bone
		local clickPt = mouseEvent.pt
		local closestBone, closestDist = nil, 999999

		for i = 0, skel:CountBones()-1 do
			local bone = skel:Bone(i)
			local pos = moho.view:WorldToScreen(bone.fPos)
			local tip = moho.view:WorldToScreen(bone:Tip())

			local dx, dy = clickPt.x - pos.x, clickPt.y - pos.y
			local distStart = dx*dx + dy*dy

			local dx2, dy2 = clickPt.x - tip.x, clickPt.y - tip.y
			local distTip = dx2*dx2 + dy2*dy2

			local dist = math.min(distStart, distTip)
			if dist < closestDist then
				closestDist = dist
				closestBone = i
			end
		end

		if closestBone and closestDist < 400 then
			self.highlightedBones[closestBone] = true
		end
	end

	self.dragging = false

	if self.syncWithMoho then
		for i = 0, skel:CountBones()-1 do
			skel:Bone(i).fSelected = self.highlightedBones[i] or false
		end
	end

	moho.view:DrawMe()
end

----------------------------------------------------
-- Keyboard shortcut
----------------------------------------------------
function JM_BoneHighlightTool:OnKeyDown(moho, keyEvent)
	if keyEvent.keyCode == LM.GUI.KEY_ESC then
		self.highlightedBones = {}
		moho.view:DrawMe()
	end
end

----------------------------------------------------
-- Drawing (highlights + selection box)
----------------------------------------------------
function JM_BoneHighlightTool:Draw(moho, view)
	local skel = moho:Skeleton()
	if not skel then return end

	local r, g, b = 1, 0, 0
	if self.syncWithMoho then
		r, g, b = 0.7, 0, 1
	end

	for i = 0, skel:CountBones()-1 do
		if self.highlightedBones[i] then
			local bone = skel:Bone(i)
			local startPt = view:WorldToScreen(bone.fPos)
			local endPt = view:WorldToScreen(bone:Tip())
			view:SetColor(r, g, b)
			view:DrawLine(startPt, endPt)
			view:DrawCircle(startPt, 4)
			view:DrawCircle(endPt, 4)
		end
	end

	if self.dragging then
		view:SetColor(0, 1, 0)
		view:DrawRect(self.startX, self.startY, self.endX, self.endY)
	end
end