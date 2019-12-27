--Custom specialization for those pesky ridge markers
--Mainly want to stop them from folding / plowing when hidden by the shop
--Almost entirely a copy of the default RidgeMarker
RidgeFixer = {}


--hey this is neat, wonder if it works for the herbicial thing?
function RidgeFixer.initSpecialization()
	RidgeFixer.spec_foldable		=g_specializationManager:getSpecializationByName("foldable")
	RidgeFixer.spec_ridgeMarker		=g_specializationManager:getSpecializationByName("ridgeMarker")
	RidgeFixer.spec_sowingMachine	=g_specializationManager:getSpecializationByName("herbicidalSowingMachine")
end

function RidgeFixer.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Foldable, specializations)
			and SpecializationUtil.hasSpecialization(RidgeMarker, specializations)
end

function RidgeFixer.registerFunctions(vehicleType)
end

function RidgeFixer.registerOverwrittenFunctions(vehicleType)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadRidgeMarker",        		RidgeFixer.loadRidgeMarker)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "setRidgeMarkerState",    		RidgeFixer.setRidgeMarkerState)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "canFoldRidgeMarker",     		RidgeFixer.canFoldRidgeMarker)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processRidgeMarkerArea", 		RidgeFixer.processRidgeMarkerArea)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadWorkAreaFromXML",          RidgeFixer.loadWorkAreaFromXML)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsWorkAreaActive",          RidgeFixer.getIsWorkAreaActive)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadSpeedRotatingPartFromXML", RidgeFixer.loadSpeedRotatingPartFromXML)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSpeedRotatingPartActive", RidgeFixer.getIsSpeedRotatingPartActive)
--	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected",             RidgeFixer.getCanBeSelected)
end

function RidgeFixer.registerEventListeners(vehicleType)
--	SpecializationUtil.registerEventListener(vehicleType, "onLoad", RidgeFixer)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onSetLowered", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", RidgeFixer)
--	SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", RidgeFixer)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", RidgeFixer)
end

function RidgeFixer:onFoldStateChanged(direction, moveToMiddle)
    if not moveToMiddle and direction > 0 then
        self:setRidgeMarkerState(0, true)
    end
end

function RidgeFixer:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient then
--		print("Checking Z in update")
		local spec = self.spec_ridgeMarker
		local actionEvent = spec.actionEvents[spec.ridgeMarkerInputButton]
		if actionEvent ~= nil then
			local isVisible = false
			if spec.numRigdeMarkers > 0 then
				local newState = (spec.ridgeMarkerState + 1) % (spec.numRigdeMarkers+1)
				if self:canFoldRidgeMarker(newState) then
					isVisible = true
				end
			end
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, isVisible)
		end
	end

	local	spec	=self.spec_ridgeMarker
	local	specSow	=spec.spec_sowingMachine

	if true ~= specSow:getIsLowered(true) then
		self:setRidgeMarkerState(0, true)
	end
end

function RidgeFixer:onPostLoad(savegame)
	local spec = self.spec_ridgeMarker

	self.visNodes	={};
	
	--grab the top node for the markers
	--they might be hidden via the store
    local i = 0
    while true do
        local key = string.format("vehicle.ridgeFixer.markerVisibilityNode(%d)", i)
        if not hasXMLProperty(self.xmlFile, key) then
            break
		end

		local 	nodeString	=getXMLString(self.xmlFile, key .. "#value")
		local	nodeObj		=I3DUtil.indexToObject(self.components, nodeString, self.i3dMappings)

		if nodeObj ~= nil then
			print("MarkerNode found: " .. getName(nodeObj));
		end

		local	bVis	=getVisibility(nodeObj);
		if bVis ~= true then
			--bad spelling, took me forever to figureout
			--what was going wrong haha
			spec.numRigdeMarkers = spec.numRigdeMarkers - 1
			print("Hidden marker, decrementing marker count...")
		end

		i = i + 1
    end
end

function RidgeFixer:canFoldRidgeMarker(state)	
	local	spec			=self.spec_ridgeMarker
	local	actionEvent		=spec.actionEvents[spec.ridgeMarkerInputButton]
	local	foldAnimTime	=nil

	if self.getFoldAnimTime ~= nil then
		foldAnimTime = self:getFoldAnimTime()
		if foldAnimTime < spec.ridgeMarkerMinFoldTime or foldAnimTime > spec.ridgeMarkerMaxFoldTime then
			return false
		end
	end
	local	foldableSpec	=self.spec_foldable
	if state ~= 0 and not foldableSpec.moveToMiddle and spec.foldDisableDirection ~= nil and (spec.foldDisableDirection == foldableSpec.foldMoveDirection or foldableSpec.foldMoveDirection == 0) then
		return false
	end

	return true
end