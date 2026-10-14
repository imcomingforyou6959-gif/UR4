local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local GifDecoder = loadstring(Game:HttpGet("https://raw.githubusercontent.com/mental1illness/modules/refs/heads/main/GifDecoder.luau"))()

export type Frame = {
	Pixels: buffer,
	Duration: number?,
}

export type Options = {
	ImageLabel: ImageLabel?,
	Frames: {Frame},
	Size: Vector2,
	Looped: boolean?,
	DefaultFrameDuration: number?,
	AutoPlay: boolean?,
}

local GifRenderer = {}
GifRenderer.__index = GifRenderer

local function validateFrame(frame: Frame, width: number, height: number)
	assert(typeof(frame.Pixels) == "buffer", "Frame.Pixels must be a buffer")
	assert(buffer.len(frame.Pixels) == width * height * 4, "Invalid RGBA frame buffer length")
	assert(frame.Duration == nil or frame.Duration >= 0, "Frame.Duration must be >= 0")
end

function GifRenderer.new(options: Options)
	assert(options and #options.Frames > 0, "Frames cannot be empty")
	local width = math.floor(options.Size.X)
	local height = math.floor(options.Size.Y)
	assert(width > 0 and height > 0 and width <= 1024 and height <= 1024, "Size must be 1..1024")

	for _, frame in options.Frames do
		validateFrame(frame, width, height)
	end

	local self = setmetatable({
		Frames = options.Frames,
		Width = width,
		Height = height,
		Looped = options.Looped ~= false,
		DefaultFrameDuration = options.DefaultFrameDuration or (1 / 12),
		FrameIndex = 1,
		Elapsed = 0,
		Playing = false,
		Destroyed = false,
		Connection = nil,
	}, GifRenderer)

	self.Image = AssetService:CreateEditableImage({Size = Vector2.new(width, height)})
	if options.ImageLabel then
		options.ImageLabel.ImageContent = Content.fromObject(self.Image)
	end
	self:_writeCurrentFrame()

	self.Connection = RunService.RenderStepped:Connect(function(dt)
		if not self.Playing or self.Destroyed then
			return
		end
		self.Elapsed += dt

		local duration = self.Frames[self.FrameIndex].Duration or self.DefaultFrameDuration
		if duration <= 0 then duration = 1 / 60 end
		while self.Elapsed >= duration do
			self.Elapsed -= duration
			if self.FrameIndex == #self.Frames then
				if not self.Looped then
					self.Playing = false
					self.Elapsed = 0
					return
				end
				self.FrameIndex = 1
			else
				self.FrameIndex += 1
			end
			self:_writeCurrentFrame()
			duration = self.Frames[self.FrameIndex].Duration or self.DefaultFrameDuration
			if duration <= 0 then duration = 1 / 60 end
		end
	end)

	if options.AutoPlay then self:Play() end
	return self
end

function GifRenderer:_writeCurrentFrame()
	self.Image:WritePixelsBuffer(
		Vector2.zero,
		Vector2.new(self.Width, self.Height),
		self.Frames[self.FrameIndex].Pixels
	)
end

function GifRenderer:SetFrame(index: number)
	assert(not self.Destroyed, "Renderer has been destroyed")
	assert(index == math.floor(index) and index >= 1 and index <= #self.Frames, "Frame index out of range")
	self.FrameIndex = index
	self.Elapsed = 0
	self:_writeCurrentFrame()
end

function GifRenderer:Play()
	assert(not self.Destroyed, "Renderer has been destroyed")
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
	if self.Destroyed then return end
	self.Destroyed = true
	self.Playing = false
	if self.Connection then self.Connection:Disconnect() end
	self.Image:Destroy()
end

return GifRenderer
