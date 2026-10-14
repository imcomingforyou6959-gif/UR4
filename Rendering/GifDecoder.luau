--!native
--!optimize 2

local bit32 = bit32
local bufferWriteu8 = buffer.writeu8
local bufferWriteu32 = buffer.writeu32
local bufferReadu8 = buffer.readu8
local bufferCopy = buffer.copy

export type DecodedFrame = {
	Pixels: buffer,
	Duration: number,
}

export type DecodedGif = {
	Width: number,
	Height: number,
	Frames: {DecodedFrame},
	LoopCount: number?,
}

local GifDecoder = {}

local function fail(message: string): never
	error("GifDecoder: " .. message, 2)
end

local function u8(data: string, position: number): number
	if position > #data then
		fail("unexpected end of data")
	end
	return string.byte(data, position)
end

local function u16(data: string, position: number): number
	return u8(data, position) + u8(data, position + 1) * 256
end

local function skipSubBlocks(data: string, position: number): number
	while true do
		local size = u8(data, position)
		position += 1
		if size == 0 then
			return position
		end
		if position + size > #data then
			fail("truncated sub-block")
		end
		position += size
	end
end

local function readSubBlocks(data: string, position: number): (string, number)
	local chunks = table.create(8)
	local count = 0
	while true do
		local size = u8(data, position)
		position += 1
		if size == 0 then
			return table.concat(chunks), position
		end
		if position + size > #data then
			fail("truncated sub-block")
		end
		count += 1
		chunks[count] = string.sub(data, position, position + size - 1)
		position += size
	end
end

local function readPalette(data: string, position: number, count: number): ({number}, number)
	local packed = table.create(count)
	for index = 0, count - 1 do
		local red = u8(data, position)
		local green = u8(data, position + 1)
		local blue = u8(data, position + 2)
		packed[index] = red + green * 256 + blue * 65536 + 4278190080
		position += 3
	end
	return packed, position
end

local function clearCanvas(canvas: buffer, width: number, height: number, r: number, g: number, b: number, a: number)
	for y = 0, height - 1 do
		local p = y * width * 4
		for _ = 0, width - 1 do
			bufferWriteu8(canvas, p, r)
			bufferWriteu8(canvas, p + 1, g)
			bufferWriteu8(canvas, p + 2, b)
			bufferWriteu8(canvas, p + 3, a)
			p += 4
		end
	end
end

local function copyBuffer(source: buffer): buffer
	local length = buffer.len(source)
	local result = buffer.create(length)
	bufferCopy(result, 0, source, 0, length)
	return result
end

local function saveRect(canvas: buffer, left: number, top: number, width: number, height: number, canvasWidth: number, canvasHeight: number)
	local x0 = math.max(left, 0)
	local y0 = math.max(top, 0)
	local x1 = math.min(left + width, canvasWidth)
	local y1 = math.min(top + height, canvasHeight)
	if x0 >= x1 or y0 >= y1 then
		return nil
	end

	local saved = buffer.create((x1 - x0) * (y1 - y0) * 4)
	local destination = 0
	for y = y0, y1 - 1 do
		local source = (y * canvasWidth + x0) * 4
		local rowBytes = (x1 - x0) * 4
		bufferCopy(saved, destination, canvas, source, rowBytes)
		destination += rowBytes
	end
	return saved, x0, y0, x1, y1
end

local function restoreRect(canvas: buffer, saved: buffer, x0: number, y0: number, x1: number, y1: number, canvasWidth: number)
	local source = 0
	local rowBytes = (x1 - x0) * 4
	for y = y0, y1 - 1 do
		bufferCopy(canvas, (y * canvasWidth + x0) * 4, saved, source, rowBytes)
		source += rowBytes
	end
end

local function clearRect(canvas: buffer, left: number, top: number, width: number, height: number, canvasWidth: number, canvasHeight: number, r: number, g: number, b: number)
	local x0 = math.max(left, 0)
	local y0 = math.max(top, 0)
	local x1 = math.min(left + width, canvasWidth)
	local y1 = math.min(top + height, canvasHeight)
	for y = y0, y1 - 1 do
		local p = (y * canvasWidth + x0) * 4
		for _ = x0, x1 - 1 do
			bufferWriteu8(canvas, p, r)
			bufferWriteu8(canvas, p + 1, g)
			bufferWriteu8(canvas, p + 2, b)
			bufferWriteu8(canvas, p + 3, 0)
			p += 4
		end
	end
end

