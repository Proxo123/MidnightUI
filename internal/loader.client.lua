if getgenv().MidnightCheat then
	getgenv().MidnightCheat:Destroy(true)
end

local VERSION = "5aa1ae0"
local REPO = "https://raw.githubusercontent.com/Proxo123/MidnightUI/" .. VERSION

local function fetch(path)
	local url = REPO .. path
	local ok, src = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or type(src) ~= "string" or src == "" then
		return nil, url
	end
	return src, url
end

local function showUnsupportedAlert(placeId)
	local Players = game:GetService("Players")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MidnightUnsupported"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 9999
	if gethui then
		gui.Parent = gethui()
	else
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.1, 0)
	frame.Size = UDim2.fromOffset(400, 96)
	frame.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UIStroke", frame).Color = Color3.fromRGB(255, 80, 90)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 90, 100)
	title.Text = "Unsupported Game"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 36)
	body.Size = UDim2.new(1, -32, 0, 48)
	body.Font = Enum.Font.Gotham
	body.TextSize = 14
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(210, 210, 220)
	body.Text = "Midnight Internal does not support this game yet.\nPlace ID: " .. tostring(placeId)
	body.Parent = frame

	task.delay(3, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

local registrySrc, registryUrl = fetch("/internal/games/registry.lua")
if not registrySrc then
	warn("[Midnight] failed to load registry:", registryUrl)
	showUnsupportedAlert(game.PlaceId)
	return
end

local registryFn = loadstring(registrySrc)
if not registryFn then
	warn("[Midnight] registry parse failed:", registryUrl)
	showUnsupportedAlert(game.PlaceId)
	return
end

local registry = registryFn()
local entry = registry[game.PlaceId]
if not entry or type(entry.folder) ~= "string" or entry.folder == "" then
	showUnsupportedAlert(game.PlaceId)
	return
end

local gameSrc, gameUrl = fetch("/internal/games/" .. entry.folder .. "/init.lua")
if not gameSrc then
	warn("[Midnight] failed to load game module:", gameUrl)
	showUnsupportedAlert(game.PlaceId)
	return
end

getgenv().MidnightGame = {
	key = entry.folder,
	name = entry.name or entry.folder,
	placeId = game.PlaceId,
}

local gameFn = loadstring(gameSrc)
if not gameFn then
	warn("[Midnight] game module parse failed:", gameUrl)
	showUnsupportedAlert(game.PlaceId)
	return
end

local ok, err = pcall(gameFn)
if not ok then
	warn("[Midnight] game module error:", err)
end
