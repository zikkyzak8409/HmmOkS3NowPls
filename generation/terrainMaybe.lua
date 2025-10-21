--[[

Note to self: pls refactor later to make better
ts not include col,pos, etc
work harder not smarter

]]

--!optimize 2
--!native
type templateGrid = {[number]: {[number]: BasePart}}

local terrain = workspace:WaitForChild("Terrain")
local biomes = require(script.Parent:WaitForChild("biomes"))

--for cool looks
local noise = math.noise
local abs = math.abs
local clamp = math.clamp
local sqrt = math.sqrt
local floor = math.floor
local newInstance = Instance.new
local vectorNew = Vector3.new
local plastic = Enum.Material.SmoothPlastic

--general noise vars to be changed later
local innerRadius = 10
local outerRadius = 500
local cutoffRadius = outerRadius + 20 + 1
local maxHeight = 64

local function makePart(position: Vector3, size: Vector3): BasePart
	local part = newInstance("Part")
	part.Size = size
	part.Anchored = true
	part.Position = position
	part.Material = plastic
	part.MaterialVariant = 'Baseplate'
	part.Color = Color3.new(0.0941176, 0.67451, 0.0509804)
	part.Parent = terrain
	return part
end


--biom test
local function rockyNoise(x, z)
	local n1 = abs(noise(x * 0.1, z * 0.1))
	local n2 = abs(noise(x * 0.3, z * 0.3))
	local n3 = abs(noise(x * 0.6, z * 0.6))
	local combined = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2)
	return (combined + 0.1) ^ 2.2
end

local module = {}

function module.getYPos(x: number, z: number, scale: number?): number
	--[[
	local height = noise(x*.01,z*0.01,scale) * 25
	return height - scale/2
	]]
	
	return biomes.getYPos(x,z,scale)
end

function module.setPartYPosWithBiome(x: number, z: number, scale: number, part : Instance): number
	
	--[[
	local height = module.getYPos(x, z, scale)
	
	local biomeLeaf = noise(x*.002,z*0.002,scale)*1 --> 0-1 i think
	--local biomeShroom = noise(x*.002,z*0.002,scale)*.7
	
	local blend = .1
	
	if biomeLeaf > .2 then
		part.Material = Enum.Material.Grass
		part.MaterialVariant = 'Leaves'
		part.Color = Color3.new(0.458824, 0.254902, 0.0745098)
	elseif biomeLeaf + blend > .2 then
		part.Material = Enum.Material.Grass
		part.MaterialVariant = ''
		part.Color = Color3.new(0.545098, 0.431373, 0.0901961)
	else
		part.Material = Enum.Material.Grass
		part.MaterialVariant = 'OpenWorldGrass'
		part.Color = Color3.new(0.419608, 0.615686, 0.054902)
	end
	
	part.Position = vectorNew(part.Position.X, height, part.Position.Z)
	]]
	
	local height = biomes.texturePartWithYPos(x, z, scale, part)
	
	return height
end


--[[
function module.getYPos(x : number, z : number, scale : number) : number
	return 1
end
]]

function module.setupGrid(
	length: number, 
	width: number, 
	blockSize: number | Vector3, 
	forceHeight : number?, 
	config : {[string] : any? }
): templateGrid
	local gridTemplate: templateGrid = {}

	--i declare these so i process efficiently (reduce overhead per makepart)
	local vecSize = typeof(blockSize) == "Vector3" and blockSize or vectorNew(blockSize, blockSize, blockSize)
	local scaleX, scaleY, scaleZ = vecSize.X, vecSize.Y, vecSize.Z

	--[[
	didnt need the // 2 since player is not centred on 0,0
	but i kept it for grid noise testing purposes
	(-x vs +x type shii)
	
	i do everything in synchrony because it is a small map
	and doesnt require actors... yet -.-
	]]
	
	local forcedTransparency = config and config.Transparency or 0
	local forcedColour = config and config.Colour or Color3.new(1,1,1)
	local forcedTexture = config and config.Texture or nil
	local canCollide = config and config.CanCollide
	
	local toggle = 0
	
	for xIndex = -width // 2, width // 2 - 1 do
		local col: {[number]: BasePart} = {}
		local worldX = xIndex * scaleX

		for zIndex = -length // 2, length // 2 - 1 do
			local worldZ = zIndex * scaleZ
			local part = makePart(vectorNew(worldX, -50, worldZ), vecSize)
			
			if forcedTexture then
				local newTexture = Instance.new('Texture')
				newTexture.Texture = forcedTexture
				newTexture.Face = Enum.NormalId.Top
				newTexture.Parent = part
			end
			
			if forcedColour then
				part.Color = forcedColour
			end
			
			if forcedTransparency then
				part.Transparency = forcedTransparency
			end
			
			if config and config.CanCollide == false then
				part.CanCollide = canCollide
			end
			
			local yPos = forceHeight or module.setPartYPosWithBiome(worldX, worldZ, scaleY, part)
			
			if forceHeight then
				part.Position = vectorNew(worldX, yPos, worldZ)
			end
			
			col[worldZ] = part
		end

		gridTemplate[worldX] = col
		
		if toggle == 3 then task.wait() end
		toggle = toggle == 3 and 0 or toggle+1
	end

	return gridTemplate
end

--> TODO; reassign this func to the setupgrid bc this is same but with offset
function module.appendToGrid(
	length: number, 
	width: number, 
	blockSize: number | Vector3,
	currentGrid: templateGrid,

	offsetX: number,
	offsetZ: number,

	forceHeight: number?, 
	config: {[string]: any?}
): templateGrid

	local gridTemplate: templateGrid = currentGrid

	local vecSize = typeof(blockSize) == "Vector3" and blockSize or Vector3.new(blockSize, blockSize, blockSize)
	local scaleX, scaleY, scaleZ = vecSize.X, vecSize.Y, vecSize.Z

	local forcedTransparency = config and config.Transparency or 0
	local forcedColour = config and config.Colour or Color3.new(1,1,1)
	local forcedTexture = config and config.Texture or nil
	local canCollide = config and config.CanCollide
	
	local toggle = 0

	for xIndex = -width // 2, width // 2 - 1 do
		local gridX = offsetX + xIndex * scaleX
		local xId = math.floor(gridX / scaleX + 0.5) * scaleX

		local col = gridTemplate[xId] or {}

		for zIndex = -length // 2, length // 2 - 1 do
			local gridZ = offsetZ + zIndex * scaleZ
			local zId = math.floor(gridZ / scaleZ + 0.5) * scaleZ

			if col[zId] then continue end

			local part = makePart(Vector3.new(gridX, -50, gridZ), vecSize)

			if forcedTexture then
				local newTexture = Instance.new("Texture")
				newTexture.Texture = forcedTexture
				newTexture.Face = Enum.NormalId.Top
				newTexture.Parent = part
			end

			part.Color = forcedColour
			part.Transparency = forcedTransparency
			part.CanCollide = canCollide ~= false

			local yPos = forceHeight or module.setPartYPosWithBiome(gridX, gridZ, scaleY, part)
			if forceHeight then
				part.Position = Vector3.new(gridX, yPos, gridZ)
			end

			col[zId] = part
		end

		gridTemplate[xId] = col
		
		if toggle == 3 then task.wait() end
		toggle = toggle == 3 and 0 or toggle+1
	end

	return gridTemplate
end

return module
