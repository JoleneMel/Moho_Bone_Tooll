-- **************************************************
-- JM Bone Highlight Tool
-- **************************************************

ScriptName = "JM_BoneHighlightTool"

JM_BoneHighlightTool = {}

	function JM_BoneHighlightTool:Name() return "Bone Highlight Tool" end
	function JM_BoneHighlightTool:Version() return "0.8" end
	function JM_BoneHighlightTool:Description() return "Highlight bones, adjust strength, clone/mirror with offset and clone count options." end
	function JM_BoneHighlightTool:Creator() return "You + ChatGPT" end
	function JM_BoneHighlightTool:UILabel() return "Bone Highlight" end

	-- Load helpers (pure Lua file, safe for unit tests)
	local Helpers = dofile("JM_BoneHighlightHelpers.lua")

	----------------------------------------------------
	-- State
	----------------------------------------------------
	JM_BoneHighlightTool.highlightedBones = {}
	JM_BoneHighlightTool.syncWithMoho = false
	JM_BoneHighlightTool.clearOnEscEnabled = true
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
	-- Drawing highlights
	----------------------------------------------------
	function JM_BoneHighlightTool:Draw(moho, view)
		local skel = moho:Skeleton()
		if not skel then return end

		view:PushPen()
		view:SetColor(1, 1, 0, 1) -- Yellow highlight
		view:SetLineWidth(2)

		for i = 0, skel:CountBones() - 1 do
			if self.highlightedBones[i] then
				local bone = skel:Bone(i)
				local pos = bone.fPos
				local tip = pos + LM.Vector2:new_local(
				bone.fLength * math.cos(bone.fAngle),
				bone.fLength * math.sin(bone.fAngle)
				)
				view:DrawLine(pos, tip)
			end
		end

		view:PopPen()
	end

	----------------------------------------------------
	-- Mouse down: begin selection
	----------------------------------------------------
	function JM_BoneHighlightTool:OnMouseDown(moho, mouseEvent)
		self.dragging = true
		self.startX, self.startY = mouseEvent.pt.x, mouseEvent.pt.y
	end

	----------------------------------------------------
	-- Mouse drag: highlight bones under lasso
	----------------------------------------------------
	function JM_BoneHighlightTool:OnMouseMoved(moho, mouseEvent)
		if not self.dragging then return end
		local skel = moho:Skeleton()
		if not skel then return end

		local rect = LM.Rect:new_local(
		math.min(self.startX, mouseEvent.pt.x),
		math.min(self.startY, mouseEvent.pt.y),
		math.max(self.startX, mouseEvent.pt.x),
		math.max(self.startY, mouseEvent.pt.y)
		)

		for i = 0, skel:CountBones() - 1 do
			local bone = skel:Bone(i)
			if rect:Contains(bone.fPos) then
				self.highlightedBones[i] = true
			end
		end

		moho:UpdateUI()
		moho.view:DrawMe()
	end

	----------------------------------------------------
	-- Mouse up: stop drag
	----------------------------------------------------
	function JM_BoneHighlightTool:OnMouseUp(moho, mouseEvent)
		self.dragging = false
	end

	----------------------------------------------------
	-- Handle key events (ESC clear)
	----------------------------------------------------
	function JM_BoneHighlightTool:OnKeyDown(moho, keyEvent)
		if keyEvent.keyCode == LM.GUI.KEY_ESC and self.clearOnEscEnabled then
			self.highlightedBones = {}
			moho:UpdateUI()
			moho.view:DrawMe()
		end
	end

	----------------------------------------------------
	-- Dialog UI
	----------------------------------------------------
	function JM_BoneHighlightTool:DoLayout(moho, layout)
		-- Sync toggle
		self.syncCheckbox = LM.GUI.CheckBox("Sync With Moho Selection", 0)
		layout:AddChild(self.syncCheckbox, LM.GUI.ALIGN_LEFT, 0)

		-- Clear ESC toggle
		self.escCheckbox = LM.GUI.CheckBox("Enable Clear All w/ ESC", 0)
		self.escCheckbox:SetValue(self.clearOnEscEnabled)
		layout:AddChild(self.escCheckbox, LM.GUI.ALIGN_LEFT, 0)

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		-- Strength input
		self.strengthInput = LM.GUI.TextControl(0, "0.0", 0, LM.GUI.FIELD_FLOAT, "Bone Strength:")
		self.strengthInput:SetValue("0.0")
		layout:AddChild(self.strengthInput, LM.GUI.ALIGN_LEFT, 0)

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		-- Clone options
		self.cloneButton = LM.GUI.Button("Clone", 0)
		layout:AddChild(self.cloneButton, LM.GUI.ALIGN_LEFT, 0)

		self.mirrorButton = LM.GUI.Button("Clone + Mirror", 0)
		layout:AddChild(self.mirrorButton, LM.GUI.ALIGN_LEFT, 0)

		-- Axis choice
		self.axisMenu = LM.GUI.Menu("Mirror Axis")
		self.axisMenu:AddItem("Horizontal (Y Axis)", 0)
		self.axisMenu:AddItem("Vertical (X Axis)", 1)
		self.axisMenu:AddItem("Custom X", 2)
		self.axisPopup = LM.GUI.PopupMenu(100, false)
		self.axisPopup:SetMenu(self.axisMenu)
		layout:AddChild(self.axisPopup, LM.GUI.ALIGN_LEFT, 0)

		-- Custom X field
		self.customXInput = LM.GUI.TextControl(0, "0.0", 0, LM.GUI.FIELD_FLOAT, "Custom X:")
		layout:AddChild(self.customXInput, LM.GUI.ALIGN_LEFT, 0)

		-- Clone count
		self.cloneCountInput = LM.GUI.TextControl(0, "1", 0, LM.GUI.FIELD_INT, "Clone Count:")
		self.cloneCountInput:SetValue("1")
		layout:AddChild(self.cloneCountInput, LM.GUI.ALIGN_LEFT, 0)

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		-- Offset options
		self.offsetToggle = LM.GUI.CheckBox("Enable Offset", 0)
		layout:AddChild(self.offsetToggle, LM.GUI.ALIGN_LEFT, 0)

		self.offsetXInput = LM.GUI.TextControl(0, "0.0", 0, LM.GUI.FIELD_FLOAT, "Offset X:")
		layout:AddChild(self.offsetXInput, LM.GUI.ALIGN_LEFT, 0)

		self.offsetYInput = LM.GUI.TextControl(0, "0.0", 0, LM.GUI.FIELD_FLOAT, "Offset Y:")
		layout:AddChild(self.offsetYInput, LM.GUI.ALIGN_LEFT, 0)

		self.offsetModeMenu = LM.GUI.Menu("Offset Mode")
		self.offsetModeMenu:AddItem("Fixed", 0)
		self.offsetModeMenu:AddItem("Incremental", 1)
		self.offsetPopup = LM.GUI.PopupMenu(101, false)
		self.offsetPopup:SetMenu(self.offsetModeMenu)
		layout:AddChild(self.offsetPopup, LM.GUI.ALIGN_LEFT, 0)
	end

	----------------------------------------------------
	-- Update widgets
	----------------------------------------------------
	function JM_BoneHighlightTool:UpdateWidgets(moho)
		self.syncCheckbox:SetValue(self.syncWithMoho)
		self.escCheckbox:SetValue(self.clearOnEscEnabled)
	end

	----------------------------------------------------
	-- Handle widget actions
	----------------------------------------------------
	function JM_BoneHighlightTool:HandleMessage(moho, view, msg)
		if msg == self.syncCheckbox then
			self.syncWithMoho = self.syncCheckbox:Value()
			if self.syncWithMoho then
				self.syncCheckbox:SetTextColor(0.6, 0, 1) -- purple
			else
				self.syncCheckbox:SetTextColor(1, 0, 0) -- red
			end

		elseif msg == self.escCheckbox then
			self.clearOnEscEnabled = self.escCheckbox:Value()

		elseif msg == self.strengthInput then
			-- Apply bone strength immediately
			local val = self.strengthInput:FloatValue()
			local skel = moho:Skeleton()
			if skel then
				for i = 0, skel:CountBones()-1 do
					if self.highlightedBones[i] then
						skel:Bone(i).fStrength = val
					end
				end
			end
			moho:UpdateUI()
			moho.view:DrawMe()

		elseif msg == self.cloneButton then
			self:CloneBones(moho, false)

		elseif msg == self.mirrorButton then
			self:CloneBones(moho, true)
		end
	end

	----------------------------------------------------
	-- Clone bones (mirror + offset + count)
	----------------------------------------------------
	function JM_BoneHighlightTool:CloneBones(moho, mirror)
		local skel = moho:Skeleton()
		if not skel then return end

		local newHighlights = {}
		local mode = self.axisPopup:Sel()
		local customX = self.customXInput:FloatValue()

		local useOffset = self.offsetToggle and self.offsetToggle:Value()
		local dx = self.offsetXInput:FloatValue()
		local dy = self.offsetYInput:FloatValue()
		local offsetMode = self.offsetPopup:Sel()

		local cloneCount = self.cloneCountInput:IntValue()
		if cloneCount < 1 then cloneCount = 1 end

		for c = 1, cloneCount do
			local cloneIndex = c - 1
			for i = 0, skel:CountBones()-1 do
				if self.highlightedBones[i] then
					local bone = skel:Bone(i)

					local newPos = {x = bone.fPos.x, y = bone.fPos.y}
					local newAngle = bone.fAngle

					-- Mirror
					if mirror then
						newPos, newAngle = Helpers.CalcMirror(newPos, newAngle, mode, customX)
					end

					-- Offset
					newPos = Helpers.ApplyOffset(newPos, dx, dy, cloneIndex, useOffset, offsetMode)

					-- Create
					local newBone = skel:AddBone(bone)
					newBone.fPos.x = newPos.x
					newBone.fPos.y = newPos.y
					newBone.fAngle = newAngle
					newBone.fName = Helpers.GenerateCloneName(bone.fName, mirror, c)

					newHighlights[newBone.fID] = true
				end
			end
		end

		self.highlightedBones = newHighlights

		-- Sync with Moho selection
		if self.syncWithMoho then
			for i = 0, skel:CountBones()-1 do
				skel:Bone(i).fSelected = self.highlightedBones[i] or false
			end
		end

		moho:UpdateUI()
		moho.view:DrawMe()
	end
--gave a smaller version idk 