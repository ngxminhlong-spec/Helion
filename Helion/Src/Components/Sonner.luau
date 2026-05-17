--[[
Helion — Sonner notification system
Ported from Sonner by Emil Kowalski (https://sonner.emilkowal.ski/)
]]

local Sonner = {
	Queue = {},
	TweenInfo = TweenInfo.new(0.42, Enum.EasingStyle.Exponential),
	Wrapper = nil,
	PendingQueue = {},
	Processing = false,
}

local Icons = require(script.Parent.Icons)
local Interface = require(script.Parent.Interface)
local Animations = require(script.Parent.Animations)

local T = Interface.Theme

-- Accent colours per type
local TypeAccents = {
	info    = T.AccentInfo,
	success = T.AccentSuccess,
	warning = T.AccentWarning,
	error   = T.AccentError,
}

local function InternalCreateNotificationObject(zindex, image, text, accentColor)
	-- Outer canvas for group fade
	local NotificationTemplate = Interface.New("CanvasGroup", {
		BorderSizePixel = 0,
		BackgroundColor3 = T.BgCard,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 268, 0, 54),
		Position = UDim2.new(0.5, 0, 1, 60),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		ZIndex = zindex,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 10),
		},

		["UIStroke"] = {
			Color = accentColor and accentColor or T.BorderSubtle,
			Thickness = 1,
		},

		["UIScale"] = {},
	})

	-- Subtle left accent bar
	if accentColor then
		local AccentBar = Interface.New("Frame", {
			BackgroundColor3 = accentColor,
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = zindex + 1,
			Parent = NotificationTemplate,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		})
		_ = AccentBar
	end

	local ImageLabel = Interface.New("ImageLabel", {
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(0, 18, 0, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 28, 0.5, 0),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ImageColor3 = accentColor or T.TextSecondary,
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	Animations.SetFadeExpectation("In", ImageLabel, {
		BackgroundTransparency = 1,
		ImageTransparency = 0,
	})

	if image then
		if image:find("rbxasset") then
			ImageLabel.Image = image
		else
			Icons.SetIcon(ImageLabel, image)
		end
	else
		ImageLabel.Visible = false
	end

	local TextContainer = Interface.New("Frame", {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -52, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		ZIndex = zindex + 1,
		Parent = NotificationTemplate,
	})

	Interface.New("TextLabel", {
		BorderSizePixel = 0,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = T.TextPrimary,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		ZIndex = zindex + 1,
		Parent = TextContainer,
		TextWrapped = true,
		LineHeight = 1.35,
	})

	return NotificationTemplate
end

local function InternalToast(image, text, internalTime, removeCallback, toastType)
	assert(Sonner.Wrapper, "Sonner has not been initialized")
	assert(typeof(image) == "string" or image == nil, "Image must be a string or nil")
	assert(typeof(text) == "string", "Text is required!")
	assert(typeof(internalTime) == "number" or internalTime == nil, "Time must be a number or nil")

	local time = internalTime or 4.5
	local accentColor = toastType and TypeAccents[toastType] or nil

	local Notif = InternalCreateNotificationObject(500, image, text, accentColor)

	Notif.Position = UDim2.new(0.5, 0, 1, 36)
	Notif.Parent = Sonner.Wrapper

	table.insert(Sonner.Queue, Notif)

	local ScaleMultiplier = 0.91
	local RemovalQueue = {}

	for index, object in Sonner.Queue do
		if object == Notif then
			continue
		end

		object.ZIndex = 500 - (#Sonner.Queue - index)

		wax.shared.TweenService
			:Create(object.UIScale, Sonner.TweenInfo, {
				Scale = object.UIScale.Scale * ScaleMultiplier,
			})
			:Play()

		wax.shared.TweenService
			:Create(object, Sonner.TweenInfo, {
				Position = object.Position - UDim2.fromOffset(0, object.AbsoluteSize.Y * 0.32),
			})
			:Play()

		if ((#Sonner.Queue - index) + 1) >= 4 then
			Animations.FadeOut(object)
			task.delay(0.5, function()
				object:Destroy()
			end)
			table.insert(RemovalQueue, object)
		end
	end

	for _, obj in RemovalQueue do
		table.remove(Sonner.Queue, table.find(Sonner.Queue, obj))
	end

	wax.shared.TweenService
		:Create(Notif, Sonner.TweenInfo, {
			Position = UDim2.new(0.5, 0, 1, -14),
		})
		:Play()
	Animations.FadeIn(Notif)

	if removeCallback then
		task.spawn(removeCallback, Notif, time)
	else
		task.delay(time, function()
			if not table.find(Sonner.Queue, Notif) then
				return
			end
			table.remove(Sonner.Queue, table.find(Sonner.Queue, Notif))

			Animations.FadeOut(Notif, 0.3)
			wax.shared.TweenService
				:Create(Notif, Sonner.TweenInfo, {
					Position = UDim2.new(0.5, 0, 1, 60),
				})
				:Play()
			task.wait(0.45)
			Notif:Destroy()
		end)
	end
end

local function ProcessQueue()
	if Sonner.Processing then
		return
	end
	Sonner.Processing = true

	while #Sonner.PendingQueue > 0 do
		local Request = table.remove(Sonner.PendingQueue, 1)
		InternalToast(Request.image, Request.text, Request.internalTime, Request.removeCallback, Request.toastType)
		task.wait(0.45)
	end

	Sonner.Processing = false
end

local function toast(image, text, internalTime, removeCallback, toastType)
	table.insert(Sonner.PendingQueue, {
		image = image,
		text = text,
		internalTime = internalTime,
		removeCallback = removeCallback,
		toastType = toastType,
	})

	task.spawn(ProcessQueue)
end

function Sonner.info(text, internalTime)
	toast("info", text, internalTime, nil, "info")
end

function Sonner.success(text, internalTime)
	toast("circle-check", text, internalTime, nil, "success")
end

function Sonner.warning(text, internalTime)
	toast("triangle-alert", text, internalTime, nil, "warning")
end

function Sonner.error(text, internalTime)
	toast("circle-alert", text, internalTime, nil, "error")
end

function Sonner.toast(text, internalTime)
	toast(nil, text, internalTime)
end

function Sonner.promise(func, options)
	local loadingText = options.loadingText or "Loading..."
	local successText = options.successText or "Success!"
	local errorText = options.errorText or "Error!"
	local internalTime = options.time or 4.5

	toast("loader-circle", loadingText, internalTime, function(notif, time)
		local success, resultOrError = nil, nil

		local spinnerThread = task.spawn(function()
			repeat
				wax.shared.RunService.RenderStepped:Wait()

				local icon = notif:FindFirstChild("ImageLabel")
				if not icon then
					continue
				end
				icon.Rotation = (icon.Rotation + 2) % 360
			until success == false or resultOrError ~= nil
		end)

		success, resultOrError = pcall(func, function(text)
			notif.Frame.TextLabel.Text = text
		end)

		task.spawn(function()
			setthreadidentity(8)

			Animations.FadeOut(notif.ImageLabel, 0.15)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.22, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 0, 0, 0),
				})
				:Play()
			task.wait(0.15)

			if coroutine.status(spinnerThread) ~= "dead" then
				coroutine.close(spinnerThread)
			end
			notif.ImageLabel.Rotation = 0

			if success then
				Icons.SetIcon(notif.ImageLabel, "check")
				notif.ImageLabel.ImageColor3 = Interface.Theme.AccentSuccess
				local message = (
					typeof(successText) == "string" and successText
					or typeof(successText) == "function" and successText(resultOrError)
					or "Success!"
				)

				if message:match("%s") then
					notif.Frame.TextLabel.Text = string.format(message, tostring(resultOrError))
				else
					notif.Frame.TextLabel.Text = message
				end
			else
				Icons.SetIcon(notif.ImageLabel, "circle-alert")
				notif.ImageLabel.ImageColor3 = Interface.Theme.AccentError
				notif.Frame.TextLabel.Text = (
					typeof(errorText) == "string" and errorText
					or typeof(errorText) == "function" and errorText(resultOrError)
					or "Error!"
				)
			end

			Animations.FadeIn(notif.ImageLabel)
			wax.shared.TweenService
				:Create(notif.ImageLabel, TweenInfo.new(0.22, Enum.EasingStyle.Exponential), {
					Size = UDim2.new(0, 18, 0, 18),
				})
				:Play()

			task.delay(time, function()
				if not table.find(Sonner.Queue, notif) then
					return
				end
				table.remove(Sonner.Queue, table.find(Sonner.Queue, notif))

				Animations.FadeOut(notif, 0.3)
				wax.shared.TweenService
					:Create(notif, Sonner.TweenInfo, {
						Position = UDim2.new(0.5, 0, 1, 60),
					})
					:Play()

				task.wait(0.45)
				notif:Destroy()
			end)
		end)
	end)
end

function Sonner.rawtoast(options)
	local image = options.image
	local text = options.text or "No Text Provided"
	local internalTime = options.time or 4.5

	toast(image, text, internalTime)
end

function Sonner.init(wrapper)
	Sonner.Wrapper = wrapper
end

return Sonner
