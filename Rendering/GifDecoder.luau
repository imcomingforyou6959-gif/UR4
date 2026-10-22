--!native
--!optimize 2
-- Decoder v9

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

local bor    = bit32.bor
local band   = bit32.band
local lshift = bit32.lshift
local rshift = bit32.rshift

local function readu16BE(src, pos)
    return readu8(src, pos) * 256 + readu8(src, pos + 1)
end
local function readu32BE(src, pos)
    return readu8(src, pos) * 16777216
         + readu8(src, pos + 1) * 65536
         + readu8(src, pos + 2) * 256
         + readu8(src, pos + 3)
end

local GifDecoder = {}
GifDecoder.Version = 9

local MAX_CANVAS = 8192
local MAX_FRAME_PIXELS = 67108864          -- 8192 * 8192
local MAX_TOTAL_FRAMES = 5000
local DEFAULT_MAX_BYTES = 512 * 1024 * 1024 -- total RGBA kept across all frames
local YIELD_BYTES = 262144                  -- inflate yields every this many output bytes
local YIELD_PIXELS = 65536                  -- LZW yields every this many output pixels

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

local pooledTables = nil
local function getTables()
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

local function readPaletteGif(src, length, position, count)
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

local function lzwDecode(src, srcLength, minCodeSize, expected, output, tables, padValue, canYield)
    if minCodeSize < 2 or minCodeSize > 8 then fail("invalid LZW minimum code size") end
    local prefix, suffix, length, first = tables.prefix, tables.suffix, tables.length, tables.first
    local clearCode = lshift(1, minCodeSize)
    local endCode = clearCode + 1
    for code = 0, clearCode - 1 do
        writeu8(suffix, code, code)
        writeu8(first, code, code)
        writeu16(length, code * 2, 1)
    end
    local codeSize = minCodeSize + 1
    local sizeLimit = lshift(1, codeSize)
    local codeMask = sizeLimit - 1
    local available = clearCode + 2
    local oldCode = -1

    local bytePosition, bitBuffer, bitCount, outCount = 0, 0, 0, 0
    local nextYield = YIELD_PIXELS

    while outCount < expected do
        while bitCount < codeSize and bytePosition < srcLength do
            bitBuffer = bor(bitBuffer, lshift(readu8(src, bytePosition), bitCount))
            bytePosition += 1
            bitCount += 8
        end
        if bitCount < codeSize then break end
        local code = band(bitBuffer, codeMask)
        bitBuffer = rshift(bitBuffer, codeSize)
        bitCount -= codeSize

        if code == clearCode then
            codeSize = minCodeSize + 1
            sizeLimit = lshift(1, codeSize)
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

        if canYield and outCount >= nextYield then
            nextYield = outCount + YIELD_PIXELS
            task.wait()
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

