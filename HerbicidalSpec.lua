--Custom specialization for planters / seeders that put down chemical
--Fixes the double fertilizing bug and allows herbicide to work
--Almost entirely a copy of the default FertilizingSowingMachine
HerbicidalSpec = {}
HerbicidalSpec.spec_sowingMachine	=g_specializationManager:getSpecializationByName("sowingMachine")
HerbicidalSpec.spec_sprayer			=g_specializationManager:getSpecializationByName("sprayer")


function HerbicidalSpec.prerequisitesPresent(specializations)
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