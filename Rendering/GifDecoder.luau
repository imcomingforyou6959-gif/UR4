-- GifDecoder
--
-- GifDecoder.decode(data, options?) -> DecodedGif
--
-- options:
--   Yield      : number?  task.wait() every N decoded frames (keeps big GIFs from freezing the client)
--   FullFrames : boolean? true = every frame is a full-canvas RGBA buffer (old behaviour, uses a lot more memory)
--                         false/nil = frames after the first only store the rectangle that changed
--   RawDelays  : boolean? true = keep 0/10ms delays as is, otherwise they become 100ms like browsers do
--
-- Frame = { Pixels: buffer (RGBA, Width*Height*4), X, Y, Width, Height, Duration }
-- Frame 1 always covers the whole canvas, so playing frames in order on one canvas reproduces the GIF.

local bit32 = bit32
local bufferCreate = buffer.create
local bufferLen = buffer.len
local bufferCopy = buffer.copy
local bufferFill = buffer.fill
local bufferFromString = buffer.fromstring
local bufferReadString = buffer.readstring
local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readu32 = buffer.readu32
local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32

export type DecodedFrame = {
	Pixels: buffer,
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Duration: number,
}

export type DecodedGif = {
	Width: number,
	Height: number,
	Frames: {DecodedFrame},
	LoopCount: number?,
	Duration: number,
}

export type DecodeOptions = {
	Yield: number?,
	FullFrames: boolean?,
	RawDelays: boolean?,
}

local MAX_CANVAS = 1024
local MAX_FRAME_PIXELS = 16777216

local GifDecoder = {}
GifDecoder.Version = 2

local function fail(message: string): never
	error("GifDecoder: " .. message, 3)
end

local function need(length: number, position: number, count: number)
	if position < 0 or position + count > length then
		fail("unexpected end of data")
	end
end

-- walks a chain of sub-blocks, returns the position after the terminator
local function skipSubBlocks(src: buffer, length: number, position: number): number
	while position < length do
		local size = readu8(src, position)
		position += 1
		if size == 0 then
			return position
		end
		position += size
	end
	return length
end

-- joins a chain of sub-blocks into one buffer; tolerates a truncated tail
local function readSubBlocks(src: buffer, length: number, position: number): (buffer, number, number)
	local scan = position
	local total = 0
	while scan < length do
		local size = readu8(src, scan)
		scan += 1
		if size == 0 then
			break
		end
		total += math.min(size, length - scan)
		scan += size
	end

	local joined = bufferCreate(math.max(total, 1))
	local write = 0
	scan = position
	while scan < length do
		local size = readu8(src, scan)
		scan += 1
		if size == 0 then
			break
		end
		local available = math.min(size, length - scan)
		bufferCopy(joined, write, src, scan, available)
		write += available
		scan += size
	end
	return joined, total, math.min(scan, length)
end

-- palette is always 256 RGBA entries so a bad pixel index can never read out of range
local function readPalette(src: buffer, length: number, position: number, count: number): (buffer, number)
	need(length, position, count * 3)
	local palette = bufferCreate(256 * 4)
	local write = 0
	for _ = 1, count do
		local red = readu8(src, position)
		local green = readu8(src, position + 1)
		local blue = readu8(src, position + 2)
		writeu32(palette, write, red + green * 256 + blue * 65536 + 4278190080)
		position += 3
		write += 4
	end
	return palette, position
end

-- clips a rect to the canvas, returns x0, y0, x1, y1 (empty when x0 >= x1 or y0 >= y1)
local function clampRect(left: number, top: number, width: number, height: number, canvasWidth: number, canvasHeight: number)
	return math.max(left, 0), math.max(top, 0), math.min(left + width, canvasWidth), math.min(top + height, canvasHeight)
end

local function extractRect(canvas: buffer, canvasWidth: number, x0: number, y0: number, x1: number, y1: number): buffer
	local rowBytes = (x1 - x0) * 4
	local out = bufferCreate(rowBytes * (y1 - y0))
	local write = 0
	for y = y0, y1 - 1 do
		bufferCopy(out, write, canvas, (y * canvasWidth + x0) * 4, rowBytes)
		write += rowBytes
	end
	return out
end

local function restoreRect(canvas: buffer, saved: buffer, canvasWidth: number, x0: number, y0: number, x1: number, y1: number)
	local rowBytes = (x1 - x0) * 4
	local read = 0
	for y = y0, y1 - 1 do
		bufferCopy(canvas, (y * canvasWidth + x0) * 4, saved, read, rowBytes)
		read += rowBytes
	end
