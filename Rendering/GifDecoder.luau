--!nonstrict

local bufferCreate = buffer.create
local bufferLen    = buffer.len
local bufferCopy   = buffer.copy
local bufferFill   = buffer.fill
local bufferFromString = buffer.fromstring
local bufferReadString = buffer.readstring
local readu8  = buffer.readu8
local readu16 = buffer.readu16
local readu32 = buffer.readu32
local writeu8  = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32

local GifDecoder = {}
GifDecoder.Version = 3

local MAX_CANVAS = 1024
local MAX_FRAME_PIXELS = 16777216
local MAX_TOTAL_FRAMES = 5000

local function fail(msg) error("GifDecoder: " .. msg, 3) end
local function need(len, pos, count)
	if pos < 0 or pos + count > len then fail("unexpected end of data") end
end

local function skipSubBlocks(src, length, position)
	while position < length do
		local size = readu8(src, position)
		position += 1
		if size == 0 then return position end
		position += size
	end
	return length
end

local function readSubBlocks(src, length, position)
	local scan = position
	local total = 0
	while scan < length do
		local size = readu8(src, scan)
		scan += 1
		if size == 0 then break end
		total += math.min(size, length - scan)
		scan += size
	end
	local joined = bufferCreate(math.max(total, 1))
	local write = 0
	scan = position
	while scan < length do
		local size = readu8(src, scan)
		scan += 1
		if size == 0 then break end
		local available = math.min(size, length - scan)
		bufferCopy(joined, write, src, scan, available)
		write += available
		scan += size
	end
	return joined, total, math.min(scan, length)
end

local function clampRect(left, top, w, h, cw, ch)
	return math.max(left, 0), math.max(top, 0), math.min(left + w, cw), math.min(top + h, ch)
end

local function extractRect(canvas, canvasWidth, x0, y0, x1, y1)
	local rowBytes = (x1 - x0) * 4
	local out = bufferCreate(rowBytes * (y1 - y0))
	local write = 0
	for y = y0, y1 - 1 do
		bufferCopy(out, write, canvas, (y * canvasWidth + x0) * 4, rowBytes)
		write += rowBytes
	end
	return out
end

local function restoreRect(canvas, saved, canvasWidth, x0, y0, x1, y1)
	local rowBytes = (x1 - x0) * 4
	local read = 0
	for y = y0, y1 - 1 do
		bufferCopy(canvas, (y * canvasWidth + x0) * 4, saved, read, rowBytes)
		read += rowBytes
	end
end

local function clearRect(canvas, canvasWidth, x0, y0, x1, y1)
	local rowBytes = (x1 - x0) * 4
	for y = y0, y1 - 1 do
		bufferFill(canvas, (y * canvasWidth + x0) * 4, 0, rowBytes)
	end
end

-- ============================================================================
-- GIF
-- ============================================================================

type LzwTables = { prefix: buffer, suffix: buffer, length: buffer, first: buffer }

local pooledTables: LzwTables? = nil
local function getTables(): LzwTables
	local t = pooledTables
	if t then return t end
	t = {
		prefix = bufferCreate(4096 * 2),
		suffix = bufferCreate(4096),
		length = bufferCreate(4096 * 2),
		first  = bufferCreate(4096),
	}
	pooledTables = t
	return t
end

local function readPalette(src, length, position, count)
	need(length, position, count * 3)
	local palette = bufferCreate(256 * 4)
	local write = 0
	for _ = 1, count do
		local red   = readu8(src, position)
		local green = readu8(src, position + 1)
		local blue  = readu8(src, position + 2)
		writeu32(palette, write, red + green * 256 + blue * 65536 + 4278190080)
		position += 3
		write += 4
	end
	return palette, position
end

