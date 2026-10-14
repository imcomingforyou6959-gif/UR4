local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local GifRenderer = {}
GifRenderer.__index = GifRenderer

-- where the decoder lives; change this if you move the file
GifRenderer.DecoderUrl = "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Rendering/GifDecoder.luau"
-- a cached decoder with an older Version gets reloaded
GifRenderer.RequiredDecoderVersion = 2
-- longest slice of time one frame update may consume, stops a lag spike from fast-forwarding the gif
GifRenderer.MaxDeltaTime = 0.25

-- A frame is RGBA pixels for a rectangle of the canvas. X/Y/Width/Height are optional and default to
-- the whole canvas, so plain full-size frames still work. Frame 1 must cover the whole canvas.
export type Frame = {
	Pixels: buffer,
	Duration: number?,
	X: number?,
	Y: number?,
	Width: number?,
	Height: number?,
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
}

local DecoderCache
local DecodedCache = {}

-- binary safe download, request() first because HttpGet can mangle binary data
local function download(url: string): string
	local req = request or http_request or (syn and syn.request)
	local lastError = "no response"

	for attempt = 1, 2 do
		if req then
			local ok, response = pcall(req, {Url = url, Method = "GET"})
			if ok and type(response) == "table" and response.StatusCode == 200 and type(response.Body) == "string" and #response.Body > 0 then
				return response.Body
			end
			lastError = if ok then "HTTP " .. tostring(type(response) == "table" and response.StatusCode) else tostring(response)
		end

		local ok, body = pcall(game.HttpGet, game, url)
		if ok and type(body) == "string" and #body > 0 then
			return body
		end
		lastError = tostring(body)

		if attempt < 2 then
			task.wait(0.5)
		end
	end

	error("GifRenderer: failed to download " .. url .. " (" .. lastError .. ")", 3)
end

-- loads the decoder lazily so requiring this file never fails on its own
local function getDecoder()
	if DecoderCache then
		return DecoderCache
	end

	local env = getgenv and getgenv() or nil
	local cached = env and env.GifDecoder
	if type(cached) == "table" and cached.Version == GifRenderer.RequiredDecoderVersion then
		DecoderCache = cached
		return DecoderCache
	end

	local source = download(GifRenderer.DecoderUrl)
	local chunk, compileError = loadstring(source)
	if not chunk then
		error("GifRenderer: GifDecoder failed to compile: " .. tostring(compileError), 3)
	end

	DecoderCache = chunk()
	if env then
		env.GifDecoder = DecoderCache
	end
	return DecoderCache
end

function GifRenderer.new(options: Options)
	assert(options and options.Frames and #options.Frames > 0, "Frames cannot be empty")
	local width = math.floor(options.Size.X)
	local height = math.floor(options.Size.Y)
	assert(width > 0 and height > 0 and width <= 1024 and height <= 1024, "Size must be 1..1024")

	local frameCount = #options.Frames
	local defaultDuration = options.DefaultFrameDuration or (1 / 12)

	-- everything per frame is worked out once here instead of every time a frame is shown
	local positions = table.create(frameCount)
	local sizes = table.create(frameCount)
	local durations = table.create(frameCount)
	local fullAt = table.create(frameCount) -- latest frame <= i that covers the whole canvas
	local lastFull = 0

	for index, frame in options.Frames do
		assert(typeof(frame.Pixels) == "buffer", "Frame.Pixels must be a buffer")
		local x = frame.X or 0
		local y = frame.Y or 0
		local w = frame.Width or width
		local h = frame.Height or height
		assert(w > 0 and h > 0 and x >= 0 and y >= 0 and x + w <= width and y + h <= height, "Frame rectangle is outside the canvas")
		assert(buffer.len(frame.Pixels) == w * h * 4, "Invalid RGBA frame buffer length")
		assert(frame.Duration == nil or frame.Duration >= 0, "Frame.Duration must be >= 0")

		positions[index] = Vector2.new(x, y)
		sizes[index] = Vector2.new(w, h)
		local duration = frame.Duration or defaultDuration
		durations[index] = if duration <= 0 then 1 / 60 else duration

		if w == width and h == height then
			lastFull = index
		end
		fullAt[index] = lastFull
	end
	assert(fullAt[1] == 1, "The first frame must cover the whole canvas")

	local self = setmetatable({
		Frames = options.Frames,
		FrameCount = frameCount,
		Width = width,
		Height = height,
		Looped = options.Looped ~= false,
		Speed = math.max(options.Speed or 1, 0),
		OnFinished = options.OnFinished,
		FrameIndex = 1,
		Elapsed = 0,
		Playing = false,
		Destroyed = false,
		ImageLabel = options.ImageLabel,
		Connection = nil,
		LabelConnection = nil,
		_positions = positions,
		_sizes = sizes,
		_durations = durations,
		_fullAt = fullAt,
	}, GifRenderer)

	local created, image = pcall(AssetService.CreateEditableImage, AssetService, {Size = Vector2.new(width, height)})
	if not created then
		error("GifRenderer: couldn't create an EditableImage, this executor or game may not support it (" .. tostring(image) .. ")", 2)
	end
	self.Image = image

	local label = options.ImageLabel
	if label then
		label.ImageContent = Content.fromObject(image)
		-- don't keep decoding for a label that no longer exists
		self.LabelConnection = label.Destroying:Connect(function()
			self:Destroy()
		end)
	end
	self:_writeFrame(1)

	self.Connection = RunService.RenderStepped:Connect(function(dt)
		if not self.Playing then
			return
		end
		-- nothing to see, so don't spend time on it
		if label and not label.Visible then
			return
		end
		self:_advance(math.min(dt * self.Speed, GifRenderer.MaxDeltaTime))
	end)

	if options.AutoPlay then
		self:Play()
	end
	return self
end

-- builds a renderer from an already decoded gif (see GifDecoder.decode)
function GifRenderer.fromGif(gif, options: {[string]: any}?)
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
	})
