--!nonstrict
-- GifRenderer v3
local AssetService = game:GetService("AssetService")
local RunService   = game:GetService("RunService")

local GifRenderer = {}
GifRenderer.__index = GifRenderer

GifRenderer.DecoderUrl = "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Rendering/GifDecoder.luau"
GifRenderer.RequiredDecoderVersion = 11
GifRenderer.MaxDeltaTime = 0.25

GifRenderer.FrameBudget = 0.002
GifRenderer.CacheBudgetBytes = 256 * 1024 * 1024
GifRenderer.Adaptive = true
GifRenderer.DefaultYield = 8

local MAX_TILE = 1024              -- hard limit for a single EditableImage side
local MAX_CANVAS = 8192            -- overall canvas limit

export type Frame = {
	Pixels: buffer,
	Duration: number?,
	X: number?, Y: number?,
	Width: number?, Height: number?,
}

export type Options = {
	ImageLabel: ImageLabel?,
	Frames: {Frame},
	Size: Vector2,
	Looped: boolean?,
	DefaultFrameDuration: number?,
	AutoPlay: boolean?,
	Speed: number?,
	OnFinished: ((any) -> ())?,

	LowPower: boolean?,
	UpdateRate: number?,
	MaxFrameSkip: number?,
	SkipDuplicates: boolean?,
}

local DecoderCache

local function download(url: string): string
	local req = request or http_request or (syn and syn.request)
	local lastError = "no response"
	for attempt = 1, 2 do
		if req then
			local ok, response = pcall(req, {Url = url, Method = "GET"})
			if ok and type(response) == "table" and tonumber(response.StatusCode) == 200
				and type(response.Body) == "string" and #response.Body > 0 then
				return response.Body
			end
			lastError = if ok then "HTTP " .. tostring(type(response) == "table" and response.StatusCode)
				else tostring(response)
		end
		local ok, body = pcall(game.HttpGet, game, url)
		if ok and type(body) == "string" and #body > 0 then return body end
		lastError = tostring(body)
		if attempt < 2 then task.wait(0.5) end
	end
	error("GifRenderer: failed to download " .. url .. " (" .. lastError .. ")", 3)
end

local function getDecoder()
	if DecoderCache then return DecoderCache end
	local env = getgenv and getgenv() or nil
	local cached = env and env.GifDecoder
	if type(cached) == "table" and type(cached.decode) == "function" then
		local cv = cached.Version
		if cv == nil or (type(cv) == "number" and cv >= GifRenderer.RequiredDecoderVersion) then
			DecoderCache = cached
			return DecoderCache
		end
	end
	local source = download(GifRenderer.DecoderUrl)
	local chunk, compileError = loadstring(source)
	if not chunk then
		error("GifRenderer: decoder failed to compile: " .. tostring(compileError), 3)
	end
	DecoderCache = chunk()
	if env then env.GifDecoder = DecoderCache end
	return DecoderCache
end

local cache = {}
local cacheBytes = 0
local cacheClock = 0

local function cacheGet(url)
	local entry = cache[url]
	if not entry then return nil end
	cacheClock += 1
	entry.used = cacheClock
	return entry.gif
end

local function cachePut(url, gif)
	local bytes = 0
	for _, frame in gif.Frames do bytes += buffer.len(frame.Pixels) end
	local budget = GifRenderer.CacheBudgetBytes
	if bytes > budget then return end

	local old = cache[url]
	if old then cacheBytes -= old.bytes end
	cacheClock += 1
	cache[url] = {gif = gif, bytes = bytes, used = cacheClock}
	cacheBytes += bytes

	while cacheBytes > budget do
		local oldestKey, oldest
		for key, entry in cache do
			if key ~= url and (not oldest or entry.used < oldest.used) then
				oldestKey, oldest = key, entry
			end
		end
		if not oldestKey then break end
		cacheBytes -= oldest.bytes
		cache[oldestKey] = nil
	end
end

local function decodeOptions(options)
	local yield = options.Yield
	if yield == nil then yield = GifRenderer.DefaultYield end
	return {Yield = yield, RawDelays = options.RawDelays}
