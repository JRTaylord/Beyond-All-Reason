local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gunship Strafe Fix",
		desc = "When gunships stop attacking their target unit with no followup command, forces them to stop strafing and enter idle behavior",
		author = "JRTaylord: https://github.com/JRTaylord",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Only run in synced code
if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetGameFrame = Spring.GetGameFrame
local spSetUnitVelocity = Spring.SetUnitVelocity

-- Gadget variables
local gunshipWeaponCounts = {}
local gunshipsToTrack = {}
local gunshipsToStop = {}

-- Helper functions
local function isTargettingUnit(unitID, unitDefID)
	local weaponCount = gunshipWeaponCounts[unitDefID]
	for weaponNum = 1, weaponCount do
		local targetType, _, targetID = spGetUnitWeaponTarget(unitID, weaponNum)
		if targetType == 1 and targetID then
			return true
		end
	end
	return false
end

local function stopGunshipIfNoCmdAndTarget(unitID, unitDefID)
	local numCommands = spGetUnitCommandCount(unitID)
	local hasTarget = isTargettingUnit(unitID, unitDefID)
	if numCommands == 0 and not hasTarget then
		local frame = spGetGameFrame()
		gunshipsToStop[unitID] = frame
	end
end

function gadget:Initialize()
	-- Find all gunship units
	for unitDefID, unitDef in pairs(UnitDefs) do
		if (unitDef.isHoveringAirUnit or unitDef.hoverattack) and #unitDef.weapons > 0 then
			gunshipWeaponCounts[unitDefID] = #unitDef.weapons
		end
	end

	-- Register any existing gunships and stops them if already idle to ensure this fix works when loading scenarios or saved games
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if gunshipWeaponCounts[unitDefID] then
			gunshipsToTrack[unitID] = true
			stopGunshipIfNoCmdAndTarget(unitID, unitDefID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	-- Called when a unit is created
	if gunshipWeaponCounts[unitDefID] then
		-- Initialize previous command for new gunship unit ID
		gunshipsToTrack[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	-- Called when a unit is destroyed
	gunshipsToTrack[unitID] = nil
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if gunshipsToTrack[unitID] and cmdID == CMD.ATTACK then
		stopGunshipIfNoCmdAndTarget(unitID, unitDefID)
	end
end

function gadget:GameFrame(frame)
	-- if frame % 2 ~= 0 then
	-- 	return
	-- end
	for unitID, currGunshipStopFrame in pairs(gunshipsToStop) do
		if spGetUnitCommandCount(unitID) > 0 then
			Spring.Echo(unitID, "stop interrupt")
			gunshipsToStop[unitID] = nil
			break
		end
		Spring.SetUnitTarget(unitID, nil, false, false, -1)
		spSetUnitVelocity(unitID, 0, -2, 0)
		if frame - currGunshipStopFrame > 40 then
			gunshipsToStop[unitID] = nil
		end
	end
end
