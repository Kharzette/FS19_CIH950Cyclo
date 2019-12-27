Herbicidal = {};

function Herbicidal.initialLoad()
	g_specializationManager:addSpecialization("HerbicidalSowingMachine",
		"HerbicidalSowingMachine", "HerbicidalSpec.lua", "FS19_CIH950Cyclo")
	g_specializationManager:addSpecialization("HerbicidalSowingMachine",
		"HerbicidalSowingMachine", "HerbicidalSpec.lua", "FS19_CIH950Cyclo")

	source("HerbicidalSpec.lua")
	source("RidgeFixer.lua")
end