local function lzwDecode(src, srcLength, minCodeSize, expected, output, tables, padValue)
	if minCodeSize < 2 or minCodeSize > 8 then fail("invalid LZW minimum code size") end
	local prefix, suffix, length, first = tables.prefix, tables.suffix, tables.length, tables.first
	local clearCode = bit32.lshift(1, minCodeSize)
	local endCode = clearCode + 1
	for code = 0, clearCode - 1 do
		writeu8(suffix, code, code)
		writeu8(first, code, code)
		writeu16(length, code * 2, 1)
	end
	local codeSize = minCodeSize + 1
	local sizeLimit = bit32.lshift(1, codeSize)
	local codeMask = sizeLimit - 1
	local available = clearCode + 2
	local oldCode = -1

	local bytePosition, bitBuffer, bitCount, outCount = 0, 0, 0, 0
	while outCount < expected do
		while bitCount < codeSize and bytePosition < srcLength do
			bitBuffer = bit32.bor(bitBuffer, bit32.lshift(readu8(src, bytePosition), bitCount))
			bytePosition += 1
			bitCount += 8
		end
		if bitCount < codeSize then break end
		local code = bit32.band(bitBuffer, codeMask)
		bitBuffer = bit32.rshift(bitBuffer, codeSize)
		bitCount -= codeSize

		if code == clearCode then
			codeSize = minCodeSize + 1
			sizeLimit = bit32.lshift(1, codeSize)
			codeMask = sizeLimit - 1
			available = clearCode + 2
			oldCode = -1
		elseif code == endCode then
			break
		elseif oldCode < 0 then
			if code >= clearCode then break end
			writeu8(output, outCount, code); outCount += 1
			oldCode = code
		else
			local firstPixel, stringLength
			if code < available then
				stringLength = readu16(length, code * 2)
				firstPixel = readu8(first, code)
				local position = outCount + stringLength - 1
				local walk = code
				while true do
					writeu8(output, position, readu8(suffix, walk))
					if readu16(length, walk * 2) == 1 then break end
					walk = readu16(prefix, walk * 2)
					position -= 1
				end
			elseif code == available and available < 4096 then
				firstPixel = readu8(first, oldCode)
				stringLength = readu16(length, oldCode * 2) + 1
				local position = outCount + stringLength - 1
				writeu8(output, position, firstPixel)
				position -= 1
				local walk = oldCode
				while true do
					writeu8(output, position, readu8(suffix, walk))
					if readu16(length, walk * 2) == 1 then break end
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

local function interlacedRow(row, height)
	local pass1 = (height + 7) // 8
	if row < pass1 then return row * 8 end
	row -= pass1
	local pass2 = (height + 3) // 8
	if row < pass2 then return 4 + row * 8 end
	row -= pass2
	local pass3 = (height + 1) // 4
	if row < pass3 then return 2 + row * 4 end
	row -= pass3
	return 1 + row * 2
end

-- Fast path when no transparency: copy whole rows from a prebuilt u32 palette.
local function compositeIndices(canvas, indices, left, top, width, height,
	canvasWidth, canvasHeight, palette, transparentIndex, interlaced)
	local x0 = math.max(left, 0)
	local visibleWidth = math.min(left + width, canvasWidth) - x0
	if visibleWidth <= 0 then return end
	local skipLeft = x0 - left
	local transparent = transparentIndex or -1

	for row = 0, height - 1 do
		local y = top + (if interlaced then interlacedRow(row, height) else row)
		if y >= 0 and y < canvasHeight then
			local source = row * width + skipLeft
			local destination = (y * canvasWidth + x0) * 4
			if transparent < 0 then
				-- write runs of identical palette colors in one go
				local runStart = source
				local runColor = readu32(palette, readu8(indices, source) * 4)
				for i = 1, visibleWidth do
					local nextSource = source + i
					local nextColor = if i == visibleWidth then -1
						else readu32(palette, readu8(indices, nextSource) * 4)
					if nextColor ~= runColor then
						local runLen = i - (runStart - source)
						writeu32(canvas, destination, runColor)
						destination += 4
						source = nextSource
						runStart = source
						runColor = nextColor
					end
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

