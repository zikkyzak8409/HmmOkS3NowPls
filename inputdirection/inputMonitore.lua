--[[
Note; this script is a revised script which avoids for loop lookups to return vector movement values
o(n) WORST CASE vs o(n) BEST CASE

TODO; bench it vs old script
]]

local userInputService = game:GetService('UserInputService')
local inputConfig = require(script:WaitForChild('config'))
local matrices = require(script:WaitForChild('matrix'))

-->types

type KEYS_DICT = {
	[Enum.KeyCode | Enum.UserInputType] : boolean
}
type CONFIG_DICT = {
	[string] : (input: InputObject, isBegan: boolean) -> boolean?
}
type GET_CONFIG_DICT = {
	[string] : () -> any
}

--> general variables
local downKeys : KEYS_DICT = {}
local normalisedUpdateConfigs : CONFIG_DICT = {}
local normalisedGetConfigs : GET_CONFIG_DICT = {}

--> for verifying config integrities and adding to normalisedConfigs
local function setNormalisedConfigs() : ()
	
	--for updating, configs require updateValue function or getValue function
	for configName, configTable in inputConfig do
		
		local updateFunction = configTable.updateValue
		local getFunction = configTable.getValue
		
		--we set updatevalue function
		if updateFunction then
			normalisedUpdateConfigs[configName] = updateFunction
		end
		
		--we set get function
		if getFunction then
			normalisedGetConfigs[configName] = getFunction
		end
	end
	
	return
end

--key monitoring -> downKeys[Enumerate]
userInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	
	--> just binding keypress
	downKeys[input.KeyCode] = true
	downKeys[input.UserInputType] = true
	
	--> updating values using relevant function; see fetchNormalisedConfigs()
	for _, updateFunction in normalisedUpdateConfigs do
		updateFunction(input, true, downKeys) --> returns boolean?
	end
	
end)
userInputService.InputEnded:Connect(function(input, gpe)
	if gpe then return end
	
	--> just unbinding keypress
	downKeys[input.KeyCode] = nil
	downKeys[input.UserInputType] = nil
	
	--> updating values using relevant function; see fetchNormalisedConfigs()
	for _, updateFunction in normalisedUpdateConfigs do
		updateFunction(input, false, downKeys) --> returns boolean?
	end
	
end)

--initiation

setNormalisedConfigs() --> ensure that configs function references are populated

--module consitution

local inputs = {}

function inputs.getPressedInputs() : KEYS_DICT
	return downKeys
end

function inputs.getValueFor(configName) : {any}?
	local referencedConfig = normalisedGetConfigs[configName]
	return referencedConfig and referencedConfig()
end

function inputs.getAxisMovement() : Vector3?
	return inputs.getValueFor('threeAxisMovement')
end

--> cool additions

function inputs.getAxisMovementRelativeToCamera() : Vector3
	local threeMovementAxis = inputs.getAxisMovement()
	
	--> incase movement not returned ??!
	if not threeMovementAxis then
		warn('Inputs - get axis movement relative to camera ERR 01')
		return vector.zero
	end
	
	return matrices.alignInputWithCamera(threeMovementAxis)
end

return inputs
