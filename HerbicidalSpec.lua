
-- Create a new class that inherits from a base class
--
function inheritsFrom( baseClass )

    -- The following lines are equivalent to the SimpleClass example:

    -- Create the table and metatable representing the class.
    local new_class = {}
    local class_mt = { __index = new_class }

    -- Note that this function uses class_mt as an upvalue, so every instance
    -- of the class will share the same metatable.
    --
    function new_class:create()
        local newinst = {}
        setmetatable( newinst, class_mt )
        return newinst
    end

    -- The following is the key to implementing inheritance:

    -- The __index member of the new class's metatable references the
    -- base class.  This implies that all methods of the base class will
    -- be exposed to the sub-class, and that the sub-class can override
    -- any of these methods.
    --
    if baseClass then
        setmetatable( new_class, { __index = baseClass } )
    end

    return new_class
end

--HerbicidalSpec = inheritsFrom(SowingMachine)
HerbicidalSpec = {}
HerbicidalSpec.spec_sowingMachine	=g_specializationManager:getSpecializationByName("sowingMachine")
HerbicidalSpec.spec_sprayer			=g_specializationManager:getSpecializationByName("sprayer")


function HerbicidalSpec.prerequisitesPresent(specializations)
	print("Checking herbicidal prereqs")
	local hasSow	=SpecializationUtil.hasSpecialization(SowingMachine, specializations)
	local hasSpray	=SpecializationUtil.hasSpecialization(Sprayer, specializations)

	print("Specs: ", hasSow ~= nil, hasSpray ~= nil)
	print("Specs2: ", hasSow, hasSpray)

	if hasSow ~= nil and hasSpray ~= nil then		
		return	true
	end

	return SpecializationUtil.hasSpecialization(SowingMachine, specializations) and SpecializationUtil.hasSpecialization(Sprayer, specializations)
end

function HerbicidalSpec.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", HerbicidalSpec.processSowingMachineArea)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getUseSprayerAIRequirements", HerbicidalSpec.getUseSprayerAIRequirements)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAreEffectsVisible", HerbicidalSpec.getAreEffectsVisible)
end

function HerbicidalSpec.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", HerbicidalSpec)
end

function HerbicidalSpec:onLoad(savegame)
	self.needsSetIsTurnedOn = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.herbicidalSowingMachine#needsSetIsTurnedOn"), false)
	self.spec_sprayer.needsToBeFilledToTurnOn = false
	self.spec_sprayer.useSpeedLimit = false
end

function HerbicidalSpec:processSowingMachineArea(superFunc, workArea, dt)
	local spec = self
	local specSowingMachine = self.spec_sowingMachine
	local specSpray = self.spec_sprayer
	local sprayerParams = specSpray.workAreaParameters
	local sowingParams = specSowingMachine.workAreaParameters
	local changedArea, totalArea
	self.spec_sowingMachine.isWorking = self:getLastSpeed() > 0.5
	if not sowingParams.isActive then
		return 0, 0
	end
	if not self:getIsAIActive() or not g_currentMission.missionInfo.helperBuySeeds then
		if sowingParams.seedsVehicle == nil then
			if self:getIsAIActive() then
				local rootVehicle = self:getRootVehicle()
				rootVehicle:stopAIVehicle(AIVehicle.STOP_REASON_OUT_OF_FILL)
			end
			return 0, 0
		end
	end
	
	-- stop the sowing machine if the fertilizer tank was filled and got empty
	-- do not stop if the tank was all the time empty
	if not g_currentMission.missionInfo.helperBuyFertilizer then
		if self:getIsAIActive() then
			if sprayerParams.sprayFillType == nil or sprayerParams.sprayFillType == FillType.UNKNOWN then
				if sprayerParams.lastAIHasSprayed ~= nil then
					local rootVehicle = self:getRootVehicle()
					rootVehicle:stopAIVehicle(AIVehicle.STOP_REASON_OUT_OF_FILL)
					sprayerParams.lastAIHasSprayed = nil
				end
			else
				sprayerParams.lastAIHasSprayed = true
			end
		end
	end
	if not sowingParams.canFruitBePlanted then
		return 0, 0
	end

	-- we need to use fertilizer as spraying type because fertilizer is the final blocking value
	local sprayTypeIndex = SprayType.FERTILIZER
	if sprayerParams.sprayFillLevel <= 0 or (spec.needsSetIsTurnedOn and not self:getIsTurnedOn()) then
		sprayTypeIndex = nil
	end
	
	local startX,_,startZ = getWorldTranslation(workArea.start)
	local widthX,_,widthZ = getWorldTranslation(workArea.width)
	local heightX,_,heightZ = getWorldTranslation(workArea.height)
	
	if not specSowingMachine.useDirectPlanting then
		changedArea, totalArea = FSDensityMapUtil.updateSowingArea(sowingParams.seedsFruitType, startX, startZ, widthX, widthZ, heightX, heightZ, sowingParams.angle, nil, sprayTypeIndex)
	else
		changedArea, totalArea = FSDensityMapUtil.updateDirectSowingArea(sowingParams.seedsFruitType, startX, startZ, widthX, widthZ, heightX, heightZ, sowingParams.angle, nil, sprayTypeIndex)
	end
	
	self.spec_sowingMachine.isProcessing = self.spec_sowingMachine.isWorking

	-- This stuff is handled in the spray specialization
	-- having it here just doubles things
--	if sprayTypeIndex ~= nil then
--		local sprayChangedArea, sprayTotalArea = FSDensityMapUtil.updateSprayArea(startX, startZ, widthX, widthZ, heightX, heightZ, sprayTypeIndex)
--
--		sprayerParams.lastChangedArea = sprayerParams.lastChangedArea + sprayChangedArea
--		sprayerParams.lastTotalArea = sprayerParams.lastTotalArea + sprayTotalArea
--		sprayerParams.lastStatsArea = 0
--		sprayerParams.isActive = true
--
--		local stats = g_currentMission:farmStats(self:getLastTouchedFarmlandFarmId())
--		local ha = MathUtil.areaToHa(sprayerParams.lastChangedArea, g_currentMission:getFruitPixelsToSqm())
--		
--		stats:updateStats("fertilizedHectares", ha)
--		stats:updateStats("fertilizedTime", dt/(1000*60))
--		stats:updateStats("sprayUsage", sprayerParams.usage)
--	end
	sowingParams.lastChangedArea = sowingParams.lastChangedArea + changedArea
	sowingParams.lastStatsArea = sowingParams.lastStatsArea + changedArea
	sowingParams.lastTotalArea = sowingParams.lastTotalArea + totalArea
	
	-- remove tireTracks
	FSDensityMapUtil.eraseTireTrack(startX, startZ, widthX, widthZ, heightX, heightZ)
	self:updateMissionSowingWarning(startX, startZ)
	return changedArea, totalArea
end

function HerbicidalSpec:getUseSprayerAIRequirements(superFunc)
	return false
end

function HerbicidalSpec:getAreEffectsVisible(superFunc)
	return superFunc(self) and self:getFillUnitFillType(self:getSprayerFillUnitIndex()) ~= FillType.UNKNOWN
end