local proximityPromptService = game:GetService('ProximityPromptService')

local activeTriggers = {}
local callbackModule = {}
local activeListeners = {}

local function isValidCallbackModule(module)
	return type(module.onShown) == "function"
		and type(module.onTriggered) == "function"
		and type(module.onHidden) == "function"
end

for _, v in script:GetChildren() do
	if v:IsA('ModuleScript') then
		local callbackModuleEntry = require(v)
		if isValidCallbackModule(callbackModuleEntry) then
			callbackModule[v.Name] = callbackModuleEntry
		else
			warn(`PROXHOVER - {v.Name} is missing required methods`)
		end
	end
end

script.ChildAdded:Connect(function(v)
	if not v:IsA('ModuleScript') then return end
	local callbackModuleEntry = require(v)
	if isValidCallbackModule(callbackModuleEntry) then
		callbackModule[v.Name] = callbackModuleEntry
	else
		warn(`PROXHOVER - {v.Name} is missing required methods`)
	end
end)

proximityPromptService.PromptShown:Connect(function(prompt)
	local function handleCallback(callbackName)
		local callbackModuleEntry = callbackModule[callbackName]
		if not callbackModuleEntry then warn(`No callback module found for "{callbackName}"`) return end

		callbackModuleEntry.onShown(prompt)

		activeTriggers[prompt] = prompt.Triggered:Once(function()
			callbackModuleEntry.onTriggered(prompt)
		end)
	end

	local promptCallback = prompt:GetAttribute('callback')
	if promptCallback then
		
		handleCallback(promptCallback)
		
	else
		local listener : RBXScriptConnection
		
		listener = prompt:GetAttributeChangedSignal('callback'):Connect(function()
			local updatedCallback = prompt:GetAttribute('callback')
			if not updatedCallback then return end
				
			handleCallback(updatedCallback)
			
			if not listener then return end
			
			listener:Disconnect()
			activeListeners[prompt] = nil
		end)
		
		activeListeners[prompt] = listener
	end
end)

proximityPromptService.PromptHidden:Connect(function(prompt)
	if activeTriggers[prompt] then
		activeTriggers[prompt]:Disconnect()
		activeTriggers[prompt] = nil
	end

	if activeListeners[prompt] then
		activeListeners[prompt]:Disconnect()
		activeListeners[prompt] = nil
	end

	local promptCallback = prompt:GetAttribute('callback')
	if not promptCallback then return end
	
	local callbackModuleEntry = callbackModule[promptCallback]
	if not callbackModuleEntry then return end
	
	callbackModuleEntry.onHidden(prompt)
end)