end

-- decode raw gif bytes and build a renderer from them
-- extra options: ImageLabel, Looped, AutoPlay, Speed, OnFinished, Yield (task.wait every N decoded frames), RawDelays
function GifRenderer.fromData(data: string, options: {[string]: any}?)
	options = options or {}
	local gif = getDecoder().decode(data, {Yield = options.Yield, RawDelays = options.RawDelays})
	return GifRenderer.fromGif(gif, options)
end

-- download + decode + render. This yields, so call it from task.spawn
-- decoded frames are cached per url so the same gif is only downloaded and decoded once, pass Cache = false to skip that
function GifRenderer.fromUrl(url: string, options: {[string]: any}?)
	options = options or {}
	local gif = DecodedCache[url]
	if not gif then
		gif = getDecoder().decode(download(url), {Yield = options.Yield, RawDelays = options.RawDelays})
		if options.Cache ~= false then
			DecodedCache[url] = gif
		end
	end
	return GifRenderer.fromGif(gif, options)
end

function GifRenderer.ClearCache()
	table.clear(DecodedCache)
end

-- writes a single frame's rectangle onto the image
function GifRenderer:_writeFrame(index: number)
	self.Image:WritePixelsBuffer(self._positions[index], self._sizes[index], self.Frames[index].Pixels)
end

-- brings the image from frame `from` to frame `target`, only touching what has to change
function GifRenderer:_showFrame(from: number, target: number)
	local start = if target > from then from + 1 else 1
	-- a full-canvas frame overwrites everything before it, so skip straight to the latest one
	start = math.max(start, self._fullAt[target])
	for index = start, target do
		self:_writeFrame(index)
	end
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
		task.spawn(self.OnFinished, self)
	end
end

function GifRenderer:SetFrame(index: number)
	assert(not self.Destroyed, "Renderer has been destroyed")
	assert(index == math.floor(index) and index >= 1 and index <= self.FrameCount, "Frame index out of range")
	local from = self.FrameIndex
	self.FrameIndex = index
	self.Elapsed = 0
	self:_showFrame(from, index)
end

function GifRenderer:SetSpeed(speed: number)
	self.Speed = math.max(speed, 0)
end

function GifRenderer:GetFrameCount(): number
	return self.FrameCount
end

function GifRenderer:Play()
	assert(not self.Destroyed, "Renderer has been destroyed")
	-- replaying a finished non-looping gif starts it over
	if not self.Looped and self.FrameIndex == self.FrameCount and not self.Playing then
		self:SetFrame(1)
	end
	self.Playing = true
end

function GifRenderer:Pause()
	self.Playing = false
end

function GifRenderer:Stop()
	self.Playing = false
	self:SetFrame(1)
end

function GifRenderer:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Playing = false
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.LabelConnection then
		self.LabelConnection:Disconnect()
		self.LabelConnection = nil
	end
	local label = self.ImageLabel
	if label and label.Parent then
		pcall(function()
			label.ImageContent = Content.none
		end)
	end
	self.Image:Destroy()
end

return GifRenderer