end

local function clearRect(canvas: buffer, canvasWidth: number, x0: number, y0: number, x1: number, y1: number)
	local rowBytes = (x1 - x0) * 4
	for y = y0, y1 - 1 do
		bufferFill(canvas, (y * canvasWidth + x0) * 4, 0, rowBytes)
	end
end

type LzwTables = {
	prefix: buffer,
	suffix: buffer,
	length: buffer,
	first: buffer,
}

-- LZW decoder. Every dictionary entry stores its prefix, last pixel, total length and first pixel,
-- so a code is written straight into the output from the back. No stack, no per-pixel calls.
-- Lenient on purpose: a missing end code, truncated data or bad code ends the frame early and the
-- rest is padded instead of throwing away the whole GIF.
-- `output` needs room for expected + 4100 bytes.
local function lzwDecode(
	src: buffer,
	srcLength: number,
	minimumCodeSize: number,
	expected: number,
	output: buffer,
	tables: LzwTables,
	padValue: number
)
	if minimumCodeSize < 2 or minimumCodeSize > 8 then
		fail("invalid LZW minimum code size")
	end

	local prefix, suffix, length, first = tables.prefix, tables.suffix, tables.length, tables.first

	local clearCode = bit32.lshift(1, minimumCodeSize)
	local endCode = clearCode + 1
	for code = 0, clearCode - 1 do
		writeu8(suffix, code, code)
		writeu8(first, code, code)
		writeu16(length, code * 2, 1)
	end

	local codeSize = minimumCodeSize + 1
	local sizeLimit = bit32.lshift(1, codeSize)
	local codeMask = sizeLimit - 1
	local available = clearCode + 2
	local oldCode = -1

	local bytePosition = 0
	local bitBuffer = 0
	local bitCount = 0
	local outCount = 0

	while outCount < expected do
		while bitCount < codeSize and bytePosition < srcLength do
			bitBuffer = bit32.bor(bitBuffer, bit32.lshift(readu8(src, bytePosition), bitCount))
			bytePosition += 1
			bitCount += 8
		end
		if bitCount < codeSize then
			break
		end
		local code = bit32.band(bitBuffer, codeMask)
		bitBuffer = bit32.rshift(bitBuffer, codeSize)
		bitCount -= codeSize

		if code == clearCode then
			codeSize = minimumCodeSize + 1
			sizeLimit = bit32.lshift(1, codeSize)
			codeMask = sizeLimit - 1
			available = clearCode + 2
			oldCode = -1
		elseif code == endCode then
			break
		elseif oldCode < 0 then
			if code >= clearCode then
				break
			end
			writeu8(output, outCount, code)
			outCount += 1
			oldCode = code
		else
			local firstPixel
			local stringLength
			if code < available then
				stringLength = readu16(length, code * 2)
				firstPixel = readu8(first, code)
				local position = outCount + stringLength - 1
				local walk = code
				while true do
					writeu8(output, position, readu8(suffix, walk))
					if readu16(length, walk * 2) == 1 then
						break
					end
					walk = readu16(prefix, walk * 2)
					position -= 1
				end
			elseif code == available and available < 4096 then
				-- the "KwKwK" case: previous string plus its own first pixel
				firstPixel = readu8(first, oldCode)
				stringLength = readu16(length, oldCode * 2) + 1
				local position = outCount + stringLength - 1
				writeu8(output, position, firstPixel)
				position -= 1
				local walk = oldCode
				while true do
					writeu8(output, position, readu8(suffix, walk))
					if readu16(length, walk * 2) == 1 then
						break
					end
					walk = readu16(prefix, walk * 2)
					position -= 1
				end
			else
				break
			end
			outCount += stringLength

			if available < 4096 then
				writeu16(prefix, available * 2, oldCode)
				writeu8(suffix, available, firstPixel)
				writeu16(length, available * 2, readu16(length, oldCode * 2) + 1)
				writeu8(first, available, readu8(first, oldCode))
				available += 1
				if available == sizeLimit and codeSize < 12 then
					codeSize += 1
					sizeLimit *= 2
					codeMask = sizeLimit - 1
				end
			end
			oldCode = code
		end
	end

	if outCount < expected then
		bufferFill(output, outCount, padValue, expected - outCount)
	end
end

