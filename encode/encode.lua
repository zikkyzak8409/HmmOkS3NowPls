local ser = {}

--[[
Helper
]]
local function valueToBitCount(x : number)
	x = math.abs(x)

	if x == 0 then return 0 end
	local requiredBits = math.floor(math.log(x,2)) + 1
	return requiredBits
end

--[[
Helper
]]
local function getPrefixBuffer(bitCount : number)
	local zeroes = math.floor(bitCount / 4)
	if zeroes == 0 then zeroes = 1 end

	local leftover = bitCount - zeroes * 4
	if leftover < 0 then leftover = 0 end

	local ones = math.ceil(leftover / 2)

	return ones, zeroes
end

--[[
Helper for reading buffer as a string
]]
local function bufToStr(x : buffer) : string
	local str = ""
	local bufLen = buffer.len(x)
	local bufLenBits = bufLen * 8

	for i=1, bufLenBits do
		local bit = buffer.readbits(x, bufLenBits-i, 1)
		str = str .. bit
	end

	return str
end

--[[
Helper;
returns a table of stats for constructing le buffer
]]
local function getBufferStats(
	value : number
) : {[string] : number}

	local payloadBitCount = valueToBitCount(math.abs(value))
	local ones, zeroes = getPrefixBuffer(payloadBitCount)

	--> return a helper table of stats for constructing a value's buffer
	return {
		value = value,
		payloadBitCount = payloadBitCount,
		prefixOnes = ones,
		prefixZeroes = zeroes,
		signBit = value < 0 and 1 or 0,
		totalBitCount = ones + zeroes + 2 + ones*2 + zeroes * 4,
		totalByteCount = math.ceil( (ones + zeroes + 2 + payloadBitCount) / 8)
	}
end

--mains

--[[
Will push first value to msb
(most significant bit)
]]
function ser.intToBuffer(
	value : number
) : buffer

	local bufferStats = getBufferStats(value)
	local workingOffset = (bufferStats.totalByteCount * 8) --> start at msb

	--> declare new buffer with size in bytes
	local smolBuffieWuffie = buffer.create(bufferStats.totalByteCount)

	--> INITIATE PREFIX <--

	for i=1, bufferStats.prefixOnes do --> write 1's
		buffer.writebits(
			smolBuffieWuffie,
			workingOffset,
			1,
			1
		)

		workingOffset -= 1
	end
	workingOffset -= bufferStats.prefixZeroes --> "write" 0's (just skip as 0 by def)

	local truePayloadSize = bufferStats.prefixZeroes * 4 + bufferStats.prefixOnes * 2

	--> write splitter
	workingOffset -= 1
	buffer.writebits(
		smolBuffieWuffie,
		workingOffset,
		1,
		1
	)

	--> write sign bit
	workingOffset -= 1
	buffer.writebits(
		smolBuffieWuffie,
		workingOffset,
		1,
		bufferStats.signBit
	)

	--> write payload
	workingOffset -= truePayloadSize
	buffer.writebits(
		smolBuffieWuffie,
		workingOffset,
		bufferStats.payloadBitCount,
		math.abs(value)
	)

	--> return the buffer
	return smolBuffieWuffie
end

--[[
Will read first value as msb
(most significant bit)
]]
function ser.bufferToInt(

	bigBuffieWuffie : buffer,
	offsetStart : number

) : number

	--> initiation
	local bufferLenBits = buffer.len(bigBuffieWuffie) * 8
	local workingOffset = offsetStart or bufferLenBits-1

	--> read prefix
	local ones, zeroes = 0, 0

	while true do

		--> read bit for prefix
		local bitValue = buffer.readbits(bigBuffieWuffie, workingOffset, 1)
		workingOffset -= 1

		--> check if 1 is splitter
		if bitValue == 1 and zeroes ~= 0 then break end
		if bitValue == 1 then
			ones += 1
		elseif bitValue == 0 then
			zeroes += 1
		end
	end

	--> next bit is sign
	local signBit = buffer.readbits(bigBuffieWuffie, workingOffset, 1)

	--> prefix ones/zeroes to payload length
	local valueLen = zeroes * 4 + ones * 2


	--> read the payload unsigned value
	workingOffset -= valueLen

	local unsignedPayloadValue = buffer.readbits(
		bigBuffieWuffie,
		workingOffset,
		valueLen
	)

	local temporaryWorkingOffset = workingOffset

	--> check if is end of buffer
	while true do
		temporaryWorkingOffset -= 1

		--> end is reached
		if temporaryWorkingOffset < 0 then
			return unsignedPayloadValue * (signBit==1 and -1 or 1), temporaryWorkingOffset
		end

		--> check for anymore 1's (if buffer end isnt reached)
		local bitValue = buffer.readbits(bigBuffieWuffie, temporaryWorkingOffset, 1)
		if bitValue == 1 then
			break
		end
	end

	--> return the value
	return unsignedPayloadValue * (signBit==1 and -1 or 1), workingOffset -1
end

function ser.tableToBuffer(
	intTable : {[any] : number}
) : buffer

	local dataTable = {}
	local cumulativeBitCount = 0

	--> assemble data table

	for _, value in intTable do
		local bufferStats = getBufferStats(value)
		table.insert(dataTable, bufferStats)

		cumulativeBitCount += bufferStats.totalBitCount
	end

	local cumulativeByteCount = math.ceil(cumulativeBitCount / 8)
	local bigBufferBitCount = cumulativeByteCount * 8
	local workingOffset = bigBufferBitCount-1

	--> create buffer
	local bigBuffieWuffie = buffer.create(cumulativeByteCount)

	--> construct buffer values
	for _, data in dataTable do
		local valueBuffer = ser.intToBuffer(data.value) :: buffer

		--> adjust working offset accordingly
		workingOffset -= data.totalBitCount

		--> isolate bits in msb segment (lose the unnecessary lsb)
		local targetBits = buffer.readbits(
			valueBuffer,
			(buffer.len(valueBuffer)*8-1) - data.totalBitCount,
			data.totalBitCount
		)

		--> write bits to big buffer
		buffer.writebits(
			bigBuffieWuffie,
			workingOffset,
			data.totalBitCount,
			targetBits
		)
	end

	print(`full buffer; {bufToStr(bigBuffieWuffie)}`)

	--> process completo
	return bigBuffieWuffie
end

function ser.bufferToTable(

	bigBuffieWuffie : buffer

) : {[number] : number}

	local bufferByteLen = buffer.len(bigBuffieWuffie)
	local bufferBitLen = bufferByteLen * 8
	local workingOffset = bufferBitLen - 1
	local dataTable = {}

	--> read values

	while true do
		local newWorkingOffset = 0

		local value, newWorkingOffset = ser.bufferToInt(
			bigBuffieWuffie,
			workingOffset
		)

		workingOffset = newWorkingOffset
		table.insert(dataTable, value)

		--> end of buffer
		if workingOffset <= 0 then break end
	end

	return dataTable
end

--> (help me pls im die now)

return ser