local function decodeGif(data, options)
	local yieldEvery  = options and options.Yield
	local fullFrames  = options ~= nil and options.FullFrames == true
	local rawDelays   = options ~= nil and options.RawDelays == true

	local length = #data
	if length < 13 then fail("file is too short") end
	local src = bufferFromString(data)

	local signature = bufferReadString(src, 0, 6)
	if signature ~= "GIF87a" and signature ~= "GIF89a" then fail("invalid GIF signature") end

	local canvasWidth  = readu16(src, 6)
	local canvasHeight = readu16(src, 8)
	if canvasWidth == 0 or canvasHeight == 0 then fail("invalid logical screen size") end
	if canvasWidth > MAX_CANVAS or canvasHeight > MAX_CANVAS then
		fail("logical screen exceeds " .. MAX_CANVAS .. "x" .. MAX_CANVAS)
	end

	local screenPacked = readu8(src, 10)
	local position = 13

	local globalPalette = nil
	if bit32.band(screenPacked, 0x80) ~= 0 then
		local count = bit32.lshift(2, bit32.band(screenPacked, 0x07))
		globalPalette, position = readPalette(src, length, position, count)
	end

	local canvas = bufferCreate(canvasWidth * canvasHeight * 4)
	local tables = getTables()
	local indexBuffer = nil

	local frames = {}
	local frameCount = 0
	local totalDuration = 0
	local loopCount = nil
	local gceDelay, gceTransparent, gceDisposal = 0, nil, 0
	local pendingX0, pendingY0, pendingX1, pendingY1 = 0, 0, 0, 0
	local hasPending = false

	while position < length do
		local introducer = readu8(src, position); position += 1
		if introducer == 0x3B then break end
		if introducer == 0x21 then
			need(length, position, 1)
			local label = readu8(src, position); position += 1
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
				local appSize = readu8(src, position); position += 1
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
			local left  = readu16(src, position)
			local top   = readu16(src, position + 2)
			local width = readu16(src, position + 4)
			local height = readu16(src, position + 6)
			local imagePacked = readu8(src, position + 8)
			position += 9
			if width == 0 or height == 0 then fail("invalid image dimensions") end
			local expected = width * height
			if expected > MAX_FRAME_PIXELS then fail("image is too large") end

			local palette = globalPalette
			if bit32.band(imagePacked, 0x80) ~= 0 then
				local count = bit32.lshift(2, bit32.band(imagePacked, 0x07))
				palette, position = readPalette(src, length, position, count)
			end
			if not palette then fail("image has no color table") end

			need(length, position, 1)
			local minCodeSize = readu8(src, position); position += 1
			local compressed, compressedLength
			compressed, compressedLength, position = readSubBlocks(src, length, position)

			local required = expected + 4100
			if not indexBuffer or bufferLen(indexBuffer) < required then
				indexBuffer = bufferCreate(required)
			end
			local indices = indexBuffer
			lzwDecode(compressed, compressedLength, minCodeSize, expected, indices, tables, gceTransparent or 0)

			local x0, y0, x1, y1 = clampRect(left, top, width, height, canvasWidth, canvasHeight)
			local hasRect = x0 < x1 and y0 < y1

			local saved = nil
			if gceDisposal == 3 and hasRect then
				saved = extractRect(canvas, canvasWidth, x0, y0, x1, y1)
			end

			compositeIndices(canvas, indices, left, top, width, height,
				canvasWidth, canvasHeight, palette, gceTransparent,
				bit32.band(imagePacked, 0x40) ~= 0)

			local dx0, dy0, dx1, dy1
			if frameCount == 0 or fullFrames then
				dx0, dy0, dx1, dy1 = 0, 0, canvasWidth, canvasHeight
			else
				local has = false
				if hasRect then dx0, dy0, dx1, dy1 = x0, y0, x1, y1; has = true end
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
				if not has then dx0, dy0, dx1, dy1 = 0, 0, 1, 1 end
			end

			local duration = gceDelay
			if not rawDelays and duration <= 0.01 then duration = 0.1 end
			totalDuration += duration

			frameCount += 1
			if frameCount > MAX_TOTAL_FRAMES then fail("too many frames") end
			frames[frameCount] = {
				Pixels = extractRect(canvas, canvasWidth, dx0, dy0, dx1, dy1),
				X = dx0, Y = dy0,
				Width = dx1 - dx0, Height = dy1 - dy0,
				Duration = duration,
			}

			hasPending = false
			if gceDisposal == 2 and hasRect then
				clearRect(canvas, canvasWidth, x0, y0, x1, y1)
				pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
				hasPending = true
			elseif gceDisposal == 3 and saved then
				restoreRect(canvas, saved, canvasWidth, x0, y0, x1, y1)
				pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
				hasPending = true
			end

			gceDelay, gceTransparent, gceDisposal = 0, nil, 0

			if yieldEvery and yieldEvery > 0 and frameCount % yieldEvery == 0 then
				task.wait()
			end
		else
			if frameCount > 0 then break end
			fail(string.format("unknown block introducer 0x%02X", introducer))
		end
	end

	if frameCount == 0 then fail("GIF contains no frames") end

	return {
		Width = canvasWidth, Height = canvasHeight,
		Frames = frames, LoopCount = loopCount, Duration = totalDuration,
	}
end

-- ============================================================================
-- Inflate (zlib + raw DEFLATE, output into a buffer)
-- ============================================================================