-- maps the nth stored row of an interlaced image to its real row
local function interlacedRow(row: number, height: number): number
	local pass1 = (height + 7) // 8
	if row < pass1 then
		return row * 8
	end
	row -= pass1
	local pass2 = (height + 3) // 8
	if row < pass2 then
		return 4 + row * 8
	end
	row -= pass2
	local pass3 = (height + 1) // 4
	if row < pass3 then
		return 2 + row * 4
	end
	row -= pass3
	return 1 + row * 2
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
	palette: buffer,
	transparentIndex: number?,
	interlaced: boolean
)
	local x0 = math.max(left, 0)
	local visibleWidth = math.min(left + width, canvasWidth) - x0
	if visibleWidth <= 0 then
		return
	end
	local skipLeft = x0 - left
	local transparent = transparentIndex or -1

	for row = 0, height - 1 do
		local y = top + (if interlaced then interlacedRow(row, height) else row)
		if y >= 0 and y < canvasHeight then
			local source = row * width + skipLeft
			local destination = (y * canvasWidth + x0) * 4
			if transparent < 0 then
				for _ = 1, visibleWidth do
					writeu32(canvas, destination, readu32(palette, readu8(indices, source) * 4))
					source += 1
					destination += 4
				end
			else
				for _ = 1, visibleWidth do
					local index = readu8(indices, source)
					if index ~= transparent then
						writeu32(canvas, destination, readu32(palette, index * 4))
					end
					source += 1
					destination += 4
				end
			end
		end
	end
end

