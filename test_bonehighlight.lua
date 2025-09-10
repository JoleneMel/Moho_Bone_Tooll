-- test_bonehighlight.lua
-- Run with: lua test_bonehighlight.lua

luaunit = require("luaunit")
local Helpers = dofile("JM_BoneHighlightHelpers.lua")

TestBoneHighlight = {}

function TestBoneHighlight:testMirrorHorizontal()
	local pos, angle = {x=5, y=2}, 1.0
	local mirrored, mirroredAngle = Helpers.CalcMirror(pos, angle, 0, 0)
	luaunit.assertEquals(mirrored, {x=-5, y=2})
	luaunit.assertEquals(mirroredAngle, -1.0)
end

function TestBoneHighlight:testMirrorVertical()
	local pos, angle = {x=5, y=2}, 1.0
	local mirrored, mirroredAngle = Helpers.CalcMirror(pos, angle, 1, 0)
	luaunit.assertEquals(mirrored, {x=5, y=-2})
	luaunit.assertAlmostEquals(mirroredAngle, math.pi - 1.0, 1e-6)
end

function TestBoneHighlight:testMirrorCustom()
	local pos, angle = {x=3, y=1}, 0.5
	local mirrored, mirroredAngle = Helpers.CalcMirror(pos, angle, 2, 10)
	luaunit.assertEquals(mirrored, {x=17, y=1})
	luaunit.assertEquals(mirroredAngle, -0.5)
end

function TestBoneHighlight:testOffsetFixed()
	local pos = {x=1, y=1}
	local newPos = Helpers.ApplyOffset(pos, 2, 3, 0, true, 0)
	luaunit.assertEquals(newPos, {x=3, y=4})
end

function TestBoneHighlight:testOffsetIncremental()
	local pos = {x=0, y=0}
	local newPos = Helpers.ApplyOffset(pos, 2, 1, 2, true, 1) -- 3rd clone
	luaunit.assertEquals(newPos, {x=6, y=3})
end

function TestBoneHighlight:testOffsetDisabled()
	local pos = {x=10, y=10}
	local newPos = Helpers.ApplyOffset(pos, 5, 5, 0, false, 0)
	luaunit.assertEquals(newPos, {x=10, y=10})
end

function TestBoneHighlight:testCloneNameMirror()
	local name = Helpers.GenerateCloneName("Arm", true, 2)
	luaunit.assertEquals(name, "Arm_mirror2")
end

function TestBoneHighlight:testCloneNameNormal()
	local name = Helpers.GenerateCloneName("Leg", false, 1)
	luaunit.assertEquals(name, "Leg_clone1")
end

os.exit(luaunit.LuaUnit.run())