local function lzwDecode(compressed: string, minimumCodeSize: number, expectedPixels: number): buffer
	if minimumCodeSize < 2 or minimumCodeSize > 8 then
		fail("invalid LZW minimum code size")
	end

	local clearCode = bit32.lshift(1, minimumCodeSize)
	local endCode = clearCode + 1
	local codeSize = minimumCodeSize + 1
	local available = clearCode + 2
	local oldCode = -1
	local first = 0
	local bytePosition = 1
	local bitBuffer = 0
	local bitsInBuffer = 0
	local compressedLength = #compressed
	local prefix = table.create(4096)
	local suffix = table.create(4096)
	local stack = table.create(4096)
	local output = buffer.create(expectedPixels)
	local outputCount = 0
	local sawEnd = false

	local function readCode(): number?
		while bitsInBuffer < codeSize do
			if bytePosition > compressedLength then
				return nil
			end
			bitBuffer = bit32.bor(bitBuffer, bit32.lshift(string.byte(compressed, bytePosition), bitsInBuffer))
			bytePosition += 1
			bitsInBuffer += 8
		end
		local mask = bit32.lshift(1, codeSize) - 1
		local code = bit32.band(bitBuffer, mask)
		bitBuffer = bit32.rshift(bitBuffer, codeSize)
		bitsInBuffer -= codeSize
		return code
	end

	local function emit(value: number)
		if outputCount >= expectedPixels then
			fail("LZW output exceeds frame size")
		end
		bufferWriteu8(output, outputCount, value)
		outputCount += 1
	end

	while true do
		local code = readCode()
		if code == nil then
			break
		elseif code == clearCode then
			codeSize = minimumCodeSize + 1
			available = clearCode + 2
			oldCode = -1
		elseif code == endCode then
			sawEnd = true
			break
		else
			if code >= available then
				if code ~= available or oldCode < 0 then
					fail("invalid LZW code")
				end
			end
			local inCode = code
			local stackCount = 0
			if oldCode < 0 then
				if code >= clearCode then
					fail("invalid first LZW code")
				end
				first = code
				emit(code)
				oldCode = code
			else
				if code == available then
					stackCount += 1
					stack[stackCount] = first
					code = oldCode
				end
				while code >= clearCode do
					if code >= 4096 or suffix[code] == nil then
						fail("invalid LZW dictionary reference")
					end
					stackCount += 1
					if stackCount > 4096 then
						fail("LZW dictionary cycle")
					end
					stack[stackCount] = suffix[code]
					code = prefix[code]
				end
				first = code
				stackCount += 1
				stack[stackCount] = first
				for index = stackCount, 1, -1 do
					emit(stack[index])
				end
				if available < 4096 then
					prefix[available] = oldCode
					suffix[available] = first
					available += 1
					if available == bit32.lshift(1, codeSize) and codeSize < 12 then
						codeSize += 1
					end
				end
				oldCode = inCode
			end
		end
	end

	if not sawEnd then
		fail("missing LZW end code")
	end
	if outputCount ~= expectedPixels then
		fail(string.format("LZW decoded %d pixels, expected %d", outputCount, expectedPixels))
	end
	return output
end

local function compositeIndices(
	canvas: buffer,
	indices: buffer,
	left: number,
	top: number,
	width: number,
	height: number,
	canvasWidth: number,
	canvasHeight: number,
	palette: {number},
	transparentIndex: number?,
	interlaced: boolean
)
	local source = 0
	local x0 = math.max(left, 0)
	local x1 = math.min(left + width, canvasWidth)
	local skipLeft = x0 - left
	local visibleWidth = math.max(x1 - x0, 0)

	local function drawRow(y: number)
		if y < 0 or y >= canvasHeight then
			source += width
			return
		end
		source += skipLeft
		local destination = (y * canvasWidth + x0) * 4
		for _ = 1, visibleWidth do
			local index = bufferReadu8(indices, source)
			source += 1
			if index ~= transparentIndex then
				bufferWriteu32(canvas, destination, palette[index])
			end
			destination += 4
		end
		source += width - skipLeft - visibleWidth
	end

	if not interlaced then
		for y = 0, height - 1 do
			drawRow(top + y)
		end
		return
	end

	local passStarts = {0, 4, 2, 1}
	local passSteps = {8, 8, 4, 2}
	for pass = 1, 4 do
		local y = passStarts[pass]
		while y < height do
			drawRow(top + y)
			y += passSteps[pass]
		end
	end
end

