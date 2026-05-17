local Interface = {}
local Icons = require(script.Parent.Icons)
local AssetManager = require(script.Parent.AssetManager)

local DefaultFont = AssetManager.GetCustomFont({
	Name = "Inter",
	Url = "https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/Inter.ttf",

	FallbackId = 12187365364
})

-- Helion Design Tokens
Interface.Theme = {
	-- Backgrounds
	BgPrimary   = Color3.fromRGB(10, 11, 17),
	BgSecondary = Color3.fromRGB(14, 16, 24),
	BgTertiary  = Color3.fromRGB(18, 21, 32),
	BgCard      = Color3.fromRGB(20, 23, 36),

	-- Borders
	BorderSubtle  = Color3.fromRGB(38, 44, 68),
	BorderDefault = Color3.fromRGB(52, 60, 90),
	BorderBright  = Color3.fromRGB(80, 92, 140),

	-- Text
	TextPrimary   = Color3.fromRGB(236, 240, 255),
	TextSecondary = Color3.fromRGB(148, 160, 200),
	TextMuted     = Color3.fromRGB(90, 102, 145),

	-- Accent
	AccentPrimary = Color3.fromRGB(110, 130, 255),
	AccentGlow    = Color3.fromRGB(90, 108, 220),
	AccentSuccess = Color3.fromRGB(72, 210, 145),
	AccentWarning = Color3.fromRGB(255, 185, 75),
	AccentError   = Color3.fromRGB(255, 90, 100),
	AccentInfo    = Color3.fromRGB(100, 190, 255),
}

local DefaultProperties = {
	["Frame"] = {
		BorderSizePixel = 0,
	},
	["ScrollingFrame"] = {
		BorderSizePixel = 0,
		ScrollBarImageColor3 = Color3.fromRGB(80, 92, 140),
	},
	["ImageLabel"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	},
	["ImageButton"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	},

	["TextLabel"] = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		RichText = true,
		TextColor3 = Color3.fromRGB(236, 240, 255),
	},
	["TextButton"] = {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		RichText = true,
		TextColor3 = Color3.fromRGB(236, 240, 255),
	},
	["TextBox"] = {
		BorderSizePixel = 0,
		FontFace = DefaultFont,
		ClipsDescendants = true,
		RichText = false,
		TextColor3 = Color3.fromRGB(236, 240, 255),
	},

	["UIListLayout"] = {
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
}

function Interface.New(ClassName: string, Properties: { [string | number]: any })
	local Object = Instance.new(ClassName)

	for Key, Value in pairs(DefaultProperties[ClassName] or {}) do
		if Properties and Properties[Key] ~= nil then
			continue
		end

		Object[Key] = Value
	end

	for Key, Value in pairs(Properties or {}) do
		if typeof(Value) == "table" then
			local SubObject = Interface.New(Key, Value)
			SubObject.Parent = Object

			continue
		elseif typeof(Key) ~= "string" and typeof(Value) == "Instance" then
			local SubObject = Value:Clone()
			SubObject.Parent = Object

			continue
		end

		Object[Key] = Value
	end

	return Object
end

function Interface.NewIcon(IconName: string, Properties: { [string]: any })
	local Image: ImageLabel = Interface.New("ImageLabel", Properties)
	Icons.SetIcon(Image, IconName)

	return Image
end

function Interface.HideCorner(Frame: GuiObject, Size: UDim2, Offset: Vector2): Frame
	local Hider = Interface.New("Frame", {
		AnchorPoint = Offset or Vector2.zero,
		BackgroundColor3 = Frame.BackgroundColor3,
		Position = UDim2.fromScale(Offset.X or 0, Offset.Y or 0),
		Size = Size,
		ZIndex = Frame.ZIndex,

		Parent = Frame,
	})

	return Hider
end

function Interface.GetScreenParent(): Instance
	local ScreenGui = Interface.New("ScreenGui", {})
	local HiddenUI = wax.shared.gethui()

	for _, Container in { HiddenUI, wax.shared.CoreGui } do
		if pcall(function()
			ScreenGui.Parent = Container
		end) then
			ScreenGui:Destroy()
			return Container
		end
	end

	return wax.shared.LocalPlayer:WaitForChild("PlayerGui")
end

return Interface