local function inflateRaw(src, bytePos, srcEnd, expected)
	local bitBuf, bitCount = 0, 0
	local function bits(n)
		while bitCount < n do
			if bytePos >= srcEnd then return 0 end
			bitBuf = bitBuf | (readu8(src, bytePos) << bitCount)
			bytePos += 1
			bitCount += 8
		end
		local v = bitBuf & ((1 << n) - 1)
		bitBuf = bitBuf >> n
		bitCount -= n
		return v
	end

	local out = bufferCreate(expected)
	local outPos = 0

	local function buildHuff(lengths, n)
		local count = {}
		for i = 0, 15 do count[i] = 0 end
		for i = 1, n do count[lengths[i]] = count[lengths[i]] + 1 end
		count[0] = 0
		local firstCode, firstSym = {}, {}
		local code, sym = 0, 0
		for len = 1, 15 do
			code = (code + count[len - 1]) << 1
			firstCode[len] = code
			firstSym[len] = sym
			sym = sym + count[len]
		end
		local symbols, idx = {}, 1
		for len = 1, 15 do
			for s = 0, n - 1 do
				if lengths[s + 1] == len then
					symbols[idx] = s; idx += 1
				end
			end
		end
		return { count = count, firstCode = firstCode, firstSym = firstSym, symbols = symbols }
	end

	local function decodeSym(huff)
		local code = 0
		for len = 1, 15 do
			code = (code << 1) | bits(1)
			local cnt = huff.count[len]
			if cnt > 0 and code - huff.firstCode[len] < cnt then
				return huff.symbols[huff.firstSym[len] + code - huff.firstCode[len] + 1]
			end
		end
		return -1
	end

	-- dynamic block code-length order
	local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }
	local LEN_BASE  = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
	local LEN_EXTRA = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
	local DIST_BASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
	local DIST_EXTRA = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}

	local litHuff, distHuff
	local fixedLit, fixedDist

	while outPos < expected do
		local bfinal = bits(1)
		local btype = bits(2)
		if btype == 0 then
			-- stored
			bitBuf, bitCount = 0, 0
			-- skip to byte boundary (already byte-aligned in practice)
			local len = readu8(src, bytePos) | (readu8(src, bytePos + 1) << 8)
			bytePos += 4
			for i = 0, len - 1 do
				if outPos >= expected then break end
				writeu8(out, outPos, readu8(src, bytePos + i))
				outPos += 1
			end
			bytePos += len
		elseif btype == 3 then
			fail("invalid DEFLATE block type")
		else
			if btype == 1 then
				if not fixedLit then
					local litL = {}
					for i = 1, 144 do litL[i] = 8 end
					for i = 145, 256 do litL[i] = 9 end
					for i = 257, 280 do litL[i] = 7 end
					for i = 281, 288 do litL[i] = 8 end
					fixedLit = buildHuff(litL, 288)
					local distL = {}
					for i = 1, 30 do distL[i] = 5 end
					fixedDist = buildHuff(distL, 30)
				end
				litHuff, distHuff = fixedLit, fixedDist
			else
				local hlit  = bits(5) + 257
				local hdist = bits(5) + 1
				local hclen = bits(4) + 4
				local clLengths = {}
				for i = 1, 19 do clLengths[i] = 0 end
				for i = 1, hclen do
					clLengths[CL_ORDER[i] + 1] = bits(3)
				end
				local clHuff = buildHuff(clLengths, 19)
				local lengths = {}
				local total = hlit + hdist
				local i = 1
				while i <= total do
					local sym = decodeSym(clHuff)
					if sym < 0 then fail("bad code length symbol") end
					if sym < 16 then
						lengths[i] = sym; i += 1
					elseif sym == 16 then
						local prev = lengths[i - 1] or 0
						local rep = 3 + bits(2)
						for _ = 1, rep do lengths[i] = prev; i += 1 end
					elseif sym == 17 then
						local rep = 3 + bits(3)
						for _ = 1, rep do lengths[i] = 0; i += 1 end
					else
						local rep = 11 + bits(7)
						for _ = 1, rep do lengths[i] = 0; i += 1 end
					end
				end
				local litL = {}
				for j = 1, hlit do litL[j] = lengths[j] or 0 end
				local distL = {}
				for j = 1, hdist do distL[j] = lengths[hlit + j] or 0 end
				litHuff = buildHuff(litL, hlit)
				distHuff = buildHuff(distL, hdist)
			end

			while true do
				local sym = decodeSym(litHuff)
				if sym < 0 then fail("bad literal symbol") end
				if sym < 256 then
					if outPos >= expected then break end
					writeu8(out, outPos, sym); outPos += 1
				elseif sym == 256 then
					break
				else
					local lenIdx = sym - 256
					local length = LEN_BASE[lenIdx] + bits(LEN_EXTRA[lenIdx])
					local dsym = decodeSym(distHuff)
					if dsym < 0 then fail("bad distance symbol") end
					local dist = DIST_BASE[dsym + 1] + bits(DIST_EXTRA[dsym + 1])
					-- copy `length` bytes from outPos - dist
					local srcPos = outPos - dist
					for k = 0, length - 1 do
						if outPos >= expected then break end
						writeu8(out, outPos, readu8(out, srcPos + k))
						outPos += 1
					end
				end
			end
		end
		if bfinal == 1 then break end
	end

	return out
end

-- zlib: 2-byte header + DEFLATE + 4-byte adler32
local function zlibInflate(src, startPos, srcEnd, expected)
	-- skip zlib header
	local cmf = readu8(src, startPos)
	local flg = readu8(src, startPos + 1)
	if bit32.band(cmf, 0x0F) ~= 8 then fail("unsupported zlib compression") end
	-- (we ignore FDICT)
	local dataStart = startPos + 2
	return inflateRaw(src, dataStart, srcEnd, expected)
end

-- ============================================================================
-- PNG / APNG
-- ============================================================================

