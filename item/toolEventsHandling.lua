local replicatedStorage = game:GetService('ReplicatedStorage')
local serverScriptService = game:GetService('ServerScriptService')
local playerService = game:GetService('Players')

local itemIdList = require(replicatedStorage.Modules.itemIdList)
local chestModule = require(script.Parent.chests)
local playerApi = require(serverScriptService.API.Player.playerAPI)

local te = {}

local toolSerialLink = {
	[13] = {
		radius = 10
	}
}


--[[
for easy hitboxing using spatial query
-> set up custom query later for performance boost
TODO; setup custom spatial query
]]
local function frontBox(char : Model, size : Vector3, range : number, scanType : string?)
	local hrp = char:FindFirstChild('HumanoidRootPart')
	if hrp == nil then return end
	scanType = scanType or 'Model'
	
	local hitboxCF = hrp.CFrame * CFrame.new(0, 0, -range)
	local hitboxSize = size or vector.one

	local hitParts = workspace:GetPartBoundsInBox(hitboxCF,hitboxSize)
	local hitScan = {}
	
	for _, part in hitParts do
		local model = part:FindFirstAncestorOfClass(scanType)
		if not model then continue end
		
		--> ignore players
		if playerService:GetPlayerFromCharacter(model) then continue end
		
		hitScan[model] = true
	end
	
	return hitScan
end

local function checkTags(char, hitModel)
	if hitModel == char then return true end

	local modelTags = hitModel:GetTags()
	local tagFound = false

	--> TODO; decouple tags functions
	for _, v in modelTags do
		if v == 'chest' then
			chestModule.hitChest(hitModel)
			tagFound = true
		end
	end
	
	return tagFound
end

--> actual tool actions (ata)

--[[
Sword Category Function
]]
local function Sword(
	player, 
	timeFired,
	serialID, 
	itemID, 
	item
)
	local char = player.Character
	if not char then return end
	
	--> accept {} for default values
	local itemData = toolSerialLink[serialID] or {}
	
	--> coalesce default values
	local range = itemData.radius or 10
	
	--> get parts in hitbox / coalesce to avoid nil err
	local hitScan = frontBox(char,Vector3.new(7,5,7), range/2) or {}
	
	--> just the check
	for model,_ in hitScan do
		
		if checkTags(char, model) then continue end
		
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then continue end

		humanoid.Health -= 50
		
	end
	
end

--[[
Bow Category Function
]]
local function Bow(
	player, 
	timeFired,
	serialID, 
	itemID, 
	item
)
	local char = player.Character
	if not char then return end

	--> accept {} for default values
	local itemData = toolSerialLink[serialID] or {}
	
	--> TODO; actually change this reactivity
	task.wait(.1)
	
	local hitScan = frontBox(char, Vector3.new(2,3,25), 12.5)
	
	--> just the check
	for model,_ in hitScan do

		if checkTags(char, model) then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then continue end

		humanoid.Health -= 25

	end
	
end

--[[
Staff Category Function
]]
local function Staff(
	player, 
	timeFired,
	serialID, 
	itemID, 
	item
)
	local char = player.Character
	if not char then return end

	--> accept {} for default values
	local itemData = toolSerialLink[serialID] or {}
	
	--> TODO; actually change this reactivity
	task.wait(.1)

	local hitScan = frontBox(char, Vector3.new(2,3,25), 12.5)

	--> just the check
	for model,_ in hitScan do

		if checkTags(char, model) then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then continue end

		humanoid.Health -= 25

	end
end

--[[
Potion Category Function
]]
local function Potion(
	player, 
	timeFired,
	serialID, 
	itemID, 
	item
)
	local char = player.Character
	if not char then return end
	
	--> accept {} for default values
	local itemData = toolSerialLink[serialID] or {}
	
	playerApi.RemoveItemByID(player, itemID)
	
	--> all potions are cur health potion
	playerApi.IncreasePlayerHealth(player, 50)

end

--> functionality link table
local categories = {
	['Sword'] = Sword,
	['Bow'] = Bow,
	['Staff'] = Staff,
	['Potion'] = Potion
}

--[[
main api function
]]
function te.fireToolAction(player, timeFired, itemUID)
	if not (player and timeFired) then return end
	
	--> special case where attack is assumed punch
	if not itemUID then
		
		return
	end
	
	local item = player.Character and player.Character:FindFirstChild(itemUID)
	
	local serialID = item and item:FindFirstChild('objData') and item.objData:GetAttribute('id')
	
	if not serialID then warn('item doesnt exist') return end
	
	local toolObject = itemIdList.cachedTable[serialID]
	if toolObject == nil then warn('no tool obj') return end
	
	local objData = toolObject:FindFirstChild('objData')
	if not objData then warn('nil obj data') return end
	
	local category = objData:GetAttribute('category')
	if not category then warn('nil category') return end
	
	local refFunc = categories[category]
	if not refFunc then warn(`{serialID}, {category} has no action functionality -> ERR 01; toolEvents, fireToolAction`) return end
	
	refFunc(player, timeFired, serialID, itemUID, item)
	
	return
end

return te
