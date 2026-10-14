--!nonstrict
-- GifDecoder v6
-- GIF87a / GIF89a only. No PNG/APNG decoding; static PNG/JPG is handled
-- directly by the Waifu renderer via getcustomasset.

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

local GifDecoder = {}
GifDecoder.Version = 6

local MAX_CANVAS = 1024
local MAX_FRAME_PIXELS = 16777216
local MAX_TOTAL_FRAMES = 5000

local function fail(msg) error("GifDecoder: " .. msg, 3) end
local function need(len, pos, count)
    if pos < 0 or pos + count > len then fail("unexpected end of data") end
end

-- ============================================================================
-- Shared helpers
-- ============================================================================

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

local function lzwDecode(src, srcLength, minCodeSize, expected, output, tables, padValue)
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
            lzwDecode(compressed, compressedLength, minCodeSize, expected, indices, tables, gceTransparent or 0)

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
-- public API
-- ============================================================================

function GifDecoder.detect(data)
    if type(data) ~= "string" or #data < 6 then return "unknown" end
    local sig6 = data:sub(1, 6)
    if sig6 == "GIF87a" or sig6 == "GIF89a" then return "gif" end
    if data:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
    if data:sub(1, 3) == "\255\216\255" then return "jpg" end
    return "unknown"
end

function GifDecoder.decode(data, options)
    assert(typeof(data) == "string", "decode expects bytes as a string")
    local kind = GifDecoder.detect(data)
    if kind == "gif" then
        return decodeGif(data, options)
    else
        fail("GifDecoder only decodes GIF; use getcustomasset for " .. kind)
    end
end

return GifDecoder
