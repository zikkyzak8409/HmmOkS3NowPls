--!native
--!optimize 2

local replicatedStorage = game:GetService('ReplicatedStorage')

local foliageModule = require(script.Parent.foliage)
local debrisModule = require(script.Parent.groundDebris)
local maths = require(replicatedStorage:WaitForChild('Modules').utils.mathHeavy)

local biomes = {}

local biomeSeed = 999
local biomeRegionScale = 0.001
local sampleCount = 3
local sampleCountPlusOne = sampleCount + 1

local standardScaling = 2

local biomeDefs = {
	{
		name = "Terrible Tundra",
		material = Enum.Material.Snow,
		color = Color3.fromRGB(255, 236, 229),
		foliageClipThreshold = .8,
		selectionWeight = 1.6,
		heightMod = function(x, z)
			return (math.noise(x * 0.02, z * 0.02, 830) * 0.5 + 0.5) * 35 * standardScaling
		end,
	},
	{
		name = "Salty Seabed",
		material = Enum.Material.Salt,
		color = Color3.fromRGB(203, 108, 14),
		foliageClipThreshold = .5,
		selectionWeight = 2,
		heightMod = function(x, z)
			return (math.noise(x * 0.02, z * 0.02, 790) * 0.5 + 0.5) * 5 * standardScaling
		end,
	},
	{
		name = "Flower Forest",
		material = Enum.Material.LeafyGrass,
		color = Color3.fromRGB(9, 50, 0),
		selectionWeight = 3,
		foliageClipThreshold = 0.3,
		heightMod = function(x, z)
			return (math.noise(x * 0.02, z * 0.02, 791) * 0.5 + 0.5) * 16 * standardScaling
		end,
	},
	{
		name = "Mushroom Forest",
		material = Enum.Material.Marble,
		color = Color3.fromRGB(184, 39, 10),
		foliageClipThreshold = .4,
		selectionWeight = 1,
		heightMod = function(x, z)
			return (math.noise(x * 0.02, z * 0.02, 793) * 0.5 + 0.5) * 17 * standardScaling + 45
		end,
	},
	{
		name = "Specific Ocean",
		material = Enum.Material.Sand,
		color = Color3.fromRGB(220, 215, 64),
		foliageClipThreshold = 1,
		selectionWeight = 5,
		heightMod = function(x, z)
			return (math.noise(x * 0.02, z * 0.02, 792) * 0.5 + 0.5) * 0.2 * standardScaling - 120
		end,
	}
}

local aliasBiomeObjects = {}
local totalWeight = 0
for i, biome in biomeDefs do
	totalWeight += biome.selectionWeight
	table.insert(aliasBiomeObjects, {
		weight = biome.selectionWeight,
		itemToReturn = i,
	})
end

local biomeAliasTable = maths.createAliasTableFromObjects(aliasBiomeObjects)

local function getWeightedBiomeIndex(bNoise)
	local scaledNoise = (bNoise + 1) * 0.5 * totalWeight
	local cumulative = 0

	for i, biome in biomeDefs do
		cumulative += biome.selectionWeight
		if scaledNoise <= cumulative then
			return i
		end
	end
	return #biomeDefs
end

local sqrt = math.sqrt
local max = math.max

local function getBlendedBiomeWeights(x, z, size)
	local weights = {}
	local totalWeightLocal = 0

	-- Initialize weights with zeros
	for i = 1, #biomeDefs do
		weights[i] = 0
	end

	for dx = -sampleCount, sampleCount do
		for dz = -sampleCount, sampleCount do
			local offsetX = x + dx * size
			local offsetZ = z + dz * size

			local bx = offsetX * biomeRegionScale
			local bz = offsetZ * biomeRegionScale

			local bNoise = math.noise(bx, bz, biomeSeed)
			local index = getWeightedBiomeIndex(bNoise)

			local dist = sqrt(dx * dx + dz * dz)
			local weight = max(0, 1 - (dist / sampleCountPlusOne))

			weights[index] += weight
			totalWeightLocal += weight
		end
	end

	if totalWeightLocal > 0 then
		for i = 1, #weights do
			weights[i] = weights[i] / totalWeightLocal
		end
	end

	return weights