local function decodeGif(data, options)
    local yieldEvery  = options and options.Yield
    local canYield    = yieldEvery ~= nil and yieldEvery > 0
    local fullFrames  = options ~= nil and options.FullFrames == true
    local rawDelays   = options ~= nil and options.RawDelays == true
    local maxBytes    = options and options.MaxBytes or DEFAULT_MAX_BYTES

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
    if band(screenPacked, 0x80) ~= 0 then
        local count = lshift(2, band(screenPacked, 0x07))
        globalPalette, position = readPaletteGif(src, length, position, count)
    end

    local canvas = bufferCreate(canvasWidth * canvasHeight * 4)
    local tables = getTables()
    local indexBuffer = nil

    local frames = {}
    local frameCount = 0
    local totalDuration = 0
    local usedBytes = 0
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
                    if band(gcePacked, 1) ~= 0 then
                        gceTransparent = readu8(src, position + 4)
                    else
                        gceTransparent = nil
                    end
                    gceDisposal = band(rshift(gcePacked, 2), 7)
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
            if band(imagePacked, 0x80) ~= 0 then
                local count = lshift(2, band(imagePacked, 0x07))
                palette, position = readPaletteGif(src, length, position, count)
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
            lzwDecode(compressed, compressedLength, minCodeSize, expected, indices, tables,
                gceTransparent or 0, canYield)

            local x0, y0, x1, y1 = clampRect(left, top, width, height, canvasWidth, canvasHeight)
            local hasRect = x0 < x1 and y0 < y1

            local saved = nil
            if gceDisposal == 3 and hasRect then
                saved = extractRect(canvas, canvasWidth, x0, y0, x1, y1)
            end

            compositeIndices(canvas, indices, left, top, width, height,
                canvasWidth, canvasHeight, palette, gceTransparent,
                band(imagePacked, 0x40) ~= 0)

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
            usedBytes += (dx1 - dx0) * (dy1 - dy0) * 4
            if usedBytes > maxBytes then
                fail("GIF needs more than " .. (maxBytes // 1048576) .. " MB of frame memory")
            end
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

            if canYield and yieldEvery > 1 and frameCount % yieldEvery == 0 then
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

local LEN_BASE  = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LEN_EXTRA = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DIST_BASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DIST_EXTRA = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function reverseBits(code, len)
    local r = 0
    for _ = 1, len do
        r = bor(lshift(r, 1), band(code, 1))
        code = rshift(code, 1)
    end
    return r
end

local function buildTable(lengths, n)
    local count = {}
    for i = 0, 15 do count[i] = 0 end
    local maxLen = 1
    for i = 1, n do
        local l = lengths[i]
        count[l] += 1
        if l > maxLen then maxLen = l end
    end
    count[0] = 0

    local nextCode = {}
    local code = 0
    for len = 1, 15 do
        code = lshift(code + count[len - 1], 1)
        nextCode[len] = code
    end

    local size = lshift(1, maxLen)
    local tbl = bufferCreate(size * 4)
    for sym = 0, n - 1 do
        local len = lengths[sym + 1]
        if len > 0 then
            local c = nextCode[len]
            nextCode[len] = c + 1
            local rev = reverseBits(c, len)
            local entry = len * 65536 + sym
            local step = lshift(1, len)
            for idx = rev, size - 1, step do
                writeu32(tbl, idx * 4, entry)
            end
        end
    end
    return tbl, size - 1
end

local fixedLit, fixedLitMask, fixedDist, fixedDistMask

local function inflateRaw(src, startPos, srcEnd, expected, canYield)
    local bitBuf, bitCount, bytePos = 0, 0, startPos
    local out = bufferCreate(expected)
    local outPos = 0
    local nextYield = YIELD_BYTES

    local function bits(n)
        if n == 0 then return 0 end
        while bitCount <= 24 and bytePos < srcEnd do
            bitBuf = bor(bitBuf, lshift(readu8(src, bytePos), bitCount))
            bytePos += 1
            bitCount += 8
        end
        if bitCount < n then fail("truncated DEFLATE stream") end
        local v = band(bitBuf, lshift(1, n) - 1)
        bitBuf = rshift(bitBuf, n)
        bitCount -= n
        return v
    end

    local function decode(tbl, mask)
        while bitCount <= 24 and bytePos < srcEnd do
            bitBuf = bor(bitBuf, lshift(readu8(src, bytePos), bitCount))
            bytePos += 1
            bitCount += 8
        end
        local entry = readu32(tbl, band(bitBuf, mask) * 4)
        if entry == 0 then fail("invalid Huffman code") end
        local len = rshift(entry, 16)
        if len > bitCount then fail("truncated DEFLATE stream") end
        bitBuf = rshift(bitBuf, len)
        bitCount -= len
        return band(entry, 0xFFFF)
    end

    while outPos < expected do
        local bfinal = bits(1)
        local btype = bits(2)

        if btype == 0 then
            local drop = bitCount % 8
            bitBuf = rshift(bitBuf, drop)
            bitCount -= drop
            bytePos -= bitCount // 8
            bitBuf, bitCount = 0, 0
            if bytePos + 4 > srcEnd then fail("truncated DEFLATE stream") end
            local len = readu8(src, bytePos) + readu8(src, bytePos + 1) * 256
            bytePos += 4
            if bytePos + len > srcEnd then fail("truncated DEFLATE stream") end
            local n = math.min(len, expected - outPos)
            if n > 0 then
                bufferCopy(out, outPos, src, bytePos, n)
                outPos += n
            end
            bytePos += len
        elseif btype == 3 then
            fail("invalid DEFLATE block type")
        else
            local litTbl, litMask, distTbl, distMask
            if btype == 1 then
                if not fixedLit then
                    local litL = {}
                    for i = 1, 144 do litL[i] = 8 end
                    for i = 145, 256 do litL[i] = 9 end
                    for i = 257, 280 do litL[i] = 7 end
                    for i = 281, 288 do litL[i] = 8 end
                    fixedLit, fixedLitMask = buildTable(litL, 288)
                    local distL = {}
                    for i = 1, 30 do distL[i] = 5 end
                    fixedDist, fixedDistMask = buildTable(distL, 30)
                end
                litTbl, litMask, distTbl, distMask = fixedLit, fixedLitMask, fixedDist, fixedDistMask
            else
                local hlit  = bits(5) + 257
                local hdist = bits(5) + 1
                local hclen = bits(4) + 4
                local clLengths = {}
                for i = 1, 19 do clLengths[i] = 0 end
                for i = 1, hclen do
                    clLengths[CL_ORDER[i] + 1] = bits(3)
                end
                local clTbl, clMask = buildTable(clLengths, 19)

                local lengths = {}
                local total = hlit + hdist
                local i = 1
                while i <= total do
                    local sym = decode(clTbl, clMask)
                    if sym < 16 then
                        lengths[i] = sym; i += 1
                    elseif sym == 16 then
                        if i == 1 then fail("bad code length repeat") end
                        local prev = lengths[i - 1]
                        for _ = 1, 3 + bits(2) do
                            if i > total then break end
                            lengths[i] = prev; i += 1
                        end
                    elseif sym == 17 then
                        for _ = 1, 3 + bits(3) do
                            if i > total then break end
                            lengths[i] = 0; i += 1
                        end
                    else
                        for _ = 1, 11 + bits(7) do
                            if i > total then break end
                            lengths[i] = 0; i += 1
                        end
                    end
                end
                local litL = {}
                for j = 1, hlit do litL[j] = lengths[j] end
                local distL = {}
                for j = 1, hdist do distL[j] = lengths[hlit + j] end
                litTbl, litMask = buildTable(litL, hlit)
                distTbl, distMask = buildTable(distL, hdist)
            end

            while true do
                local sym = decode(litTbl, litMask)
                if sym < 256 then
                    if outPos >= expected then break end
                    writeu8(out, outPos, sym)
                    outPos += 1
                elseif sym == 256 then
                    break
                else
                    local li = sym - 256
                    if li > 29 then fail("bad length symbol") end
                    local length = LEN_BASE[li] + bits(LEN_EXTRA[li])
                    local ds = decode(distTbl, distMask)
                    if ds > 29 then fail("bad distance symbol") end
                    local dist = DIST_BASE[ds + 1] + bits(DIST_EXTRA[ds + 1])
                    if dist > outPos then fail("invalid DEFLATE distance") end
                    if outPos + length > expected then length = expected - outPos end
                    if length > 0 then
                        if dist == 1 then
                            bufferFill(out, outPos, readu8(out, outPos - 1), length)
                        elseif dist >= length then
                            bufferCopy(out, outPos, out, outPos - dist, length)
                        else
                            local from = outPos - dist
                            for k = 0, length - 1 do
                                writeu8(out, outPos + k, readu8(out, from + k))
                            end
                        end
                        outPos += length
                    end
                end
                if canYield and outPos >= nextYield then
                    nextYield = outPos + YIELD_BYTES
                    task.wait()
                end
            end
        end

        if bfinal == 1 then break end
    end

    return out
end

local function zlibInflate(src, startPos, srcEnd, expected, canYield)
    if srcEnd - startPos < 2 then fail("truncated zlib stream") end
    local cmf = readu8(src, startPos)
    local flg = readu8(src, startPos + 1)
    if band(cmf, 0x0F) ~= 8 then fail("unsupported zlib compression method") end
    if band(flg, 0x20) ~= 0 then fail("zlib preset dictionary not supported") end
    return inflateRaw(src, startPos + 2, srcEnd, expected, canYield)
end

local PNG_SIG = "\137PNG\r\n\26\n"

local function pixelAt(cur, x, bitDepth)
    if bitDepth == 8 then
        return readu8(cur, x)
    end
    local byteIdx = (x * bitDepth) // 8
    local bitOff = 8 - bitDepth - ((x * bitDepth) % 8)
    return band(rshift(readu8(cur, byteIdx), bitOff), lshift(1, bitDepth) - 1)
end

local function unfilterToRGBA(raw, width, height, channels, bitDepth, colorType,
    palette, colorKey, out, canYield)

    local bpp = math.max(1, (channels * bitDepth) // 8)
    local rowBytes = (width * channels * bitDepth + 7) // 8
    local prev = bufferCreate(rowBytes)
    local cur  = bufferCreate(rowBytes)

    local pos = 0
    for y = 0, height - 1 do
        local filter = readu8(raw, pos); pos += 1
        bufferCopy(cur, 0, raw, pos, rowBytes)
        pos += rowBytes

        if filter == 1 then
            for i = bpp, rowBytes - 1 do
                writeu8(cur, i, band(readu8(cur, i) + readu8(cur, i - bpp), 0xFF))
            end
        elseif filter == 2 then
            for i = 0, rowBytes - 1 do
                writeu8(cur, i, band(readu8(cur, i) + readu8(prev, i), 0xFF))
            end
        elseif filter == 3 then
            for i = 0, rowBytes - 1 do
                local a = if i >= bpp then readu8(cur, i - bpp) else 0
                writeu8(cur, i, band(readu8(cur, i) + rshift(a + readu8(prev, i), 1), 0xFF))
            end
        elseif filter == 4 then
            for i = 0, rowBytes - 1 do
                local a, c = 0, 0
                if i >= bpp then
                    a = readu8(cur, i - bpp)
                    c = readu8(prev, i - bpp)
                end
                local b = readu8(prev, i)
                local pa = math.abs(b - c)
                local pb = math.abs(a - c)
                local pc = math.abs(a + b - 2 * c)
                local predictor
                if pa <= pb and pa <= pc then predictor = a
                elseif pb <= pc then predictor = b
                else predictor = c end
                writeu8(cur, i, band(readu8(cur, i) + predictor, 0xFF))
            end
        elseif filter ~= 0 then
            fail("invalid PNG filter type")
        end

        local outBase = y * width * 4

        if colorType == 6 and bitDepth == 8 then
            bufferCopy(out, outBase, cur, 0, rowBytes)

        elseif colorType == 3 then
            for x = 0, width - 1 do
                local idx = pixelAt(cur, x, bitDepth)
                writeu32(out, outBase + x * 4, readu32(palette, idx * 4))
            end

        elseif colorType == 0 then
            local maxIdx = lshift(1, bitDepth) - 1
            local scale = if maxIdx > 0 then 255 // maxIdx else 0
            for x = 0, width - 1 do
                local v
                if bitDepth == 16 then
                    v = readu8(cur, x * 2)
                elseif bitDepth == 8 then
                    v = readu8(cur, x)
                else
                    v = pixelAt(cur, x, bitDepth) * scale
                end
                local a = 255
                if colorKey and v == colorKey.r then a = 0 end
                writeu32(out, outBase + x * 4, v + v * 256 + v * 65536 + a * 16777216)
            end

        elseif colorType == 2 then
            for x = 0, width - 1 do
                local r, g, b
                if bitDepth == 16 then
                    r = readu8(cur, x * 6)
                    g = readu8(cur, x * 6 + 2)
                    b = readu8(cur, x * 6 + 4)
                else
                    r = readu8(cur, x * 3)
                    g = readu8(cur, x * 3 + 1)
                    b = readu8(cur, x * 3 + 2)
                end
                local a = 255
                if colorKey and r == colorKey.r and g == colorKey.g and b == colorKey.b then a = 0 end
                writeu32(out, outBase + x * 4, r + g * 256 + b * 65536 + a * 16777216)
            end

        elseif colorType == 4 then
            for x = 0, width - 1 do
                local v, a
                if bitDepth == 16 then
                    v = readu8(cur, x * 4)
                    a = readu8(cur, x * 4 + 2)
                else
                    v = readu8(cur, x * 2)
                    a = readu8(cur, x * 2 + 1)
                end
                writeu32(out, outBase + x * 4, v + v * 256 + v * 65536 + a * 16777216)
            end

        else
            for x = 0, width - 1 do
                writeu32(out, outBase + x * 4,
                    readu8(cur, x * 8)
                    + readu8(cur, x * 8 + 2) * 256
                    + readu8(cur, x * 8 + 4) * 65536
                    + readu8(cur, x * 8 + 6) * 16777216)
            end
        end

        prev, cur = cur, prev

        if canYield and y % 64 == 63 then task.wait() end
    end
end

local function channelsFor(ct)
    if ct == 0 then return 1 end
    if ct == 2 then return 3 end
    if ct == 3 then return 1 end
    if ct == 4 then return 2 end
    return 4
end

local function validPngFormat(colorType, bitDepth)
    if colorType == 0 then
        return bitDepth == 1 or bitDepth == 2 or bitDepth == 4 or bitDepth == 8 or bitDepth == 16
    elseif colorType == 3 then
        return bitDepth == 1 or bitDepth == 2 or bitDepth == 4 or bitDepth == 8
    elseif colorType == 2 or colorType == 4 or colorType == 6 then
        return bitDepth == 8 or bitDepth == 16
    end
    return false
end

local function decodePng(data, options)
    local yieldEvery = options and options.Yield
    local canYield = yieldEvery ~= nil and yieldEvery > 0
    local maxBytes = options and options.MaxBytes or DEFAULT_MAX_BYTES

    local length = #data
    if length < 8 + 25 then fail("file is too short") end
    local src = bufferFromString(data)
    if bufferReadString(src, 0, 8) ~= PNG_SIG then fail("invalid PNG signature") end

    local pos = 8
    local width, height, bitDepth, colorType, interlace
    local palette = nil
    local colorKey = nil
    local acTL = nil
    local frames = {}
    local currentFrame = nil
    local frameNum = 0

    while pos + 8 <= length do
        local clen = readu32BE(src, pos)
        local ctype = bufferReadString(src, pos + 4, 4)
        local cdataStart = pos + 8
        local cdataEnd = cdataStart + clen
        if cdataEnd + 4 > length then fail("truncated chunk") end

        if ctype == "IHDR" then
            width     = readu32BE(src, cdataStart)
            height    = readu32BE(src, cdataStart + 4)
            bitDepth  = readu8(src, cdataStart + 8)
            colorType = readu8(src, cdataStart + 9)
            interlace = readu8(src, cdataStart + 12)
            if interlace ~= 0 then fail("interlaced PNG not supported") end
            if not validPngFormat(colorType, bitDepth) then
                fail("unsupported PNG bit depth / color type")
            end

        elseif ctype == "PLTE" then
            local count = math.min(clen // 3, 256)
            local p = bufferCreate(256 * 4)
            for i = 0, count - 1 do
                local r = readu8(src, cdataStart + i * 3)
                local g = readu8(src, cdataStart + i * 3 + 1)
                local b = readu8(src, cdataStart + i * 3 + 2)
                writeu32(p, i * 4, r + g * 256 + b * 65536 + 4278190080)
            end
            palette = p

        elseif ctype == "tRNS" then
            if colorType == 3 and palette then
                local n = math.min(clen, 256)
                for i = 0, n - 1 do
                    writeu8(palette, i * 4 + 3, readu8(src, cdataStart + i))
                end
            elseif colorType == 0 and clen >= 2 then
                local key = readu16BE(src, cdataStart)
                local maxIdx = lshift(1, bitDepth) - 1
                local scaled = (key * 255) // maxIdx
                colorKey = { r = scaled, g = scaled, b = scaled }
            elseif colorType == 2 and clen >= 6 then
                local maxIdx = lshift(1, bitDepth) - 1
                colorKey = {
                    r = (readu16BE(src, cdataStart) * 255) // maxIdx,
                    g = (readu16BE(src, cdataStart + 2) * 255) // maxIdx,
                    b = (readu16BE(src, cdataStart + 4) * 255) // maxIdx,
                }
            end

        elseif ctype == "acTL" then
            acTL = {
                numFrames = readu32BE(src, cdataStart),
                numPlays  = readu32BE(src, cdataStart + 4),
            }

        elseif ctype == "fcTL" then
            if currentFrame and currentFrame.fromIDAT and currentFrame.w == nil then
                frames[frameNum] = nil
                frameNum -= 1
            end
            currentFrame = {
                w = readu32BE(src, cdataStart + 4),
                h = readu32BE(src, cdataStart + 8),
                x = readu32BE(src, cdataStart + 12),
                y = readu32BE(src, cdataStart + 16),
                delayNum = readu16BE(src, cdataStart + 20),
                delayDen = readu16BE(src, cdataStart + 22),
                dispose = readu8(src, cdataStart + 24),
                blend   = readu8(src, cdataStart + 25),
                chunks = {},
                fromIDAT = false,
            }
            frameNum += 1
            frames[frameNum] = currentFrame

        elseif ctype == "IDAT" then
            if not currentFrame then
                currentFrame = {
                    w = nil, h = nil, x = 0, y = 0,
                    delayNum = 0, delayDen = 100, dispose = 0, blend = 0,
                    chunks = {},
                    fromIDAT = true,
                }
                frameNum += 1
                frames[frameNum] = currentFrame
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
    if colorType == 3 and not palette then fail("palette image without PLTE") end
    if #frames > MAX_TOTAL_FRAMES then fail("too many frames") end

    for _, f in ipairs(frames) do
        if f.w == nil then
            f.w = width
            f.h = height
            f.x = 0
            f.y = 0
        end
        if f.w == 0 or f.h == 0 or f.w * f.h > MAX_FRAME_PIXELS then
            fail("invalid frame size")
        end
    end

    local isAnim = acTL ~= nil
    local channels = channelsFor(colorType)

    local decodedFrames = {}
    local totalDuration = 0
    local usedBytes = 0
    local canvas = bufferCreate(width * height * 4)

    local pendingX0, pendingY0, pendingX1, pendingY1 = 0, 0, 0, 0
    local hasPending = false

    for idx, f in ipairs(frames) do
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
        local raw = zlibInflate(comp, 0, totalBytes, expected, canYield)

        local frameRGBA = bufferCreate(f.w * f.h * 4)
        unfilterToRGBA(raw, f.w, f.h, channels, bitDepth, colorType,
            palette, colorKey, frameRGBA, canYield)

        local x0, y0, x1, y1 = clampRect(f.x, f.y, f.w, f.h, width, height)
        local hasRect = x0 < x1 and y0 < y1

        local saved = nil
        if f.dispose == 2 and hasRect then
            saved = extractRect(canvas, width, x0, y0, x1, y1)
        end

        if hasRect then
            local replace = (f.blend == 0)
            local dx = x0 - f.x
            local dy = y0 - f.y
            for yy = 0, (y1 - y0) - 1 do
                local srcRow = ((yy + dy) * f.w + dx) * 4
                local dstRow = ((yy + y0) * width + x0) * 4
                if replace then
                    bufferCopy(canvas, dstRow, frameRGBA, srcRow, (x1 - x0) * 4)
                else
                    for xx = 0, (x1 - x0) - 1 do
                        local c = readu32(frameRGBA, srcRow + xx * 4)
                        local a = rshift(c, 24)
                        local dstOff = dstRow + xx * 4
                        if a == 255 then
                            writeu32(canvas, dstOff, c)
                        elseif a > 0 then
                            local dc = readu32(canvas, dstOff)
                            local cr = band(c, 0xFF)
                            local cg = band(rshift(c, 8), 0xFF)
                            local cb = band(rshift(c, 16), 0xFF)
                            local dr = band(dc, 0xFF)
                            local dg = band(rshift(dc, 8), 0xFF)
                            local db = band(rshift(dc, 16), 0xFF)
                            local da = rshift(dc, 24)
                            local inv = 255 - a
                            local orr = (cr * a + dr * inv) // 255
                            local ogg = (cg * a + dg * inv) // 255
                            local obb = (cb * a + db * inv) // 255
                            local oaa = a + (da * inv) // 255
                            writeu32(canvas, dstOff,
                                orr + ogg * 256 + obb * 65536 + oaa * 16777216)
                        end
                    end
                end
            end
        end

        local dnum, dden = f.delayNum or 0, f.delayDen or 100
        if dden == 0 then dden = 100 end
        local duration = dnum / dden
        if not isAnim then duration = 0 end
        if isAnim and duration <= 0 then duration = 0.1 end
        totalDuration += duration

        local dx0, dy0, dx1, dy1
        if idx == 1 then
            dx0, dy0, dx1, dy1 = 0, 0, width, height
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

        usedBytes += (dx1 - dx0) * (dy1 - dy0) * 4
        if usedBytes > maxBytes then
            fail("image needs more than " .. (maxBytes // 1048576) .. " MB of frame memory")
        end

        decodedFrames[idx] = {
            Pixels = extractRect(canvas, width, dx0, dy0, dx1, dy1),
            X = dx0, Y = dy0,
            Width = dx1 - dx0, Height = dy1 - dy0,
            Duration = duration,
        }

        hasPending = false
        if f.dispose == 1 and hasRect then
            clearRect(canvas, width, x0, y0, x1, y1)
            pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
            hasPending = true
        elseif f.dispose == 2 and saved then
            restoreRect(canvas, saved, width, x0, y0, x1, y1)
            pendingX0, pendingY0, pendingX1, pendingY1 = x0, y0, x1, y1
            hasPending = true
        end

        if yieldEvery and yieldEvery > 0 and idx % yieldEvery == 0 then
            task.wait()
        end
    end

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

local function pngHasAnimation(data)
    local pos = 9
    local length = #data
    while pos + 7 <= length do
        local a, b, c, d = string.byte(data, pos, pos + 3)
        local clen = a * 16777216 + b * 65536 + c * 256 + d
        local ctype = string.sub(data, pos + 4, pos + 7)
        if ctype == "acTL" then return true end
        if ctype == "IDAT" or ctype == "IEND" then return false end
        pos += 12 + clen
    end
    return false
end

local function detectWebP(data, length)
    if length < 12 then return false end
    return data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP"
end

local function detectBmp(data, length)
    return length >= 2 and data:sub(1, 2) == "BM"
end

local function detectIco(data, length)
    if length < 4 then return false end
    local b1, b2, b3, b4 = data:byte(1, 4)
    return b1 == 0x00 and b2 == 0x00 and (b3 == 0x01 or b3 == 0x02) and b4 == 0x00
end

local function detectTiff(data, length)
    if length < 4 then return false end
    return data:sub(1, 4) == "II\42\0" or data:sub(1, 4) == "MM\0\42"
end

local function detectHeic(data, length)
    if length < 12 then return false end
    if data:sub(5, 8) ~= "ftyp" then return false end
    local brand = data:sub(9, 12)
    return brand == "heic" or brand == "heix"
        or brand == "hevc" or brand == "hevx"
        or brand == "mif1" or brand == "msf1"
end

local function detectSvg(data, length)
    if length < 4 then return false end
    local head = data:sub(1, math.min(length, 512)):lower()
    if head:match("^%s*<svg") then return true end
    if head:match("^%s*<%?xml") and head:find("<svg", 1, true) then return true end
    return false
end

function GifDecoder.detect(data)
    if type(data) ~= "string" or #data < 4 then return "unknown" end
    local length = #data

    if length >= 8 and data:sub(1, 8) == PNG_SIG then
        if pngHasAnimation(data) then return "apng" end
        return "png"
    end

    local sig6 = data:sub(1, 6)
    if sig6 == "GIF87a" or sig6 == "GIF89a" then return "gif" end

    local b1, b2, b3 = data:byte(1, 3)
    if b1 == 0xFF and b2 == 0xD8 and b3 == 0xFF then return "jpg" end

    if detectWebP(data, length) then return "webp" end
    if detectBmp(data, length) then return "bmp" end
    if detectIco(data, length) then return "ico" end
    if detectTiff(data, length) then return "tiff" end
    if detectHeic(data, length) then return "heic" end
    if detectSvg(data, length) then return "svg" end

    return "unknown"
end

function GifDecoder.decode(data, options)
    assert(typeof(data) == "string", "decode expects bytes as a string")
    local kind = GifDecoder.detect(data)

    if kind == "gif" then
        return decodeGif(data, options)
    elseif kind == "apng" or kind == "png" then
        return decodePng(data, options)
    elseif kind == "unknown" then
        fail("unsupported file format")
    else
        fail("decoder only handles GIF/APNG/PNG; " .. kind ..
             " must be loaded via getcustomasset (static path)")
    end
end

return GifDecoder