function GifDecoder.decode(data: string, options: DecodeOptions?): DecodedGif
	assert(typeof(data) == "string", "decode expects GIF bytes as a string")
	local yieldEvery = options and options.Yield
	local fullFrames = options ~= nil and options.FullFrames == true
	local rawDelays = options ~= nil and options.RawDelays == true

	local length = #data
	if length < 13 then
		fail("file is too short")
	end
	local src = bufferFromString(data)

	local signature = bufferReadString(src, 0, 6)
	if signature ~= "GIF87a" and signature ~= "GIF89a" then
		fail("invalid GIF signature")
	end

	local canvasWidth = readu16(src, 6)
	local canvasHeight = readu16(src, 8)
	if canvasWidth == 0 or canvasHeight == 0 then
		fail("invalid logical screen size")
	end
	if canvasWidth > MAX_CANVAS or canvasHeight > MAX_CANVAS then
		fail("logical screen exceeds " .. MAX_CANVAS .. "x" .. MAX_CANVAS)
	end

	local screenPacked = readu8(src, 10)
	local position = 13

	local globalPalette: buffer? = nil
	if bit32.band(screenPacked, 0x80) ~= 0 then
		local count = bit32.lshift(2, bit32.band(screenPacked, 0x07))
		globalPalette, position = readPalette(src, length, position, count)
	end

	-- a fresh buffer is zero filled = fully transparent, which is what disposal 2 clears to as well
	local canvas = bufferCreate(canvasWidth * canvasHeight * 4)
	local tables: LzwTables = {
		prefix = bufferCreate(4096 * 2),
		suffix = bufferCreate(4096),
		length = bufferCreate(4096 * 2),
		first = bufferCreate(4096),
	}
	local indexBuffer: buffer? = nil

	local frames: {DecodedFrame} = {}
	local frameCount = 0
	local totalDuration = 0
	local loopCount: number? = nil

	local gceDelay = 0
	local gceTransparent: number? = nil
	local gceDisposal = 0

	-- area the previous frame's disposal changed, it has to be part of the next patch
	local pendingX0, pendingY0, pendingX1, pendingY1 = 0, 0, 0, 0
	local hasPending = false

	while position < length do
		local introducer = readu8(src, position)
		position += 1

		if introducer == 0x3B then
			break
		elseif introducer == 0x21 then
			need(length, position, 1)
			local label = readu8(src, position)
			position += 1

			if label == 0xF9 then
				need(length, position, 6)
				if readu8(src, position) == 4 then
					local gcePacked = readu8(src, position + 1)
					gceDelay = readu16(src, position + 2) * 0.01
					if bit32.band(gcePacked, 1) ~= 0 then
						gceTransparent = readu8(src, position + 4)
					else
						gceTransparent = nil
					end
					gceDisposal = bit32.band(bit32.rshift(gcePacked, 2), 7)
				end
				position = skipSubBlocks(src, length, position)
			elseif label == 0xFF then
				need(length, position, 1)
				local appSize = readu8(src, position)
				position += 1
				local idLength = math.min(appSize, length - position)
				local appId = bufferReadString(src, position, idLength)
				position += appSize
				local appData, appSizeUsed
				appData, appSizeUsed, position = readSubBlocks(src, length, position)
				if appId == "NETSCAPE2.0" and appSizeUsed >= 3 and readu8(appData, 0) == 1 then
					loopCount = readu16(appData, 1)
				end
			else
				position = skipSubBlocks(src, length, position)
			end
		elseif introducer == 0x2C then
			need(length, position, 9)
			local left = readu16(src, position)
			local top = readu16(src, position + 2)
			local width = readu16(src, position + 4)
			local height = readu16(src, position + 6)
			local imagePacked = readu8(src, position + 8)
			position += 9
			if width == 0 or height == 0 then
				fail("invalid image dimensions")
			end
			local expected = width * height
			if expected > MAX_FRAME_PIXELS then
				fail("image is too large")
			end

			local palette = globalPalette
			if bit32.band(imagePacked, 0x80) ~= 0 then
				local count = bit32.lshift(2, bit32.band(imagePacked, 0x07))
				palette, position = readPalette(src, length, position, count)
			end
			if not palette then
				fail("image has no color table")
			end

			need(length, position, 1)
			local minimumCodeSize = readu8(src, position)
			position += 1
			local compressed, compressedLength
			compressed, compressedLength, position = readSubBlocks(src, length, position)

			local required = expected + 4100
			if not indexBuffer or bufferLen(indexBuffer) < required then
				indexBuffer = bufferCreate(required)
			end
			local indices = indexBuffer :: buffer
			lzwDecode(compressed, compressedLength, minimumCodeSize, expected, indices, tables, gceTransparent or 0)

			local x0, y0, x1, y1 = clampRect(left, top, width, height, canvasWidth, canvasHeight)
			local hasRect = x0 < x1 and y0 < y1

			local saved: buffer? = nil
			if gceDisposal == 3 and hasRect then
				saved = extractRect(canvas, canvasWidth, x0, y0, x1, y1)
			end

			compositeIndices(
				canvas, indices, left, top, width, height, canvasWidth, canvasHeight,
				palette, gceTransparent, bit32.band(imagePacked, 0x40) ~= 0
			)

			-- work out which part of the canvas differs from what the previous frame showed
			local dx0, dy0, dx1, dy1
			if frameCount == 0 or fullFrames then
				dx0, dy0, dx1, dy1 = 0, 0, canvasWidth, canvasHeight
			else
				local has = false
				if hasRect then
					dx0, dy0, dx1, dy1 = x0, y0, x1, y1
					has = true
				end
				if hasPending then
					if has then
						dx0 = math.min(dx0, pendingX0)
						dy0 = math.min(dy0, pendingY0)
						dx1 = math.max(dx1, pendingX1)
						dy1 = math.max(dy1, pendingY1)
					else
						dx0, dy0, dx1, dy1 = pendingX0, pendingY0, pendingX1, pendingY1
						has = true
					end
				end
				if not has then
					dx0, dy0, dx1, dy1 = 0, 0, 1, 1
				end
			end

			local duration = gceDelay
			if not rawDelays and duration <= 0.01 then
				duration = 0.1
			end
			totalDuration += duration

			frameCount += 1
			frames[frameCount] = {
				Pixels = extractRect(canvas, canvasWidth, dx0, dy0, dx1, dy1),
				X = dx0,
				Y = dy0,
				Width = dx1 - dx0,
				Height = dy1 - dy0,
				Duration = duration,
			}

			hasPending = false
			if gceDisposal == 2 and hasRect then
				clearRect(canvas, canvasWidth, x0, y0, x1, y1)
				pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
				hasPending = true
			elseif gceDisposal == 3 and saved then
				restoreRect(canvas, saved :: buffer, canvasWidth, x0, y0, x1, y1)
				pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
				hasPending = true
			end

			gceDelay = 0
			gceTransparent = nil
			gceDisposal = 0

			if yieldEvery and yieldEvery > 0 and frameCount % yieldEvery == 0 then
				task.wait()
			end
		else
			-- unknown byte: keep whatever decoded fine instead of throwing it all away
			if frameCount > 0 then
				break
			end
			fail(string.format("unknown block introducer 0x%02X", introducer))
		end
	end

	if frameCount == 0 then
		fail("GIF contains no frames")
	end

	return {
		Width = canvasWidth,
		Height = canvasHeight,
		Frames = frames,
		LoopCount = loopCount,
		Duration = totalDuration,
	}
end

return GifDecoder
