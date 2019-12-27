Herbicidal = {};

function Herbicidal.initialLoad()
	g_specializationManager:addSpecialization("HerbicidalSowingMachine",
		"HerbicidalSowingMachine", "HerbicidalSpec.lua", "FS19_CIH950Cyclo")
	source("HerbicidalSpec.lua")
end