end

local playing = {}
local connection = nil
local rotate = 0
local throttle = 1
local dtAverage = 1 / 60

local function onHeartbeat(dt)
	if GifRenderer.Adaptive then
		dtAverage += (dt - dtAverage) * 0.05
		if dtAverage > 0.04 then throttle = 3
		elseif dtAverage > 0.025 then throttle = 2
		elseif dtAverage < 0.019 then throttle = 1 end
	else
		throttle = 1
	end

	local count = #playing
	if count == 0 then return end

	local now = os.clock()
	local deadline = now + GifRenderer.FrameBudget
	local first = rotate % count
	local removeDead = false
	local cut = false

	for k = 0, count - 1 do
		local renderer = playing[(first + k) % count + 1]
		local ok, err = pcall(renderer._tick, renderer, now)
		if not ok then
			warn("GifRenderer: stopped a renderer after an error: " .. tostring(err))
			renderer.Playing = false
		end
		if not renderer.Playing then removeDead = true end
		if k < count - 1 and os.clock() > deadline then
			rotate = first + k + 1
			cut = true
			break
		end
	end
	if not cut then rotate = first end

	if removeDead then
		local write = 0
		for read = 1, count do
			local renderer = playing[read]
			if renderer.Playing then
				write += 1
				playing[write] = renderer
			else
				renderer._registered = false
			end
		end
		for i = count, write + 1, -1 do playing[i] = nil end
		rotate = 0
	end

	if #playing == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function register(renderer)
	if renderer._registered then return end
	renderer._registered = true
	table.insert(playing, renderer)
	if not connection then
		connection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

local function unregister(renderer)
	if not renderer._registered then return end
	renderer._registered = false
	local index = table.find(playing, renderer)
	if index then table.remove(playing, index) end
	if #playing == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function createEditableImage(w, h)
	local created, image = pcall(AssetService.CreateEditableImage, AssetService,
		{Size = Vector2.new(w, h)})
	if not created then
		error("GifRenderer: couldn't create an EditableImage (" .. tostring(image) .. ")", 3)
	end
	return image
end