end


local function blendColor(weights)
	local r, g, b = 0, 0, 0
	for i, weight in weights do
		local color = biomeDefs[i].color
		r += color.R * weight
		g += color.G * weight
		b += color.B * weight
	end
	return Color3.new(r, g, b)
end

local smoothingRadius = 2

local function smoothHeightMod(heightModFunc, x, z)
	local samples = 0
	local sumHeight = 0

	for dx = -smoothingRadius, smoothingRadius do
		for dz = -smoothingRadius, smoothingRadius do
			local dist = sqrt(dx * dx + dz * dz)
			if dist <= smoothingRadius then
				local weight = 1 - (dist / (smoothingRadius + 1))
				sumHeight += heightModFunc(x + dx, z + dz) * weight
				samples += weight
			end
		end
	end

	return sumHeight / samples
end

local function blendHeight(x, z, weights)
	local height = 0
	for i, weight in weights do
		local smoothedHeight = smoothHeightMod(biomeDefs[i].heightMod, x, z)
		height += smoothedHeight * weight
	end
	return height
end

local function getDominantMaterial(weights)
	local maxWeight = -1
	local index = 1
	for i, weight in weights do
		if weight > maxWeight then
			maxWeight = weight
			index = i
		end
	end
	return biomeDefs[index].material
end

function biomes.getYPosWithBiome(x,z,size)
	local weights = getBlendedBiomeWeights(x, z, size)
	local height = blendHeight(x, z, weights)

	--> find the dominant biome index
	local maxWeight = -1
	local dominantIndex = 1
	for i, weight in weights do
		if weight > maxWeight then
			maxWeight = weight
			dominantIndex = i
		end
	end

	local dominantBiomeName = biomeDefs[dominantIndex].name

	return height, dominantBiomeName
end

function biomes.getYPos(x, z, size)
	local weights = getBlendedBiomeWeights(x, z, size)
	return blendHeight(x, z, weights), weights
end

function biomes.texturePartWithYPos(x, z, size, part)
	local height, weights = biomes.getYPos(x, z, size)

	local color = blendColor(weights)
	local material = getDominantMaterial(weights)

	part.Material = material
	part.Color = color
	part.MaterialVariant = ""
	part.Position = Vector3.new(x, height, z)

	--> foliage integration
	local maxWeight = -1
	local dominantIndex = 1
	for i, weight in weights do
		if weight > maxWeight then
			maxWeight = weight
			dominantIndex = i
		end
	end
	local dominantBiome = biomeDefs[dominantIndex]

	--> remove existing foliage and add new foliage based on biome
	foliageModule.setFoliageOfBlock(
		x,
		z,
		biomeSeed,
		dominantBiome.name,
		part,
		dominantBiome.foliageClipThreshold
	)
	
	--> remove existing debris and add new debris based on biome
	debrisModule.setDebrisOfBlock(
		x,
		z,
		biomeSeed,
		dominantBiome.name,
		part,
		dominantBiome.foliageClipThreshold
	)

	return height
end

--[[
helper to detect is position is occupied
]]
function biomes.isOccupied(x,z,size)
	local height, weights = biomes.getYPos(x, z, size)
	
	--> foliage integration
	local maxWeight = -1
	local dominantIndex = 1
	for i, weight in weights do
		if weight > maxWeight then
			maxWeight = weight
			dominantIndex = i
		end
	end
	local dominantBiome = biomeDefs[dominantIndex]

	return foliageModule.isBlocked(
		x,
		z,
		biomeSeed,
		dominantBiome.foliageClipThreshold
	)
end

return biomes