function GifDecoder.decode(data: string): DecodedGif
	assert(typeof(data) == "string", "decode expects GIF bytes as a string")
	if #data < 13 then
		fail("file is too short")
	end
	local signature = string.sub(data, 1, 6)
	if signature ~= "GIF87a" and signature ~= "GIF89a" then
		fail("invalid GIF signature")
	end

	local position = 7
	local canvasWidth = u16(data, position)
	local canvasHeight = u16(data, position + 2)
	position += 4
	if canvasWidth == 0 or canvasHeight == 0 then
		fail("invalid logical screen size")
	end
	if canvasWidth > 1024 or canvasHeight > 1024 then
		fail("logical screen exceeds 1024x1024")
	end

	local packed = u8(data, position)
	local backgroundIndex = u8(data, position + 1)
	position += 3

	local globalPalette: {number}?
	if bit32.band(packed, 0x80) ~= 0 then
		local count = bit32.lshift(2, bit32.band(packed, 0x07))
		globalPalette, position = readPalette(data, position, count)
	end

	local backgroundR, backgroundG, backgroundB = 0, 0, 0
	if globalPalette and globalPalette[backgroundIndex] ~= nil then
		local background = globalPalette[backgroundIndex]
		backgroundR = bit32.band(background, 255)
		backgroundG = bit32.band(bit32.rshift(background, 8), 255)
		backgroundB = bit32.band(bit32.rshift(background, 16), 255)
	end

	local canvas = buffer.create(canvasWidth * canvasHeight * 4)
	clearCanvas(canvas, canvasWidth, canvasHeight, backgroundR, backgroundG, backgroundB, 0)

	local frames: {DecodedFrame} = {}
	local loopCount: number? = nil
	local gceDelay = 0
	local gceTransparent: number? = nil
	local gceDisposal = 0

	while position <= #data do
		local introducer = u8(data, position)
		position += 1
		if introducer == 0x3B then
			break
		elseif introducer == 0x21 then
			local label = u8(data, position)
			position += 1
			if label == 0xF9 then
				local blockSize = u8(data, position)
				position += 1
				if blockSize ~= 4 then
					fail("invalid graphic control extension")
				end
				local gcePacked = u8(data, position)
				gceDelay = u16(data, position + 1) * 0.01
				local transparent = u8(data, position + 3)
				position += 4
				if u8(data, position) ~= 0 then
					fail("invalid graphic control terminator")
				end
				position += 1
				gceTransparent = if bit32.band(gcePacked, 1) ~= 0 then transparent else nil
				gceDisposal = bit32.band(bit32.rshift(gcePacked, 2), 7)
			elseif label == 0xFF then
				local appSize = u8(data, position)
				position += 1
				local appId = string.sub(data, position, position + appSize - 1)
				position += appSize
				local appData: string
				appData, position = readSubBlocks(data, position)
				if appId == "NETSCAPE2.0" and #appData >= 3 and string.byte(appData, 1) == 1 then
					loopCount = string.byte(appData, 2) + string.byte(appData, 3) * 256
				end
			elseif label == 0x01 then
				local blockSize = u8(data, position)
				position += 1
				if position + blockSize > #data then
					fail("truncated plain text extension")
				end
				position += blockSize
				position = skipSubBlocks(data, position)
			else
				position = skipSubBlocks(data, position)
			end
		elseif introducer == 0x2C then
			local left = u16(data, position)
			local top = u16(data, position + 2)
			local width = u16(data, position + 4)
			local height = u16(data, position + 6)
			local imagePacked = u8(data, position + 8)
			position += 9
			if width == 0 or height == 0 then
				fail("invalid image dimensions")
			end

			local palette = globalPalette
			if bit32.band(imagePacked, 0x80) ~= 0 then
				local count = bit32.lshift(2, bit32.band(imagePacked, 0x07))
				palette, position = readPalette(data, position, count)
			end
			if not palette then
				fail("image has no color table")
			end

			local minimumCodeSize = u8(data, position)
			position += 1
			local compressed: string
			compressed, position = readSubBlocks(data, position)
			local indices = lzwDecode(compressed, minimumCodeSize, width * height)

			local saved, savedX0, savedY0, savedX1, savedY1
			if gceDisposal == 3 then
				saved, savedX0, savedY0, savedX1, savedY1 = saveRect(canvas, left, top, width, height, canvasWidth, canvasHeight)
			end

			compositeIndices(canvas, indices, left, top, width, height, canvasWidth, canvasHeight, palette, gceTransparent, bit32.band(imagePacked, 0x40) ~= 0)
			frames[#frames + 1] = {Pixels = copyBuffer(canvas), Duration = gceDelay}

			if gceDisposal == 2 then
				clearRect(canvas, left, top, width, height, canvasWidth, canvasHeight, backgroundR, backgroundG, backgroundB)
			elseif gceDisposal == 3 and saved and savedX0 and savedY0 and savedX1 and savedY1 then
				restoreRect(canvas, saved, savedX0, savedY0, savedX1, savedY1, canvasWidth)
			end

			gceDelay = 0
			gceTransparent = nil
			gceDisposal = 0
		else
			fail(string.format("unknown block introducer 0x%02X", introducer))
		end
	end

	if #frames == 0 then
		fail("GIF contains no frames")
	end
	return {
		Width = canvasWidth,
		Height = canvasHeight,
		Frames = frames,
		LoopCount = loopCount,
	}
end

return GifDecoder