local PNG_SIG = "\137PNG\r\n\26\n"

-- returns width, height, bitDepth, colorType, interlace, palette, trns
local function parseIHDR(data, src, pos)
	local length = #data
	need(length, pos, 8)
	local w = readu32(src, pos)
	local h = readu32(src, pos + 4)
	local bitDepth = readu8(src, pos + 8)
	local colorType = readu8(src, pos + 9)
	local interlace = readu8(src, pos + 12)
	return w, h, bitDepth, colorType, interlace
end

local function paeth(a, b, c)
	local p = a + b - c
	local pa = math.abs(p - a)
	local pb = math.abs(p - b)
	local pc = math.abs(p - c)
	if pa <= pb and pa <= pc then return a end
	if pb <= pc then return b end
	return c
end

-- unfilter scanlines in `raw` (already inflated) into RGBA `out`.
-- bpp = bytes per pixel *after* unpacking to 8-bit
local function unfilterToRGBA(raw, width, height, channels, bitDepth, palette, trnsIndex, out)
	local bpp = channels -- for >=8-bit; for sub-8 we still operate on bytes
	local bytesPerPixel = math.max(1, (channels * bitDepth) // 8)
	local rowBytes = (width * channels * bitDepth + 7) // 8
	local prev = bufferCreate(rowBytes)
	local cur  = bufferCreate(rowBytes)

	local trnsR, trnsG, trnsB = -1, -1, -1
	if trnsIndex and palette then
		trnsR = readu8(trnsIndex, 0)
		trnsG = readu8(trnsIndex, 1)
		trnsB = readu8(trnsIndex, 2)
	end

	local pos = 0
	for y = 0, height - 1 do
		local filter = readu8(raw, pos); pos += 1
		bufferCopy(cur, 0, raw, pos, rowBytes)
		pos += rowBytes

		if filter == 1 then
			for i = bytesPerPixel, rowBytes - 1 do
				local v = (readu8(cur, i) + readu8(cur, i - bytesPerPixel)) & 0xFF
				writeu8(cur, i, v)
			end
		elseif filter == 2 then
			for i = 0, rowBytes - 1 do
				local v = (readu8(cur, i) + readu8(prev, i)) & 0xFF
				writeu8(cur, i, v)
			end
		elseif filter == 3 then
			for i = 0, rowBytes - 1 do
				local a = if i >= bytesPerPixel then readu8(cur, i - bytesPerPixel) else 0
				local v = (readu8(cur, i) + ((a + readu8(prev, i)) >> 1)) & 0xFF
				writeu8(cur, i, v)
			end
		elseif filter == 4 then
			for i = 0, rowBytes - 1 do
				local a = if i >= bytesPerPixel then readu8(cur, i - bytesPerPixel) else 0
				local b = readu8(prev, i)
				local c = if i >= bytesPerPixel then readu8(prev, i - bytesPerPixel) else 0
				local v = (readu8(cur, i) + paeth(a, b, c)) & 0xFF
				writeu8(cur, i, v)
			end
		end

		-- decode scanline into RGBA at `out` offset y*width*4
		local outBase = y * width * 4
		if colorType == 3 then
			-- palette
			local maxIdx = (1 << bitDepth) - 1
			for x = 0, width - 1 do
				local idx
				if bitDepth == 8 then
					idx = readu8(cur, x)
				else
					local bitsPerPx = bitDepth
					local byteIdx = (x * bitsPerPx) // 8
					local bitOff = 8 - bitsPerPx - ((x * bitsPerPx) % 8)
					idx = (readu8(cur, byteIdx) >> bitOff) & maxIdx
				end
				-- palette entries are stored as u32 RGBA in `palette`
				local entry = readu32(palette, idx * 4)
				-- we stored as R + G*256 + B*65536 + A*16777216 (little-endian u32)
				local r = entry & 0xFF
				local g = (entry >> 8) & 0xFF
				local b = (entry >> 16) & 0xFF
				local a = (entry >> 24) & 0xFF
				if trnsIndex and idx == readu8(trnsIndex, 0) then a = 0 end -- simple 1-entry transparency
				writeu32(out, outBase + x * 4, r + g * 256 + b * 65536 + a * 16777216)
			end
		elseif colorType == 0 then
			-- grayscale
			for x = 0, width - 1 do
				local v
				if bitDepth == 8 then
					v = readu8(cur, x)
				elseif bitDepth == 16 then
					v = readu8(cur, x * 2)
				else
					local maxIdx = (1 << bitDepth) - 1
					local byteIdx = (x * bitDepth) // 8
					local bitOff = 8 - bitDepth - ((x * bitDepth) % 8)
					local raw8 = (readu8(cur, byteIdx) >> bitOff) & maxIdx
					v = (raw8 * 255) // maxIdx
				end
				local a = 255
				if trnsIndex then
					local gv
					if bitDepth == 8 then gv = readu8(trnsIndex, 0)
					elseif bitDepth == 16 then gv = readu8(trnsIndex, 0)
					else gv = 0 end
					if v == gv then a = 0 end
				end
				writeu32(out, outBase + x * 4, v + v * 256 + v * 65536 + a * 16777216)
			end
		elseif colorType == 2 then
			for x = 0, width - 1 do
				local r, g, b, a
				if bitDepth == 8 then
					r = readu8(cur, x * 3); g = readu8(cur, x * 3 + 1); b = readu8(cur, x * 3 + 2)
				else
					r = readu8(cur, x * 6); g = readu8(cur, x * 6 + 2); b = readu8(cur, x * 6 + 4)
				end
				a = 255
				writeu32(out, outBase + x * 4, r + g * 256 + b * 65536 + a * 16777216)
			end
		elseif colorType == 4 then
			for x = 0, width - 1 do
				local v, a
				if bitDepth == 8 then
					v = readu8(cur, x * 2); a = readu8(cur, x * 2 + 1)
				else
					v = readu8(cur, x * 4); a = readu8(cur, x * 4 + 2)
				end
				writeu32(out, outBase + x * 4, v + v * 256 + v * 65536 + a * 16777216)
			end
		else -- colorType == 6
			for x = 0, width - 1 do
				local r, g, b, a
				if bitDepth == 8 then
					r = readu8(cur, x * 4); g = readu8(cur, x * 4 + 1)
					b = readu8(cur, x * 4 + 2); a = readu8(cur, x * 4 + 3)
				else
					r = readu8(cur, x * 8); g = readu8(cur, x * 8 + 2)
					b = readu8(cur, x * 8 + 4); a = readu8(cur, x * 8 + 6)
				end
				writeu32(out, outBase + x * 4, r + g * 256 + b * 65536 + a * 16777216)
			end
		end

		-- swap prev/cur
		prev, cur = cur, prev
	end
end

local function decodeApng(data, options)
	local yieldEvery = options and options.Yield
	local length = #data
	if length < 8 + 25 then fail("file is too short") end
	local src = bufferFromString(data)
	if bufferReadString(src, 0, 8) ~= PNG_SIG then fail("invalid PNG signature") end

	local pos = 8
	local width, height, bitDepth, colorType, interlace
	local palette = nil
	local trnsData = nil
	local idatChunks = {}        -- { [i] = {start, len} }
	local acTL = nil             -- { numFrames, numPlays }
	local frames = {}            -- parsed frames: { {seq, w,h,x,y,delayNum,delayDen,dispose,blend, dataChunks} }
	local currentFrame = nil
	local frameNum = 0

	-- chunk scanner
	while pos + 8 <= length do
		local clen = readu32(src, pos)
		local ctype = bufferReadString(src, pos + 4, 4)
		local cdataStart = pos + 8
		local cdataEnd = cdataStart + clen
		if cdataEnd + 4 > length then fail("truncated chunk") end

		if ctype == "IHDR" then
			width, height, bitDepth, colorType, interlace = parseIHDR(data, src, cdataStart)
			if interlace ~= 0 then fail("interlaced PNG not supported") end
			if bitDepth ~= 8 and bitDepth ~= 16 and
			   not (colorType == 3 and (bitDepth == 1 or bitDepth == 2 or bitDepth == 4)) and
			   not (colorType == 0 and (bitDepth == 1 or bitDepth == 2 or bitDepth == 4))
			then
				fail("unsupported PNG bit depth/color type combination")
			end
		elseif ctype == "PLTE" then
			local count = clen // 3
			local p = bufferCreate(256 * 4)
			for i = 0, count - 1 do
				local r = readu8(src, cdataStart + i * 3)
				local g = readu8(src, cdataStart + i * 3 + 1)
				local b = readu8(src, cdataStart + i * 3 + 2)
				writeu32(p, i * 4, r + g * 256 + b * 65536 + 4278190080)
			end
			palette = p
		elseif ctype == "tRNS" then
			trnsData = {}
			for i = 0, math.min(clen, 256) - 1 do
				trnsData[i] = readu8(src, cdataStart + i)
			end
			-- also support simple alpha-key for color type 0/2
			if colorType == 0 and clen >= 2 then
				trnsData.keyR = readu16(src, cdataStart)
				trnsData.keyG = trnsData.keyR
				trnsData.keyB = trnsData.keyR
			elseif colorType == 2 and clen >= 6 then
				trnsData.keyR = readu16(src, cdataStart)
				trnsData.keyG = readu16(src, cdataStart + 2)
				trnsData.keyB = readu16(src, cdataStart + 4)
			end
		elseif ctype == "acTL" then
			acTL = { numFrames = readu32(src, cdataStart), numPlays = readu32(src, cdataStart + 4) }
		elseif ctype == "fcTL" then
			local seq  = readu32(src, cdataStart)
			local fw   = readu32(src, cdataStart + 4)
			local fh   = readu32(src, cdataStart + 8)
			local fx   = readu32(src, cdataStart + 12)
			local fy   = readu32(src, cdataStart + 16)
			local dnum = readu16(src, cdataStart + 20)
			local dden = readu16(src, cdataStart + 22)
			local dispose = readu8(src, cdataStart + 24)
			local blend   = readu8(src, cdataStart + 25)
			if not currentFrame then
				-- first fcTL: this describes the first IDAT frame too
				currentFrame = {
					seq = seq, w = fw, h = fh, x = fx, y = fy,
					delayNum = dnum, delayDen = dden,
					dispose = dispose, blend = blend,
					chunks = {}, first = true,
				}
				frames[1] = currentFrame
				frameNum = 1
			else
				-- new frame
				currentFrame = {
					seq = seq, w = fw, h = fh, x = fx, y = fy,
					delayNum = dnum, delayDen = dden,
					dispose = dispose, blend = blend,
					chunks = {},
				}
				frameNum += 1
				frames[frameNum] = currentFrame
			end
		elseif ctype == "IDAT" then
			-- belongs to first frame (or whole image if no acTL)
			if not currentFrame then
				currentFrame = { w = width, h = height, x = 0, y = 0,
					delayNum = 0, delayDen = 100, dispose = 0, blend = 0,
					chunks = {}, first = true }
				frames[1] = currentFrame
				frameNum = 1
			end
			table.insert(currentFrame.chunks, { start = cdataStart, len = clen })
		elseif ctype == "fdAT" then
			if not currentFrame then fail("fdAT before fcTL") end
			table.insert(currentFrame.chunks, { start = cdataStart + 4, len = clen - 4 })
		elseif ctype == "IEND" then
			break
		end

		pos = cdataEnd + 4
	end

	if not width or not height then fail("missing IHDR") end
	if width == 0 or height == 0 or width > MAX_CANVAS or height > MAX_CANVAS then
		fail("invalid canvas size")
	end
	if #frames == 0 then fail("PNG contains no image data") end
	if not palette and colorType == 3 then fail("palette image without PLTE") end

	local isAnim = acTL ~= nil
	-- Build the frame list. Non-animated PNG = 1 frame.
	local decodedFrames = {}
	local totalDuration = 0

	-- Base canvas: transparent
	local canvas = bufferCreate(width * height * 4)

	-- We reuse the same RGBA scratch per frame.
	for idx, f in ipairs(frames) do
		-- Determine channels
		local channels
		if colorType == 0 then channels = 1
		elseif colorType == 2 then channels = 3
		elseif colorType == 3 then channels = 1
		elseif colorType == 4 then channels = 2
		elseif colorType == 6 then channels = 4
		else fail("unsupported color type") end

		-- Concatenate all chunk data
		local totalBytes = 0
		for _, c in ipairs(f.chunks) do totalBytes += c.len end
		local comp = bufferCreate(math.max(totalBytes, 1))
		local w = 0
		for _, c in ipairs(f.chunks) do
			bufferCopy(comp, w, src, c.start, c.len)
			w += c.len
		end

		local rowBytes = (f.w * channels * bitDepth + 7) // 8
		local expected = (rowBytes + 1) * f.h
		local raw = zlibInflate(comp, 0, totalBytes, expected)

		-- Decode frame pixels into a scratch RGBA (full-frame canvas-size)
		local frameRGBA = bufferCreate(f.w * f.h * 4)
		unfilterToRGBA(raw, f.w, f.h, channels, bitDepth, palette,
			trnsData and (colorType == 3 and (trnsData[0] ~= nil and trnsData or nil) or
			((colorType == 0 or colorType == 2) and trnsData or nil)), frameRGBA)

		-- Composite onto canvas (with blend/dispose)
		local saved = nil
		local hasRect = f.w > 0 and f.h > 0
		local x0, y0, x1, y1 = clampRect(f.x, f.y, f.w, f.h, width, height)

		if f.dispose == 3 and hasRect then
			saved = extractRect(canvas, width, x0, y0, x1, y1)
		end

		-- blend: 0 = source (replace), 1 = over
		local blendOp = f.blend or 0
		if blendOp == 0 then
			-- replace (copy non-transparent or all pixels depending on alpha)
			for yy = 0, f.h - 1 do
				local cy = f.y + yy
				if cy >= 0 and cy < height then
					local rowStart = yy * f.w * 4
					for xx = 0, f.w - 1 do
						local cx = f.x + xx
						if cx >= 0 and cx < width then
							local c = readu32(frameRGBA, rowStart + xx * 4)
							local a = (c >> 24) & 0xFF
							-- Overwrite with premultiplied result: canvas alpha blend
							if a == 255 then
								writeu32(canvas, (cy * width + cx) * 4, c)
							elseif a > 0 then
								-- simple over blend
								local dc = readu32(canvas, (cy * width + cx) * 4)
								local cr = c & 0xFF; cg = (c >> 8) & 0xFF; cb = (c >> 16) & 0xFF
								local dr = dc & 0xFF; dg = (dc >> 8) & 0xFF; db = (dc >> 16) & 0xFF
								local da = (dc >> 24) & 0xFF
								local inv = 255 - a
								local or_ = (cr * a + dr * inv) // 255
								local og  = (cg * a + dg * inv) // 255
								local ob  = (cb * a + db * inv) // 255
								local oa  = a + (da * inv) // 255
								writeu32(canvas, (cy * width + cx) * 4,
									or_ + og * 256 + ob * 65536 + oa * 16777216)
							end
						end
					end
				end
			end
		else
			-- blend over
			for yy = 0, f.h - 1 do
				local cy = f.y + yy
				if cy >= 0 and cy < height then
					local rowStart = yy * f.w * 4
					for xx = 0, f.w - 1 do
						local cx = f.x + xx
						if cx >= 0 and cx < width then
							local c = readu32(frameRGBA, rowStart + xx * 4)
							local a = (c >> 24) & 0xFF
							if a == 255 then
								writeu32(canvas, (cy * width + cx) * 4, c)
							elseif a > 0 then
								local dc = readu32(canvas, (cy * width + cx) * 4)
								local cr = c & 0xFF; cg = (c >> 8) & 0xFF; cb = (c >> 16) & 0xFF
								local dr = dc & 0xFF; dg = (dc >> 8) & 0xFF; db = (dc >> 16) & 0xFF
								local da = (dc >> 24) & 0xFF
								local inv = 255 - a
								local or_ = (cr * a + dr * inv) // 255
								local og  = (cg * a + dg * inv) // 255
								local ob  = (cb * a + db * inv) // 255
								local oa  = a + (da * inv) // 255
								writeu32(canvas, (cy * width + cx) * 4,
									or_ + og * 256 + ob * 65536 + oa * 16777216)
							end
						end
					end
				end
			end
		end

		-- delay seconds
		local dnum, dden = f.delayNum or 0, f.delayDen or 100
		if dden == 0 then dden = 100 end
		local duration = dnum / dden
		if duration <= 0 then duration = 0.1 end
		totalDuration += duration

		-- delta rect computation vs previous displayed frame
		local dx0, dy0, dx1, dy1
		if idx == 1 then
			dx0, dy0, dx1, dy1 = 0, 0, width, height
		else
			dx0, dy0, dx1, dy1 = x0, y0, x1, y1
			if not hasRect then dx0, dy0, dx1, dy1 = 0, 0, 1, 1 end
		end

		decodedFrames[idx] = {
			Pixels = extractRect(canvas, width, dx0, dy0, dx1, dy1),
			X = dx0, Y = dy0,
			Width = dx1 - dx0, Height = dy1 - dy0,
			Duration = duration,
		}

		-- dispose op: 0 = none, 1 = background (clear rect), 2 = previous (restore)
		if f.dispose == 1 and hasRect then
			clearRect(canvas, width, x0, y0, x1, y1)
		elseif f.dispose == 2 and saved then
			restoreRect(canvas, saved, width, x0, y0, x1, y1)
		end

		if yieldEvery and yieldEvery > 0 and idx % yieldEvery == 0 then
			task.wait()
		end
	end

	-- Static PNG: return single frame with full delay of 0
	if not isAnim and #decodedFrames >= 1 then
		decodedFrames[1].Duration = 0
	end

	return {
		Width = width, Height = height,
		Frames = decodedFrames,
		LoopCount = acTL and acTL.numPlays or nil,
		Duration = totalDuration,
	}
end

function GifDecoder.detect(data)
	if type(data) ~= "string" or #data < 8 then return "unknown" end
	local sig8 = data:sub(1, 8)
	if sig8 == PNG_SIG then
		-- check for acTL chunk
		if data:find("acTL", 1, true) then return "apng" end
		return "png"
	end
	local sig6 = data:sub(1, 6)
	if sig6 == "GIF87a" or sig6 == "GIF89a" then return "gif" end
	return "unknown"
end

function GifDecoder.decode(data, options)
	assert(typeof(data) == "string", "decode expects bytes as a string")
	local kind = GifDecoder.detect(data)
	if kind == "gif" then
		return decodeGif(data, options)
	elseif kind == "apng" or kind == "png" then
		return decodeApng(data, options)
	else
		fail("unsupported file format")
	end
end

return GifDecoder
