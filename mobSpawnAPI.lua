local replicatedStorage = game:GetService('ReplicatedStorage')
local mobDirectory = replicatedStorage.Assets.Mobs
local mobWorkspaceFolder = workspace.Mobs

local terrain = require(replicatedStorage.Modules.terrainGeneration.terrain)

local mobs = {}
local mobList = {}

local function loadAllMobs()
	
	--> mob directory requires folders > models
	for _, category in mobDirectory:GetChildren() do
		if not category:IsA('Folder') then continue end
		
		for _, mobModel in category:GetChildren() do
			if not mobModel:IsA('Model') then continue end
			
			local mobID = mobModel:GetAttribute('id')
			if not mobID then continue end
			if mobList[mobID] then warn(`conflicting mob id; {mobID} -> {mobModel.Name}`) continue end
			
			mobList[mobID] = {}
			mobList[mobID].model = mobModel
			
		end
	end
	
	for _, mob in script:GetDescendants() do
		if not mob:IsA('ModuleScript') then continue end
		
		local mobModule = require(mob)
		local mobData = mobModule and mobModule.data
		local mobID = mobData and mobData.id
		if not (mobID and mobList[mobID]) then continue end
		
		mobList[mobData.id].scriptObj = mob
		mobList[mobData.id].module = mobModule
		
	end
end

local function getTracksForAnimator(
	rig : Model, 
	mobID : number
)
	
	local scriptObj = mobList[mobID] and mobList[mobID].scriptObj
	if not scriptObj then warn(`no data for mob with id; {mobID}`) return end
	
	local animator = rig:FindFirstChild('Humanoid') 
		and rig.Humanoid:FindFirstChild('Animator') 
		or rig:FindFirstChildOfClass('AnimationController')
	if not animator then warn(`rig {mobID} has no animator/animationcontroller`) return end
	
	local tracks = {}
	
	for _, track in scriptObj:GetDescendants() do
		tracks[track.Name] = animator:LoadAnimation(track)
	end
	
	return tracks
end

--[[
General purpose mob spawn api -> requires id
]]
function mobs.SpawnEntity(
	x : number,
	z : number,
	mobID : number
)
	assert(x and z and mobID, `invalid args for mobs.SpawnEntry; {x}, {z}, {mobID}`)
	
	local mob = mobList[mobID]
	if not mob then warn(`no mob data for id; {mobID}`) return end
	
	local initFunc = mob.module and mob.module.init
	if typeof(initFunc) ~= 'function' then warn(`init function is not a function for {mobID}`) return end
	
	local mobModel = mob.model and mob.model:IsA('Model') and mob.model:Clone()
	local yPos = terrain.getYPos(x,z,64)
	yPos = yPos and yPos + 32
	if not (mobModel and yPos) then warn(`nil mob height/model`) return end
	
	mobModel.HumanoidRootPart.Anchored = true
	
	mobModel:PivotTo(CFrame.new(x,yPos,z))
	mobModel.Parent = mobWorkspaceFolder
	
	local tracks = getTracksForAnimator(mobModel, mobID)
	
	--> pass mob model and tracks to init function to instantiate
	initFunc(mobModel, tracks)
	
	
	return true
end

loadAllMobs()
return mobs
