--!native
--!optimize 2
-- SpeedKit

local bufferCreate = buffer.create
local bufferLen    = buffer.len
local bufferCopy   = buffer.copy
local bufferFill   = buffer.fill
local readu8       = buffer.readu8
local writeu8      = buffer.writeu8
local band         = bit32.band
local rshift       = bit32.rshift

local SpeedKit = {}
SpeedKit.Version = 1

local MUL_DIV_255 = bufferCreate(256 * 256)
for a = 0, 255 do
    local row = a * 256
    for b = 0, 255 do
        writeu8(MUL_DIV_255, row + b, (a * b + 127) // 255)
    end
end
SpeedKit.MulDiv255 = MUL_DIV_255

local INV_ALPHA = bufferCreate(256)
for a = 0, 255 do writeu8(INV_ALPHA, a, 255 - a) end
SpeedKit.InvAlpha = INV_ALPHA

local function blendPixel(c, dc)
    local a = rshift(c, 24)
    if a == 255 then return c end
    if a == 0 then return dc end
    local cr = band(c, 0xFF)
    local cg = band(rshift(c, 8), 0xFF)
    local cb = band(rshift(c, 16), 0xFF)
    local dr = band(dc, 0xFF)
    local dg = band(rshift(dc, 8), 0xFF)
    local db = band(rshift(dc, 16), 0xFF)
    local da = rshift(dc, 24)
    local ia = readu8(INV_ALPHA, a)
    local orr = readu8(MUL_DIV_255, cr * 256 + a) + readu8(MUL_DIV_255, dr * 256 + ia)
    local ogg = readu8(MUL_DIV_255, cg * 256 + a) + readu8(MUL_DIV_255, dg * 256 + ia)
    local obb = readu8(MUL_DIV_255, cb * 256 + a) + readu8(MUL_DIV_255, db * 256 + ia)
    local oaa = a + readu8(MUL_DIV_255, da * 256 + ia)
    if orr > 255 then orr = 255 end
    if ogg > 255 then ogg = 255 end
    if obb > 255 then obb = 255 end
    if oaa > 255 then oaa = 255 end
    return orr + ogg * 256 + obb * 65536 + oaa * 16777216
end
SpeedKit.Blend = blendPixel

local pool = {}
local poolBytes = 0
local MAX_POOL_BYTES = 64 * 1024 * 1024

local function sizeClass(size)
    if size <= 4096 then return 4096 end
    if size <= 65536 then return 65536 end
    if size <= 262144 then return 262144 end
    if size <= 1048576 then return 1048576 end
    if size <= 4194304 then return 4194304 end
    if size <= 16777216 then return 16777216 end
    return ((size + 0xFFFFFF) // 0x1000000) * 0x1000000
end

function SpeedKit.acquire(size)
    local class = sizeClass(size)
    for i = #pool, 1, -1 do
        local buf = pool[i]
        if bufferLen(buf) >= class then
            table.remove(pool, i)
            poolBytes -= bufferLen(buf)
            bufferFill(buf, 0, 0, class)
            return buf
        end
    end
    return bufferCreate(class)
end

function SpeedKit.release(buf)
    if not buf then return end
    local len = bufferLen(buf)
    if len > MAX_POOL_BYTES then return end
    if poolBytes + len > MAX_POOL_BYTES then
        local largest, largestIdx = 0, 0
        for i = 1, #pool do
            local bl = bufferLen(pool[i])
            if bl > largest then largest, largestIdx = bl, i end
        end
        if largestIdx > 0 then
            poolBytes -= largest
            table.remove(pool, largestIdx)
        end
    end
    table.insert(pool, buf)
    poolBytes += len
end

function SpeedKit.clearPool()
    table.clear(pool)
    poolBytes = 0
end

function SpeedKit.poolBytes()
    return poolBytes
end

local function unfilter0(raw, pos, rowBytes, _, _, cur)
    bufferCopy(cur, 0, raw, pos, rowBytes)
end

local function unfilter1(raw, pos, rowBytes, bpp, _, cur)
    bufferCopy(cur, 0, raw, pos, rowBytes)
    for i = bpp, rowBytes - 1 do
        writeu8(cur, i, band(readu8(cur, i) + readu8(cur, i - bpp), 0xFF))
    end
end

local function unfilter2(raw, pos, rowBytes, _, prev, cur)
    for i = 0, rowBytes - 1 do
        writeu8(cur, i, band(readu8(raw, pos + i) + readu8(prev, i), 0xFF))
    end
end

local function unfilter3(raw, pos, rowBytes, bpp, prev, cur)
    bufferCopy(cur, 0, raw, pos, rowBytes)
    for i = 0, rowBytes - 1 do
        local a = if i >= bpp then readu8(cur, i - bpp) else 0
        writeu8(cur, i, band(readu8(cur, i) + rshift(a + readu8(prev, i), 1), 0xFF))
    end
end

local function unfilter4(raw, pos, rowBytes, bpp, prev, cur)
    for i = 0, rowBytes - 1 do
        local a, c = 0, 0
        if i >= bpp then
            a = readu8(cur, i - bpp)
            c = readu8(prev, i - bpp)
        end
        local b = readu8(prev, i)
        local pa = b >= c and b - c or c - b
        local pb = a >= c and a - c or c - a
        local s = a + b
        local t2c = c + c
        local pc = s >= t2c and s - t2c or t2c - s
        local predictor
        if pa <= pb and pa <= pc then predictor = a
        elseif pb <= pc then predictor = b
        else predictor = c end
        writeu8(cur, i, band(readu8(raw, pos + i) + predictor, 0xFF))
    end
end

SpeedKit.UNFILTER = {unfilter0, unfilter1, unfilter2, unfilter3, unfilter4}

local hasDesync = pcall(function()
    if task and task.desynchronize then
        task.desynchronize()
        task.synchronize()
    end
end)

function SpeedKit.hasDesync()
    return hasDesync
end

function SpeedKit.withDesync(fn)
    if not hasDesync then return fn() end
    task.desynchronize()
    local ok, a, b, c = pcall(fn)
    task.synchronize()
    if not ok then error(a, 0) end
    return a, b, c
end

return SpeedKit