function GifRenderer.new(options: Options)
	assert(options and options.Frames and #options.Frames > 0, "Frames cannot be empty")
	local width  = math.floor(options.Size.X)
	local height = math.floor(options.Size.Y)
	assert(width > 0 and height > 0 and width <= MAX_CANVAS and height <= MAX_CANVAS,
		"Size must be 1.." .. MAX_CANVAS)

	local frameCount = #options.Frames
	local defaultDuration = options.DefaultFrameDuration or (1 / 12)

	local positions = table.create(frameCount)
	local sizes     = table.create(frameCount)
	local durations = table.create(frameCount)
	local starts    = table.create(frameCount)
	local fullAt    = table.create(frameCount)
	local lastFull  = 0
	local total     = 0

	for index, frame in options.Frames do
		assert(typeof(frame.Pixels) == "buffer", "Frame.Pixels must be a buffer")
		local x = frame.X or 0
		local y = frame.Y or 0
		local w = frame.Width or width
		local h = frame.Height or height
		assert(w > 0 and h > 0 and x >= 0 and y >= 0 and x + w <= width and y + h <= height,
			"Frame rectangle is outside the canvas")
		assert(buffer.len(frame.Pixels) == w * h * 4, "Invalid RGBA frame buffer length")
		assert(frame.Duration == nil or frame.Duration >= 0, "Frame.Duration must be >= 0")

		positions[index] = Vector2.new(x, y)
		sizes[index] = Vector2.new(w, h)
		local duration = frame.Duration or defaultDuration
		if duration <= 0 then duration = 1 / 60 end
		durations[index] = duration
		starts[index] = total
		total += duration

		if w == width and h == height then lastFull = index end
		fullAt[index] = lastFull
	end
	assert(fullAt[1] == 1, "The first frame must cover the whole canvas")

	local lowPower   = options.LowPower == true
	local updateRate = options.UpdateRate or (if lowPower then 30 else 60)
	local minDt      = if updateRate > 0 then 1 / updateRate else 0

	local self = setmetatable({
		Frames = options.Frames,
		FrameCount = frameCount,
		Width = width, Height = height,
		Looped = options.Looped ~= false,
		Speed = math.max(options.Speed or 1, 0),
		OnFinished = options.OnFinished,
		FrameIndex = 1,
		Elapsed = 0,
		Playing = false,
		Destroyed = false,
		ImageLabel = options.ImageLabel,
		LabelConnection = nil,
		TotalDuration = total,
		_positions = positions,
		_sizes = sizes,
		_durations = durations,
		_starts = starts,
		_fullAt = fullAt,
		_minDt = minDt,
		_last = 0,
		_visible = true,
		_visibleCheckAt = 0,
		_registered = false,
		_tiles = {},
		_images = {},
		_labels = {},
		_scratch = {},
		_transparency = 0,
		_single = true,
	}, GifRenderer)

	local providedLabel = options.ImageLabel
	local cols = math.ceil(width / MAX_TILE)
	local rows = math.ceil(height / MAX_TILE)
	local tileW = math.ceil(width / cols)
	local tileH = math.ceil(height / rows)
	if tileW > MAX_TILE then tileW = MAX_TILE end
	if tileH > MAX_TILE then tileH = MAX_TILE end
	cols = math.ceil(width / tileW)
	rows = math.ceil(height / tileH)

	if cols == 1 and rows == 1 then
		local image = createEditableImage(width, height)
		local label
		if providedLabel then
			label = providedLabel
		else
			label = Instance.new("ImageLabel")
			label.BackgroundTransparency = 1
			label.BorderSizePixel = 0
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromOffset(width, height)
			label.ScaleType = Enum.ScaleType.Fit
		end
		label.ImageContent = Content.fromObject(image)
		self._images[1] = image
		self._labels[1] = label
		self._tiles[1] = {x = 0, y = 0, w = width, h = height, image = image, label = label}
		self.ImageLabel = label
		self._single = true
	else
		local container = providedLabel
		if not container then
			container = Instance.new("Frame")
			container.BackgroundTransparency = 1
			container.BorderSizePixel = 0
			container.AnchorPoint = Vector2.new(0.5, 0.5)
			container.Position = UDim2.fromScale(0.5, 0.5)
			container.Size = UDim2.fromOffset(width, height)
		end

		if container:IsA("ImageLabel") then
			container.Image = ""
			container.ImageTransparency = 1
		end

		local idx = 0
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				local x = col * tileW
				local y = row * tileH
				local w = math.min(tileW, width - x)
				local h = math.min(tileH, height - y)
				if w > 0 and h > 0 then
					local image = createEditableImage(w, h)
					local label = Instance.new("ImageLabel")
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					label.ScaleType = Enum.ScaleType.Stretch
					label.Position = UDim2.fromScale(x / width, y / height)
					label.Size = UDim2.fromScale(w / width, h / height)
					label.ImageTransparency = self._transparency
					label.ImageContent = Content.fromObject(image)
					label.Parent = container
					idx += 1
					self._images[idx] = image
					self._labels[idx] = label
					self._tiles[idx] = {x = x, y = y, w = w, h = h, image = image, label = label}
				end
			end
		end
		self.ImageLabel = container
		self._single = false
	end

	if self.ImageLabel then
		self.LabelConnection = self.ImageLabel.Destroying:Connect(function() self:Destroy() end)
	end

	self:_writeFrame(1)

	if options.AutoPlay then self:Play() end
	return self
end

function GifRenderer.fromGif(gif, options)
	options = options or {}
	return GifRenderer.new({
		ImageLabel = options.ImageLabel,
		Frames = gif.Frames,
		Size = Vector2.new(gif.Width, gif.Height),
		Looped = options.Looped,
		DefaultFrameDuration = options.DefaultFrameDuration,
		AutoPlay = options.AutoPlay,
		Speed = options.Speed,
		OnFinished = options.OnFinished,
		LowPower = options.LowPower,
		UpdateRate = options.UpdateRate,
	})
end

function GifRenderer.fromData(data: string, options)
	options = options or {}
	local gif = getDecoder().decode(data, decodeOptions(options))
	return GifRenderer.fromGif(gif, options)
end

local function loadGif(url, options)
	local gif = cacheGet(url)
	if gif then return gif end
	gif = getDecoder().decode(download(url), decodeOptions(options))
	if options.Cache ~= false then cachePut(url, gif) end
	return gif
end

function GifRenderer.fromUrl(url: string, options)
	options = options or {}
	return GifRenderer.fromGif(loadGif(url, options), options)
end

local pendingLoads = {}

function GifRenderer.fromUrlAsync(url: string, options, callback)
	options = options or {}
	local gif = cacheGet(url)
	if gif then
		task.defer(function()
			local ok, result = pcall(GifRenderer.fromGif, gif, options)
			if ok then callback(result, nil) else callback(nil, tostring(result)) end
		end)
		return
	end

	local waiting = pendingLoads[url]
	if waiting then
		table.insert(waiting, {options = options, callback = callback})
		return
	end
	waiting = {{options = options, callback = callback}}
	pendingLoads[url] = waiting

	task.spawn(function()
		local ok, result = pcall(loadGif, url, options)
		pendingLoads[url] = nil
		for _, entry in waiting do
			if ok then
				local built, renderer = pcall(GifRenderer.fromGif, result, entry.options)
				if built then entry.callback(renderer, nil) else entry.callback(nil, tostring(renderer)) end
			else
				entry.callback(nil, tostring(result))
			end
		end
	end)
end

function GifRenderer.preload(url: string, options, callback)
	options = options or {}
	task.spawn(function()
		local ok, err = pcall(loadGif, url, options)
		if callback then callback(ok, if ok then nil else tostring(err)) end
	end)
end

function GifRenderer.ClearCache()
	table.clear(cache)
	cacheBytes = 0
end

function GifRenderer.GetCacheBytes(): number return cacheBytes end

function GifRenderer:_writeFrame(index)
	local frame = self.Frames[index]
	local fx = frame.X or 0
	local fy = frame.Y or 0
	local fw = frame.Width or self.Width
	local fh = frame.Height or self.Height
	local pixels = frame.Pixels

	if self._single then
		self._images[1]:WritePixelsBuffer(Vector2.new(fx, fy), Vector2.new(fw, fh), pixels)
		return
	end

	for i = 1, #self._tiles do
		local tile = self._tiles[i]
		local ox = math.max(tile.x, fx)
		local oy = math.max(tile.y, fy)
		local ex = math.min(tile.x + tile.w, fx + fw)
		local ey = math.min(tile.y + tile.h, fy + fh)
		if ox < ex and oy < ey then
			local sw = ex - ox
			local sh = ey - oy
			local srcFx = ox - fx
			local srcFy = oy - fy
			local rowBytes = sw * 4
			local size = rowBytes * sh
			local scr = self._scratch[i]
			if not scr or buffer.len(scr) ~= size then
				scr = buffer.create(size)
				self._scratch[i] = scr
			end
			for row = 0, sh - 1 do
				buffer.copy(scr, row * rowBytes, pixels,
					((srcFy + row) * fw + srcFx) * 4, rowBytes)
			end
			self._images[i]:WritePixelsBuffer(
				Vector2.new(ox - tile.x, oy - tile.y),
				Vector2.new(sw, sh),
				scr)
		end
	end
end

function GifRenderer:_showFrame(from: number, target: number)
	if target == from then return end
	local start = if target > from then from + 1 else 1
	local fullStart = self._fullAt[target]
	if fullStart > start then start = fullStart end
	for index = start, target do
		self:_writeFrame(index)
	end
end

function GifRenderer:_checkVisible(): boolean
	local label = self.ImageLabel
	if not label then return true end
	if not label:IsDescendantOf(game) then return false end
	if label:IsA("ImageLabel") and label.ImageTransparency >= 1 and self._single then
		return false
	end
	local size = label.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return false end
	local object = label
	while object and object ~= game do
		if object:IsA("GuiObject") then
			if not object.Visible then return false end
		elseif object:IsA("LayerCollector") then
			if not object.Enabled then return false end
		end
		object = object.Parent
	end
	return true
end

function GifRenderer:_tick(now: number)
	if now >= self._visibleCheckAt then
		self._visibleCheckAt = now + 0.25
		self._visible = self:_checkVisible()
	end
	if not self._visible then
		self._last = now
		return
	end

	local dt = (now - self._last) * self.Speed
	if dt < self._minDt * throttle then return end
	if dt < self._durations[self.FrameIndex] - self.Elapsed then return end

	self._last = now
	self:_advance(math.min(dt, GifRenderer.MaxDeltaTime))
end

function GifRenderer:_advance(dt: number)
	local frameCount = self.FrameCount
	local durations = self._durations
	local from = self.FrameIndex
	local index = from
	local elapsed = self.Elapsed + dt
	local duration = durations[index]
	local finished = false

	while elapsed >= duration do
		elapsed -= duration
		if index == frameCount then
			if not self.Looped then
				self.Playing = false
				elapsed = 0
				finished = true
				break
			end
			index = 1
		else
			index += 1
		end
		duration = durations[index]
	end
	self.Elapsed = elapsed

	if index ~= from then
		self.FrameIndex = index
		self:_showFrame(from, index)
	end
	if finished and self.OnFinished then
		task.defer(self.OnFinished, self)
	end
end

function GifRenderer:SetFrame(index: number)
	assert(not self.Destroyed, "Renderer has been destroyed")
	assert(index == math.floor(index) and index >= 1 and index <= self.FrameCount, "Frame index out of range")
	local from = self.FrameIndex
	self.FrameIndex = index
	self.Elapsed = 0
	self:_showFrame(if index > from then from else 0, index)
end

function GifRenderer:Seek(seconds: number)
	assert(not self.Destroyed, "Renderer has been destroyed")
	seconds = math.clamp(seconds, 0, math.max(self.TotalDuration - 1e-4, 0))
	local starts = self._starts
	local low, high = 1, self.FrameCount
	while low < high do
		local mid = (low + high + 1) // 2
		if starts[mid] <= seconds then low = mid else high = mid - 1 end
	end
	local from = self.FrameIndex
	self.FrameIndex = low
	self.Elapsed = seconds - starts[low]
	self:_showFrame(if low > from then from else 0, low)
end

function GifRenderer:SetSpeed(speed: number) self.Speed = math.max(speed, 0) end
function GifRenderer:SetLooped(looped: boolean) self.Looped = looped end

function GifRenderer:SetTransparency(t: number)
	t = math.clamp(t, 0, 1)
	self._transparency = t
	for i = 1, #self._labels do
		self._labels[i].ImageTransparency = t
	end
end

function GifRenderer:GetFrameCount(): number return self.FrameCount end
function GifRenderer:GetDuration(): number return self.TotalDuration end
function GifRenderer:IsPlaying(): boolean return self.Playing end

function GifRenderer:Play()
	assert(not self.Destroyed, "Renderer has been destroyed")
	if not self.Looped and self.FrameIndex == self.FrameCount and not self.Playing then
		self:SetFrame(1)
	end
	self.Playing = true
	self._last = os.clock()
	self._visibleCheckAt = 0
	register(self)
end

function GifRenderer:Pause()
	self.Playing = false
	unregister(self)
end

function GifRenderer:Toggle()
	if self.Playing then self:Pause() else self:Play() end
end

function GifRenderer:Stop()
	self:Pause()
	self:SetFrame(1)
end

function GifRenderer:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Playing = false
	unregister(self)
	if self.LabelConnection then self.LabelConnection:Disconnect(); self.LabelConnection = nil end
	if self._single then
		local label = self.ImageLabel
		if label and label.Parent and label:IsA("ImageLabel") then
			pcall(function() label.ImageContent = Content.none end)
		end
	else
		for i = 1, #self._labels do
			local lbl = self._labels[i]
			if lbl and lbl.Parent then
				pcall(function() lbl:Destroy() end)
			end
		end
	end
	for i = 1, #self._images do
		pcall(function() self._images[i]:Destroy() end)
	end
end

return GifRenderer
