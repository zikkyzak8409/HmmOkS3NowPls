--> i realised that .AniamtionPlayed is not always reliable (drastic told me) but im post this anyway

local playerService = game:GetService('Players')
local player = playerService.LocalPlayer

local anim = {}

local linkTable = {} :: {
	[string] : {
		[string] : (Model, AnimationTrack?) -> ()
	} 
}

local monitoredPlayers = {} :: {
	[Player] : {
		[number] : RBXScriptSignal
	}
}

local function loadAnimVfx()
	for _, v in script:GetDescendants() do
		if not v:IsA('ModuleScript') then continue end
		
		local animModule = require(v)
		if not animModule then continue end
		
		local animData = animModule.data
		
		if not animData then
			warn(`data non existent for {v.Name} vfx module`)
			continue
		end
		
		local animId = animData.animId
		if not animId then
			warn(`animation id non existent in {v.Name} vfx module`)
			continue
		end
		
		local onStart = animModule.onStart
		local onStop = animModule.onStop
		
		if not onStart or not onStop then
			warn(`onStart or onStop non existent in {v.Name} vfx module`)
			continue
		end
		
		if linkTable[animId] == nil then
			linkTable[animId] = {
				startFunc = onStart,
				stopFunc = onStop
			}
		end
	end
end

local function registerCharacter(char : Model)
	if not char then return end
	
	local humanoid = char:WaitForChild('Humanoid') :: Humanoid
	if not humanoid then return end
	
	local animator = humanoid:WaitForChild('Animator') :: Animator
	if not animator then return end
	
	return animator.AnimationPlayed:Connect(function(track)
		
		if not track.Animation then warn('no anim') return end
		
		local animId = track.Animation.AnimationId
		local animData = linkTable[animId]
		if not animData then return end
		
		local startFunc = animData.startFunc
		local stopFunc = animData.stopFunc
		
		if startFunc then startFunc(char, track) end
		if not stopFunc then return end
		
		track.Ended:Once(function()
			stopFunc(char)
		end)
	end)
end

local function startMonitoringPlayer(player : Player)
	if monitoredPlayers[player] then return end
	monitoredPlayers[player] = {}
	
	local curCharacter = player.Character
	if curCharacter then monitoredPlayers[player] = {[2] = registerCharacter(curCharacter)} end
	
	monitoredPlayers[player][1] = player.CharacterAdded:Connect(function()
		if monitoredPlayers[player][2] then monitoredPlayers[player][2]:Disconnect() end
		monitoredPlayers[player][2] = registerCharacter(player.Character)
	end)
end

local function stopMonitoringPlayer(player : Player)
	if not monitoredPlayers[player] then return end
	
	for _, conn in monitoredPlayers[player] do
		if conn then conn:Disconnect() end
	end
	
	monitoredPlayers[player] = nil
end

playerService.PlayerAdded:Connect(startMonitoringPlayer)
playerService.PlayerRemoving:Connect(stopMonitoringPlayer)

loadAnimVfx()

startMonitoringPlayer(player)

return anim
