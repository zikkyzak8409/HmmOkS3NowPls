local char = {}

local replicatedStorage = game:GetService('ReplicatedStorage')
local spawns = require(script.Parent.spawn)
local itemIdList = require(replicatedStorage.Modules.itemIdList)

local function GetActiveSlot(player : Player?) : number | string?
	assert(player, `getactiveslot assertion {player}`)
	return player:GetAttribute('ActiveSlot')
end

--[[
Returns active slot's inventory folder
]]
local function GetPlayerBackpack(player : Player)
	assert(player, `api getplayerbackpack nil player`)

	local curSlot = GetActiveSlot(player)
	local slot = player:WaitForChild('playerData'):WaitForChild('charData'):FindFirstChild(curSlot)
	if not slot then warn(`api slot {curSlot} does not exist`) return end

	return slot:FindFirstChild('inventory')
end

local function GetNewItemUID(player : Player?)
	assert(player, `api getnewitemuid no player`)

	local inv = GetPlayerBackpack(player)
	local children = inv:GetChildren()

	return children and #children + 1 or 1
end


-- > Pickup Event

function char.onPickupEvent(player : Player?, pickupId : number?)
	if not (player and player.Character) then return end
	if not (pickupId and typeof(pickupId) == 'number') then return end
	local item = spawns.spawnedPool[pickupId]
	if not item then return end
	
	local objData = item:FindFirstChild('Main') and item['Main']:FindFirstChild('objData')
	if not (objData and objData:IsA('Configuration')) then return end
	local itemId = objData:GetAttribute('id')
	
	if not (itemId and typeof(itemId) == 'number') then return end
	
	local itemTool = itemIdList.cachedTable[itemId]
	if not itemTool then return end
	
	item:Destroy()
	
	itemTool = itemTool:Clone()
	
	local itemUID = GetNewItemUID(player)
	
	local itemStringValue = Instance.new('StringValue')
	itemStringValue.Value = `{itemId}:{objData:GetAttribute('level') or 1}`
	itemStringValue.Name = itemUID
	
	local inv = GetPlayerBackpack(player)
	itemStringValue.Parent = inv
	
	itemTool.objData:SetAttribute('uniqueID', itemUID)
	
	itemTool.Name = itemUID
	itemTool.Parent = player.Backpack
end
local pickupEvent = replicatedStorage.Events.Item.Pickup
pickupEvent.OnServerEvent:Connect(char.onPickupEvent)

return char
