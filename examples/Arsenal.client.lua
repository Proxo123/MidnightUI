if getgenv().MidnightCheat then getgenv().MidnightCheat:Destroy(true) end

local GAMES = { [286090429] = "Arsenal" }
local gameName = GAMES[game.PlaceId]

local function showUnsupportedAlert()
    local Players = game:GetService("Players")
    local gui = Instance.new("ScreenGui")
    gui.Name = "MidnightUnsupported"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 9999
    if gethui then gui.Parent = gethui() else gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
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
    body.Text = "Midnight Internal does not support this game yet.\nPlace ID: " .. tostring(game.PlaceId)
    body.Parent = frame
    task.delay(3, function() pcall(function() gui:Destroy() end) end)
end

if not gameName then showUnsupportedAlert() return end

local GAME_HOOKS = {
    [286090429] = {
        getHealth = function(plr)
            local n = plr:FindFirstChild("NRPBS")
            local h = n and n:FindFirstChild("Health")
            if h and typeof(h.Value) == "number" then return h.Value end
            local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            return hum and hum.Health
        end,
        isAlive = function(plr)
            local char = plr.Character or workspace:FindFirstChild(plr.Name)
            if not char then return false end
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
            if not root then return false end
            if root.Position.Y < -50 then return false end
            local n = plr:FindFirstChild("NRPBS")
            if n then
                local under = n:FindFirstChild("Underbelly")
                if under and under.Value then return false end
                local h = n:FindFirstChild("Health")
                if h and typeof(h.Value) == "number" then return h.Value > 0 end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            return hum and hum.Health > 0
        end,
    },
}

local Hooks = GAME_HOOKS[game.PlaceId]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CONFIG_PATH = "MidnightInternal.json"
local ESP_DEFAULT = Color3.fromRGB(238, 238, 245)
local ESP_VISIBLE = Color3.fromRGB(255, 72, 72)
local OUTLINE = Color3.fromRGB(8, 8, 12)
local RADAR_POSITIONS = { "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Top Center", "Bottom Center", "Custom" }
local PART_CORNERS = {
    Vector3.new(-1,-1,-1), Vector3.new(-1,-1,1), Vector3.new(-1,1,-1), Vector3.new(-1,1,1),
    Vector3.new(1,-1,-1), Vector3.new(1,-1,1), Vector3.new(1,1,-1), Vector3.new(1,1,1),
}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function keyName(k) if typeof(k) == "EnumItem" then return k.Name end return "RightShift" end
local function keyFrom(name, fallback)
    fallback = fallback or Enum.KeyCode.RightShift
    if type(name) ~= "string" or name == "" then return fallback end
    return Enum.KeyCode[name] or fallback
end
local BIND_ALIASES = { M1 = "MouseButton1", M2 = "MouseButton2", M3 = "MouseButton3" }
local function bindName(bind)
    if not bind then return "None" end
    if typeof(bind) ~= "EnumItem" then return tostring(bind) end
    if bind.EnumType == Enum.UserInputType then
        if bind == Enum.UserInputType.MouseButton1 then return "M1" end
        if bind == Enum.UserInputType.MouseButton2 then return "M2" end
        if bind == Enum.UserInputType.MouseButton3 then return "M3" end
    end
    return bind.Name
end
local function bindFrom(name, fallback)
    fallback = fallback or Enum.KeyCode.E
    if type(name) ~= "string" or name == "" then return fallback end
    local resolved = BIND_ALIASES[name] or name
    local mouse = Enum.UserInputType[resolved]
    if mouse and mouse.EnumType == Enum.UserInputType then return mouse end
    return Enum.KeyCode[resolved] or fallback
end
local function isMouseBind(bind)
    return typeof(bind) == "EnumItem" and bind.EnumType == Enum.UserInputType
end
local function bindMatch(input, bind)
    if not bind or typeof(bind) ~= "EnumItem" then return false end
    if bind.EnumType == Enum.KeyCode then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind
    end
    return input.UserInputType == bind
end
local function loadConfig()
    if not (isfile and readfile and isfile(CONFIG_PATH)) then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_PATH)) end)
    if ok and type(data) == "table" then return data end
    return nil
end
local function saveConfig(payload) if writefile then pcall(function() writefile(CONFIG_PATH, HttpService:JSONEncode(payload)) end) end end

local Saved = loadConfig() or {}
local SavedAim = Saved.Aim or {}
local SavedEsp = Saved.Esp or {}
local SavedExploits = Saved.Exploits or {}
local SavedSettings = Saved.Settings or {}

local Aim = {
    Enabled = SavedAim.Enabled == true,
    Key = bindFrom(SavedAim.Key, Enum.KeyCode.E),
    Holding = false,
    FOV = tonumber(SavedAim.FOV) or 120,
    ShowFOV = SavedAim.ShowFOV ~= false,
    Visible = SavedAim.Visible == true,
    TeamCheck = SavedAim.TeamCheck ~= false,
    Part = SavedAim.Part or "Head",
    Smooth = tonumber(SavedAim.Smooth) or 5,
    Sticky = SavedAim.Sticky == true,
    ActiveTarget = nil,
    StickyTarget = nil,
}

local Esp = {
    Enabled = SavedEsp.Enabled ~= false,
    Corners = SavedEsp.Corners ~= false,
    Fill = SavedEsp.Fill ~= false,
    Health = SavedEsp.Health ~= false,
    HeadDot = SavedEsp.HeadDot ~= false,
    Skeleton = SavedEsp.Skeleton ~= false,
    Tracers = SavedEsp.Tracers == true,
    Labels = SavedEsp.Labels ~= false,
    VisibleRed = SavedEsp.VisibleRed == true,
    TeamCheck = SavedEsp.TeamCheck ~= false,
    MaxDist = tonumber(SavedEsp.MaxDist) or 2000,
    Objects = {},
}

local Radar = {
    Enabled = SavedEsp.Radar == true,
    Position = SavedEsp.RadarPosition or "Top Left",
    Range = tonumber(SavedEsp.RadarRange) or 200,
    Size = tonumber(SavedEsp.RadarSize) or 110,
    Padding = tonumber(SavedEsp.RadarPadding) or 18,
    OffsetX = tonumber(SavedEsp.RadarOffsetX) or 0,
    OffsetY = tonumber(SavedEsp.RadarOffsetY) or 0,
    CustomX = tonumber(SavedEsp.RadarCustomX) or 12,
    CustomY = tonumber(SavedEsp.RadarCustomY) or 12,
    BgAlpha = tonumber(SavedEsp.RadarBgAlpha) or 0.82,
    Crosshair = SavedEsp.RadarCrosshair ~= false,
    DotSize = tonumber(SavedEsp.RadarDotSize) or 3.5,
    Dots = {},
}

local Exploits = {
    NoSpread = SavedExploits.NoSpread == true,
    NoRecoil = SavedExploits.NoRecoil == true,
}

local Settings = { MenuKey = keyFrom(SavedSettings.MenuKey, Enum.KeyCode.RightShift), Scheme = SavedSettings.Scheme or "Midnight" }

local Library, Window, conn
local weaponDefaults, weaponConns
local FovCircle, RadarBg, RadarRing, RadarCrossH, RadarCrossV, RadarCenter

local function snapshot()
    local scheme = Settings.Scheme
    if Library and Library.Flags and Library.Flags.Midnight_Scheme then scheme = Library.Flags.Midnight_Scheme end
    local menuKey = Settings.MenuKey
    if Library and Library.Flags and Library.Flags.Midnight_MenuKey then menuKey = Library.Flags.Midnight_MenuKey end
    return {
        Aim = { Enabled = Aim.Enabled, Key = bindName(Aim.Key), FOV = Aim.FOV, ShowFOV = Aim.ShowFOV, Visible = Aim.Visible, TeamCheck = Aim.TeamCheck, Part = Aim.Part, Smooth = Aim.Smooth, Sticky = Aim.Sticky },
        Esp = {
            Enabled = Esp.Enabled, Corners = Esp.Corners, Fill = Esp.Fill, Health = Esp.Health, HeadDot = Esp.HeadDot,
            Skeleton = Esp.Skeleton, Tracers = Esp.Tracers, Labels = Esp.Labels, VisibleRed = Esp.VisibleRed,
            TeamCheck = Esp.TeamCheck, MaxDist = Esp.MaxDist, Radar = Radar.Enabled, RadarPosition = Radar.Position,
            RadarRange = Radar.Range, RadarSize = Radar.Size, RadarPadding = Radar.Padding, RadarOffsetX = Radar.OffsetX,
            RadarOffsetY = Radar.OffsetY, RadarCustomX = Radar.CustomX, RadarCustomY = Radar.CustomY,
            RadarBgAlpha = Radar.BgAlpha, RadarCrosshair = Radar.Crosshair, RadarDotSize = Radar.DotSize,
        },
        Exploits = { NoSpread = Exploits.NoSpread, NoRecoil = Exploits.NoRecoil },
        Settings = { MenuKey = keyName(menuKey), Scheme = scheme },
    }
end
local function persist() saveConfig(snapshot()) end

local ACCENT_FALLBACK = Color3.fromRGB(104, 100, 214)
local renderErrAt = 0
local weaponTick = 0
local LibraryRef

local function themeAccent()
    if LibraryRef and LibraryRef.Theme and LibraryRef.Theme.Accent then return LibraryRef.Theme.Accent end
    return ACCENT_FALLBACK
end

Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/MidnightUI/main/src/MidnightUI.lua"))()
LibraryRef = Library
Window = Library:CreateWindow({ Title = "Midnight Internal - " .. gameName, Size = UDim2.fromOffset(520, 470), ToggleKey = Settings.MenuKey, Scheme = Settings.Scheme, OnUnload = function() if getgenv().MidnightCheat then getgenv().MidnightCheat:Destroy(true) end end })
Window.Settings.Left:AddLabel("Config: " .. CONFIG_PATH)
Window.Settings.Right:AddButton({ Text = "Save Config", Callback = function() persist() end })

FovCircle = Drawing.new("Circle")
FovCircle.Thickness = 1 FovCircle.NumSides = 64 FovCircle.Filled = false FovCircle.Transparency = 1 FovCircle.Visible = false
RadarBg = Drawing.new("Square")
RadarBg.Filled = true RadarBg.Thickness = 0 RadarBg.Color = OUTLINE RadarBg.Visible = false
RadarRing = Drawing.new("Circle")
RadarRing.Filled = false RadarRing.Thickness = 1.4 RadarRing.NumSides = 48 RadarRing.Transparency = 1 RadarRing.Color = OUTLINE RadarRing.Visible = false
RadarCrossH = Drawing.new("Line")
RadarCrossH.Thickness = 1 RadarCrossH.Transparency = 0.55 RadarCrossH.Color = Color3.fromRGB(90, 90, 105) RadarCrossH.Visible = false
RadarCrossV = Drawing.new("Line")
RadarCrossV.Thickness = 1 RadarCrossV.Transparency = 0.55 RadarCrossV.Color = Color3.fromRGB(90, 90, 105) RadarCrossV.Visible = false
RadarCenter = Drawing.new("Circle")
RadarCenter.Filled = true RadarCenter.Thickness = 0 RadarCenter.NumSides = 12 RadarCenter.Radius = 3 RadarCenter.Transparency = 1 RadarCenter.Color = Color3.fromRGB(120, 200, 255) RadarCenter.Visible = false

local AimTab = Window:AddTab("Aimbot")
local AimPage = AimTab:AddPage("Combat")
AimPage.Left:AddToggle({ Text = "Enabled", Flag = "AimEnabled", Default = Aim.Enabled, Callback = function(v) Aim.Enabled = v persist() end })
AimPage.Left:AddToggle({ Text = "Show FOV", Flag = "AimShowFOV", Default = Aim.ShowFOV, Callback = function(v) Aim.ShowFOV = v persist() end })
AimPage.Left:AddToggle({ Text = "Visible Check", Flag = "AimVisible", Default = Aim.Visible, Callback = function(v) Aim.Visible = v persist() end })
AimPage.Left:AddToggle({ Text = "Team Check", Flag = "AimTeam", Default = Aim.TeamCheck, Callback = function(v) Aim.TeamCheck = v persist() end })
AimPage.Left:AddToggle({ Text = "Sticky Aim", Flag = "AimSticky", Default = Aim.Sticky, Callback = function(v) Aim.Sticky = v Aim.StickyTarget = nil persist() end })
AimPage.Right:AddKeybind({ Text = "Aim Key", Default = Aim.Key, Flag = "AimKey", Callback = function(k) Aim.Key = k persist() end })
AimPage.Right:AddSlider({ Text = "FOV", Min = 20, Max = 500, Default = Aim.FOV, Decimals = 0, ShowValue = true, Flag = "AimFOV", Callback = function(v) Aim.FOV = v persist() end })
AimPage.Right:AddSlider({ Text = "Smoothness", Min = 1, Max = 20, Default = Aim.Smooth, Decimals = 1, ShowValue = true, Flag = "AimSmooth", Callback = function(v) Aim.Smooth = v persist() end })
AimPage.Bottom:AddDropdown({ Text = "Target Part", Options = { "Head", "HeadHB", "Torso", "HumanoidRootPart" }, Default = Aim.Part, Flag = "AimPart", Callback = function(v) Aim.Part = v persist() end })

local EspTab = Window:AddTab("ESP")
local EspPage = EspTab:AddPage("Visuals")
EspPage.Left:AddToggle({ Text = "Enabled", Flag = "EspEnabled", Default = Esp.Enabled, Callback = function(v) Esp.Enabled = v persist() end })
EspPage.Left:AddToggle({ Text = "Corner Box", Flag = "EspCorners", Default = Esp.Corners, Callback = function(v) Esp.Corners = v persist() end })
EspPage.Left:AddToggle({ Text = "Box Fill", Flag = "EspFill", Default = Esp.Fill, Callback = function(v) Esp.Fill = v persist() end })
EspPage.Left:AddToggle({ Text = "Health Bar", Flag = "EspHealth", Default = Esp.Health, Callback = function(v) Esp.Health = v persist() end })
EspPage.Left:AddToggle({ Text = "Head Dot", Flag = "EspHeadDot", Default = Esp.HeadDot, Callback = function(v) Esp.HeadDot = v persist() end })
EspPage.Left:AddToggle({ Text = "Skeleton", Flag = "EspSkeleton", Default = Esp.Skeleton, Callback = function(v) Esp.Skeleton = v persist() end })
EspPage.Right:AddToggle({ Text = "Tracers", Flag = "EspTracers", Default = Esp.Tracers, Callback = function(v) Esp.Tracers = v persist() end })
EspPage.Right:AddToggle({ Text = "Labels", Flag = "EspLabels", Default = Esp.Labels, Callback = function(v) Esp.Labels = v persist() end })
EspPage.Right:AddToggle({ Text = "Red If Visible", Flag = "EspVisibleRed", Default = Esp.VisibleRed, Callback = function(v) Esp.VisibleRed = v persist() end })
EspPage.Right:AddToggle({ Text = "Team Check", Flag = "EspTeam", Default = Esp.TeamCheck, Callback = function(v) Esp.TeamCheck = v persist() end })
EspPage.Right:AddSlider({ Text = "Max Distance", Min = 100, Max = 5000, Default = Esp.MaxDist, Decimals = 0, ShowValue = true, Flag = "EspMaxDist", Callback = function(v) Esp.MaxDist = v persist() end })

local OverlayPage = EspTab:AddPage("Overlay")
OverlayPage.Left:AddToggle({ Text = "Radar", Flag = "EspRadar", Default = Radar.Enabled, Callback = function(v) Radar.Enabled = v persist() end })
OverlayPage.Left:AddToggle({ Text = "Radar Crosshair", Flag = "EspRadarCross", Default = Radar.Crosshair, Callback = function(v) Radar.Crosshair = v persist() end })
OverlayPage.Left:AddSlider({ Text = "Radar Size", Min = 70, Max = 200, Default = Radar.Size, Decimals = 0, ShowValue = true, Flag = "EspRadarSize", Callback = function(v) Radar.Size = v persist() end })
OverlayPage.Left:AddSlider({ Text = "Radar Range", Min = 50, Max = 500, Default = Radar.Range, Decimals = 0, ShowValue = true, Flag = "EspRadarRange", Callback = function(v) Radar.Range = v persist() end })
OverlayPage.Left:AddSlider({ Text = "Dot Size", Min = 2, Max = 8, Default = Radar.DotSize, Decimals = 1, ShowValue = true, Flag = "EspRadarDot", Callback = function(v) Radar.DotSize = v persist() end })
OverlayPage.Right:AddDropdown({ Text = "Radar Position", LabelPosition = "Top", Options = RADAR_POSITIONS, Default = Radar.Position, Flag = "EspRadarPos", Callback = function(v) Radar.Position = v persist() end })
OverlayPage.Right:AddSlider({ Text = "Edge Padding", Min = 0, Max = 80, Default = Radar.Padding, Decimals = 0, ShowValue = true, Flag = "EspRadarPad", Callback = function(v) Radar.Padding = v persist() end })
OverlayPage.Right:AddSlider({ Text = "Offset X", Min = -150, Max = 150, Default = Radar.OffsetX, Decimals = 0, ShowValue = true, Flag = "EspRadarOffX", Callback = function(v) Radar.OffsetX = v persist() end })
OverlayPage.Right:AddSlider({ Text = "Offset Y", Min = -150, Max = 150, Default = Radar.OffsetY, Decimals = 0, ShowValue = true, Flag = "EspRadarOffY", Callback = function(v) Radar.OffsetY = v persist() end })
OverlayPage.Bottom:AddSlider({ Text = "Custom X %", Min = 2, Max = 98, Default = Radar.CustomX, Decimals = 0, ShowValue = true, Flag = "EspRadarCustX", Callback = function(v) Radar.CustomX = v persist() end })
OverlayPage.Bottom:AddSlider({ Text = "Custom Y %", Min = 2, Max = 98, Default = Radar.CustomY, Decimals = 0, ShowValue = true, Flag = "EspRadarCustY", Callback = function(v) Radar.CustomY = v persist() end })
OverlayPage.Bottom:AddSlider({ Text = "Background Alpha", Min = 0.4, Max = 0.95, Default = Radar.BgAlpha, Decimals = 2, ShowValue = true, Flag = "EspRadarAlpha", Callback = function(v) Radar.BgAlpha = v persist() end })

local ExploitTab = Window:AddTab("Exploits")
local ExploitPage = ExploitTab:AddPage("Weapons")
ExploitPage.Left:AddToggle({ Text = "No Spread", Flag = "ExpNoSpread", Default = Exploits.NoSpread, Callback = function(v) Exploits.NoSpread = v applyWeaponExploits() persist() end })
ExploitPage.Left:AddToggle({ Text = "No Recoil", Flag = "ExpNoRecoil", Default = Exploits.NoRecoil, Callback = function(v) Exploits.NoRecoil = v applyWeaponExploits() persist() end })
ExploitPage.Right:AddLabel("Patches ReplicatedStorage.Weapons")
ExploitPage.Right:AddLabel("Spread, MaxSpread, SpreadRecovery")
ExploitPage.Right:AddLabel("RecoilControl on equipped guns")

local SPREAD_VALUES = { Spread = true, MaxSpread = true, ["Spread%"] = true }
local RECOIL_VALUES = { RecoilControl = true, Recoil = true, Kick = true }
weaponDefaults = {}
weaponConns = {}

local function rememberWeaponValue(val)
    if weaponDefaults[val] == nil then weaponDefaults[val] = val.Value end
end

local function patchWeaponValue(val)
    local name = val.Name
    if SPREAD_VALUES[name] or name == "SpreadRecovery" then
        rememberWeaponValue(val)
        if Exploits.NoSpread then
            val.Value = name == "SpreadRecovery" and 999 or 0
        else
            val.Value = weaponDefaults[val]
        end
        return
    end
    if RECOIL_VALUES[name] then
        rememberWeaponValue(val)
        if Exploits.NoRecoil then
            val.Value = 0
        else
            val.Value = weaponDefaults[val]
        end
    end
end

local function patchWeaponRoot(root)
    if not root then return end
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ValueBase") and (SPREAD_VALUES[inst.Name] or inst.Name == "SpreadRecovery" or RECOIL_VALUES[inst.Name]) then
            patchWeaponValue(inst)
        end
    end
end

function applyWeaponExploits()
    local weapons = ReplicatedStorage:FindFirstChild("Weapons")
    if weapons then
        for _, weapon in ipairs(weapons:GetChildren()) do patchWeaponRoot(weapon) end
    end
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then patchWeaponRoot(item) end
        end
    end
end

local function hookWeaponFolder(folder)
    if not folder then return end
    table.insert(weaponConns, folder.ChildAdded:Connect(function(child) task.defer(function() patchWeaponRoot(child) end) end))
    table.insert(weaponConns, folder.DescendantAdded:Connect(function(inst)
        if inst:IsA("ValueBase") and (SPREAD_VALUES[inst.Name] or inst.Name == "SpreadRecovery" or RECOIL_VALUES[inst.Name]) then
            task.defer(function() patchWeaponValue(inst) end)
        end
    end))
end

local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons") or ReplicatedStorage:WaitForChild("Weapons", 10)
hookWeaponFolder(weaponsFolder)
table.insert(weaponConns, LocalPlayer.CharacterAdded:Connect(function(char)
    table.insert(weaponConns, char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.defer(function() patchWeaponRoot(child) end) end
    end))
end))
if LocalPlayer.Character then
    table.insert(weaponConns, LocalPlayer.Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.defer(function() patchWeaponRoot(child) end) end
    end))
end
applyWeaponExploits()

local function newDraw(kind, props) local d = Drawing.new(kind) for k, v in pairs(props) do d[k] = v end return d end
local function newLines(n, thick, col) local t = {} for i = 1, n do t[i] = newDraw("Line", { Thickness = thick, Visible = false, Transparency = 1, Color = col }) end return t end
local function sameTeam(a, b) if not a.Team or not b.Team then return false end return a.Team == b.Team end
local function getChar(plr)
    if not plr then return nil end
    local char = plr.Character
    if char and char.Parent then return char end
    char = workspace:FindFirstChild(plr.Name)
    if char and char:IsA("Model") then return char end
    return nil
end
local function getRoot(plr)
    local char = getChar(plr)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end
local function getPart(plr, name)
    local char = getChar(plr) if not char then return nil end
    if name == "HeadHB" then return char:FindFirstChild("HeadHB") or char:FindFirstChild("Head") or char:FindFirstChild("FakeHead") end
    if name == "Head" then return char:FindFirstChild("HeadHB") or char:FindFirstChild("Head") or char:FindFirstChild("FakeHead") end
    if name == "Torso" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso") end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end
local function getHealth(plr) if Hooks and Hooks.getHealth then return Hooks.getHealth(plr) end local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") return hum and hum.Health end
local function alive(plr) if Hooks and Hooks.isAlive then return Hooks.isAlive(plr) end local char = plr.Character local hum = char and char:FindFirstChildOfClass("Humanoid") return char and hum and hum.Health > 0 and getRoot(plr) end
local function getAimOrigin()
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or not UserInputService.MouseEnabled then local vs = Camera.ViewportSize return Vector2.new(vs.X * 0.5, vs.Y * 0.5) end
    local m = UserInputService:GetMouseLocation() return Vector2.new(m.X, m.Y)
end
local function updateRayFilter()
    local ignore = {}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if Camera then table.insert(ignore, Camera) end
    RayParams.FilterDescendantsInstances = ignore
end
local function isVisible(plr, part)
    local char = getChar(plr)
    if not part or not char then return false end
    updateRayFilter()
    local origin = Camera.CFrame.Position
    local delta = part.Position - origin
    local hit = workspace:Raycast(origin, delta, RayParams)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(char)
end
local function espColor(plr)
    if Aim.ActiveTarget == plr then return themeAccent() end
    if Esp.VisibleRed then local part = getPart(plr, "Head") or getRoot(plr) if part and isVisible(plr, part) then return ESP_VISIBLE end end
    return ESP_DEFAULT
end
local function healthColor(ratio) return Color3.fromRGB(255 - math.floor(200 * ratio), math.floor(220 * ratio + 35), 70) end
local function getBounds(char)
    if not char then return nil end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge local ok = false
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local cf, sz = part.CFrame, part.Size * 0.5
            for _, off in ipairs(PART_CORNERS) do
                local wp = cf:PointToWorldSpace(Vector3.new(off.X * sz.X, off.Y * sz.Y, off.Z * sz.Z))
                local sp = Camera:WorldToViewportPoint(wp)
                if sp.Z > 0 then ok = true minX = math.min(minX, sp.X) minY = math.min(minY, sp.Y) maxX = math.max(maxX, sp.X) maxY = math.max(maxY, sp.Y) end
            end
        end
    end
    if not ok then return nil end return minX, minY, maxX, maxY
end
local function setLine(line, a, b, vis, col, thick, alpha) line.Visible = vis if not vis then return end line.From = a line.To = b line.Color = col line.Thickness = thick line.Transparency = alpha end
local function drawCorners(shadow, main, x, y, w, h, col)
    local l = math.clamp(math.min(w, h) * 0.22, 6, 18)
    local pairs = {{Vector2.new(x,y),Vector2.new(x+l,y),Vector2.new(x,y+l)},{Vector2.new(x+w,y),Vector2.new(x+w-l,y),Vector2.new(x+w,y+l)},{Vector2.new(x,y+h),Vector2.new(x+l,y+h),Vector2.new(x,y+h-l)},{Vector2.new(x+w,y+h),Vector2.new(x+w-l,y+h),Vector2.new(x+w,y+h-l)}}
    for i, p in ipairs(pairs) do local si = (i-1)*2+1 setLine(shadow[si],p[1],p[2],true,OUTLINE,3.2,0.35) setLine(shadow[si+1],p[1],p[3],true,OUTLINE,3.2,0.35) setLine(main[si],p[1],p[2],true,col,1.6,1) setLine(main[si+1],p[1],p[3],true,col,1.6,1) end
end
local function hideLines(lines) for _, l in ipairs(lines) do l.Visible = false end end
local SKELETON_R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local SKELETON_R6 = {
    {"Head","Torso"},{"Torso","HumanoidRootPart"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local function worldPoint(part) if not part then return nil end local sp = Camera:WorldToViewportPoint(part.Position) if sp.Z <= 0 then return nil end return Vector2.new(sp.X, sp.Y) end
local function findBone(char, name)
    if name == "Head" then return char:FindFirstChild("HeadHB") or char:FindFirstChild("Head") or char:FindFirstChild("FakeHead") end
    return char:FindFirstChild(name)
end
local function skeletonPairs(char)
    if char:FindFirstChild("UpperTorso") then return SKELETON_R15 end
    return SKELETON_R6
end
local function boneLine(char, aName, bName)
    local a, b = findBone(char, aName), findBone(char, bName)
    if not a or not b then return nil, nil end
    if (a.Position - b.Position).Magnitude > 9 then return nil, nil end
    return worldPoint(a), worldPoint(b)
end
local function makeEspObj() return { Shadow = newLines(8,3.2,OUTLINE), Corners = newLines(8,1.6,Color3.new(1,1,1)), Fill = newDraw("Square",{Filled=true,Thickness=0,Transparency=0.82,Visible=false,Color=OUTLINE}), HealthBg = newDraw("Square",{Filled=true,Thickness=0,Transparency=0.45,Visible=false,Color=OUTLINE}), HealthFill = newDraw("Square",{Filled=true,Thickness=0,Transparency=0.15,Visible=false,Color=Color3.fromRGB(80,220,120)}), HeadRing = newDraw("Circle",{Filled=false,Thickness=1.4,NumSides=24,Transparency=1,Visible=false,Color=Color3.new(1,1,1)}), HeadDot = newDraw("Circle",{Filled=true,Thickness=0,NumSides=16,Transparency=1,Visible=false,Color=Color3.new(1,1,1)}), Name = newDraw("Text",{Size=14,Center=true,Outline=true,Font=2,Transparency=1,Visible=false,Color=Color3.new(1,1,1)}), Sub = newDraw("Text",{Size=12,Center=true,Outline=true,Font=2,Transparency=1,Visible=false,Color=Color3.fromRGB(185,185,200)}), Tracer = newDraw("Line",{Thickness=1.2,Transparency=0.55,Visible=false,Color=Color3.new(1,1,1)}), Bones = newLines(20,1.1,Color3.new(1,1,1)) } end
local function hideEsp(obj) hideLines(obj.Shadow) hideLines(obj.Corners) hideLines(obj.Bones) obj.Fill.Visible=false obj.HealthBg.Visible=false obj.HealthFill.Visible=false obj.HeadRing.Visible=false obj.HeadDot.Visible=false obj.Name.Visible=false obj.Sub.Visible=false obj.Tracer.Visible=false end
local function destroyEsp(obj) for _, v in pairs(obj) do if type(v)=="table" then for _, d in ipairs(v) do pcall(function() d:Remove() end) end else pcall(function() v:Remove() end) end end end
local function validAimTarget(plr)
    if plr == LocalPlayer then return false end
    if not alive(plr) then return false end
    if Aim.TeamCheck and sameTeam(LocalPlayer, plr) then return false end
    if Aim.Visible then local part = getPart(plr, Aim.Part) or getRoot(plr) if not part or not isVisible(plr, part) then return false end end
    return true
end
local function getClosestToCrosshair()
    local origin = getAimOrigin() local best, bestPart, bestDist = nil, nil, Aim.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if validAimTarget(plr) then
            local part = getPart(plr, Aim.Part)
            if part then
                local sp = Camera:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    local dist = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                    if dist <= Aim.FOV and dist < bestDist then bestDist = dist best = plr bestPart = part end
                end
            end
        end
    end
    return best, bestPart
end
local function getScreenDist(part) local sp = Camera:WorldToViewportPoint(part.Position) if sp.Z <= 0 then return nil end return (Vector2.new(sp.X, sp.Y) - getAimOrigin()).Magnitude end
local function resolveAimTarget()
    if not Aim.Sticky then Aim.StickyTarget = nil return getClosestToCrosshair() end
    if Aim.StickyTarget and validAimTarget(Aim.StickyTarget) then
        local part = getPart(Aim.StickyTarget, Aim.Part)
        if part then local dist = getScreenDist(part) if dist and dist <= Aim.FOV then return Aim.StickyTarget, part end end
    end
    Aim.StickyTarget = nil
    local plr, part = getClosestToCrosshair()
    Aim.StickyTarget = plr
    return plr, part
end
local function getRadarCenter()
    local vs = Camera.ViewportSize
    local pad = Radar.Padding
    local half = Radar.Size * 0.5
    local ox, oy = Radar.OffsetX, Radar.OffsetY
    local cx, cy
    local pos = Radar.Position
    if pos == "Top Left" then cx, cy = half + pad, half + pad
    elseif pos == "Top Right" then cx, cy = vs.X - half - pad, half + pad
    elseif pos == "Bottom Left" then cx, cy = half + pad, vs.Y - half - pad
    elseif pos == "Bottom Right" then cx, cy = vs.X - half - pad, vs.Y - half - pad
    elseif pos == "Top Center" then cx, cy = vs.X * 0.5, half + pad
    elseif pos == "Bottom Center" then cx, cy = vs.X * 0.5, vs.Y - half - pad
    else cx, cy = vs.X * (Radar.CustomX * 0.01), vs.Y * (Radar.CustomY * 0.01) end
    return Vector2.new(cx + ox, cy + oy)
end
local function radarOffset(localRoot, targetRoot, radius)
    local delta = targetRoot.Position - localRoot.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local dist = flat.Magnitude
    if dist < 0.01 then return Vector2.new(0, 0) end
    if dist > Radar.Range then flat = flat.Unit * Radar.Range end
    local localFlat = Camera.CFrame:VectorToObjectSpace(flat)
    local scale = radius - 8
    return Vector2.new((localFlat.X / Radar.Range) * scale, (localFlat.Z / Radar.Range) * scale)
end
local function makeRadarDot() return newDraw("Circle", { Filled = true, Thickness = 0, NumSides = 12, Radius = Radar.DotSize, Transparency = 1, Visible = false, Color = ESP_DEFAULT }) end
local function hideRadar()
    RadarBg.Visible = false RadarRing.Visible = false RadarCrossH.Visible = false RadarCrossV.Visible = false RadarCenter.Visible = false
    for _, dot in pairs(Radar.Dots) do dot.Visible = false end
end
local function updateRadar()
    if not Radar.Enabled then hideRadar() return end
    local localRoot = getRoot(LocalPlayer)
    if not localRoot then hideRadar() return end
    local center = getRadarCenter()
    local radius = Radar.Size * 0.5
    RadarBg.Visible = true
    RadarBg.Transparency = Radar.BgAlpha
    RadarBg.Position = center - Vector2.new(radius, radius)
    RadarBg.Size = Vector2.new(Radar.Size, Radar.Size)
    RadarRing.Visible = true
    RadarRing.Position = center
    RadarRing.Radius = radius
    RadarRing.Color = themeAccent()
    if Radar.Crosshair then
        RadarCrossH.Visible = true
        RadarCrossH.From = center + Vector2.new(-radius + 6, 0)
        RadarCrossH.To = center + Vector2.new(radius - 6, 0)
        RadarCrossV.Visible = true
        RadarCrossV.From = center + Vector2.new(0, -radius + 6)
        RadarCrossV.To = center + Vector2.new(0, radius - 6)
    else
        RadarCrossH.Visible = false RadarCrossV.Visible = false
    end
    RadarCenter.Visible = true
    RadarCenter.Position = center
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not Radar.Dots[plr] then Radar.Dots[plr] = makeRadarDot() end
            local dot = Radar.Dots[plr]
            if alive(plr) and (not Esp.TeamCheck or not sameTeam(LocalPlayer, plr)) then
                local root = getRoot(plr)
                if root then
                    local offset = radarOffset(localRoot, root, radius)
                    if offset then
                        local pos = center + offset
                        dot.Visible = true
                        dot.Position = pos
                        dot.Color = espColor(plr)
                        local sz = Radar.DotSize
                        if Aim.ActiveTarget == plr then sz = sz + 1 end
                        dot.Radius = sz
                    else dot.Visible = false end
                else dot.Visible = false end
            else dot.Visible = false end
        end
    end
end
local function ensureEspObj(plr)
    if plr == LocalPlayer then return end
    if not Esp.Objects[plr] then Esp.Objects[plr] = makeEspObj() end
end
local function updateEsp(plr, obj)
    if not Esp.Enabled then hideEsp(obj) return end
    if Esp.TeamCheck and sameTeam(LocalPlayer, plr) then hideEsp(obj) return end
    if not alive(plr) then hideEsp(obj) return end
    local char = getChar(plr) local root = getRoot(plr)
    if not char or not root then hideEsp(obj) return end
    local hpVal = getHealth(plr) or 0 local maxHp = 100
    local n = plr:FindFirstChild("NRPBS") if n and n:FindFirstChild("MaxHealth") then maxHp = n.MaxHealth.Value end
    local dist = (root.Position - Camera.CFrame.Position).Magnitude
    if dist > Esp.MaxDist then hideEsp(obj) return end
    local minX, minY, maxX, maxY = getBounds(char) if not minX then hideEsp(obj) return end
    local pad = 3 minX, minY = minX - pad, minY - pad maxX, maxY = maxX + pad, maxY + pad
    local w, h = maxX - minX, maxY - minY if w < 4 or h < 4 then hideEsp(obj) return end
    local col = espColor(plr) local ratio = math.clamp(hpVal / math.max(maxHp, 1), 0, 1)
    if Esp.Fill then obj.Fill.Visible=true obj.Fill.Position=Vector2.new(minX,minY) obj.Fill.Size=Vector2.new(w,h) obj.Fill.Color=col obj.Fill.Transparency=0.88 else obj.Fill.Visible=false end
    if Esp.Corners then drawCorners(obj.Shadow,obj.Corners,minX,minY,w,h,col) else hideLines(obj.Shadow) hideLines(obj.Corners) end
    if Esp.Health then local barW,gap=3,5 local bx=minX-gap-barW obj.HealthBg.Visible=true obj.HealthBg.Position=Vector2.new(bx,minY) obj.HealthBg.Size=Vector2.new(barW,h) local fh=math.max(1,h*ratio) obj.HealthFill.Visible=true obj.HealthFill.Color=healthColor(ratio) obj.HealthFill.Position=Vector2.new(bx,minY+h-fh) obj.HealthFill.Size=Vector2.new(barW,fh) else obj.HealthBg.Visible=false obj.HealthFill.Visible=false end
    if Esp.HeadDot then local head=char:FindFirstChild("Head") or char:FindFirstChild("HeadHB") local hp2=worldPoint(head) if hp2 then obj.HeadDot.Visible=true obj.HeadDot.Position=hp2 obj.HeadDot.Radius=math.clamp(h*0.035,2.5,5) obj.HeadDot.Color=col obj.HeadRing.Visible=true obj.HeadRing.Position=hp2 obj.HeadRing.Radius=obj.HeadDot.Radius+2.2 obj.HeadRing.Color=OUTLINE else obj.HeadDot.Visible=false obj.HeadRing.Visible=false end else obj.HeadDot.Visible=false obj.HeadRing.Visible=false end
    if Esp.Labels then obj.Name.Visible=true obj.Name.Text=plr.DisplayName obj.Name.Color=col obj.Name.Position=Vector2.new(minX+w*0.5,minY-18) obj.Sub.Visible=true obj.Sub.Text=string.format("%dm  |  %.0f HP",math.floor(dist*0.28),hpVal) obj.Sub.Position=Vector2.new(minX+w*0.5,minY-4) else obj.Name.Visible=false obj.Sub.Visible=false end
    if Esp.Tracers then local rp=worldPoint(root) if rp then obj.Tracer.Visible=true obj.Tracer.Color=col obj.Tracer.From=Vector2.new(Camera.ViewportSize.X*0.5,Camera.ViewportSize.Y) obj.Tracer.To=rp else obj.Tracer.Visible=false end else obj.Tracer.Visible=false end
    if Esp.Skeleton then local bi=1 for _, pair in ipairs(skeletonPairs(char)) do if bi>#obj.Bones then break end local pa,pb=boneLine(char,pair[1],pair[2]) if pa and pb then setLine(obj.Bones[bi],pa,pb,true,col,1.1,0.82) bi=bi+1 end end for j=bi,#obj.Bones do obj.Bones[j].Visible=false end else hideLines(obj.Bones) end
end


for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then Esp.Objects[plr] = makeEspObj() end end
Players.PlayerAdded:Connect(function(plr) if plr ~= LocalPlayer then Esp.Objects[plr] = makeEspObj() end end)
Players.PlayerRemoving:Connect(function(plr)
    local obj = Esp.Objects[plr] if obj then destroyEsp(obj) Esp.Objects[plr] = nil end
    local dot = Radar.Dots[plr] if dot then pcall(function() dot:Remove() end) Radar.Dots[plr] = nil end
    if Aim.ActiveTarget == plr then Aim.ActiveTarget = nil end
    if Aim.StickyTarget == plr then Aim.StickyTarget = nil end
end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not bindMatch(input, Aim.Key) then return end
    if gpe and not isMouseBind(Aim.Key) then return end
    Aim.Holding = true
    if not Aim.Sticky then Aim.StickyTarget = nil end
end)
UserInputService.InputEnded:Connect(function(input)
    if not bindMatch(input, Aim.Key) then return end
    Aim.Holding = false
    Aim.ActiveTarget = nil
    Aim.StickyTarget = nil
end)
local function renderFrame()
    Camera = workspace.CurrentCamera
    if not Camera then return end
    for _, plr in ipairs(Players:GetPlayers()) do ensureEspObj(plr) end
    local origin = getAimOrigin()
    local accent = themeAccent()
    if Aim.ShowFOV and Aim.Enabled then
        FovCircle.Visible = true
        FovCircle.Position = origin
        FovCircle.Radius = Aim.FOV
        FovCircle.Color = accent
    else
        FovCircle.Visible = false
    end
    Aim.ActiveTarget = nil
    if Aim.Enabled and Aim.Holding then
        if Aim.StickyTarget and not validAimTarget(Aim.StickyTarget) then Aim.StickyTarget = nil end
        local plr, part = resolveAimTarget()
        if part and plr and validAimTarget(plr) then
            Aim.ActiveTarget = plr
            local goal = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(1 / Aim.Smooth, 0.05, 1))
        else
            Aim.StickyTarget = nil
        end
    end
    for plr, obj in pairs(Esp.Objects) do
        local ok, err = pcall(updateEsp, plr, obj)
        if not ok then
            local now = os.clock()
            if now - renderErrAt > 2 then
                renderErrAt = now
                warn("[Midnight] esp error:", plr.Name, err)
            end
        end
    end
    local okRadar, errRadar = pcall(updateRadar)
    if not okRadar then
        local now = os.clock()
        if now - renderErrAt > 2 then
            renderErrAt = now
            warn("[Midnight] radar error:", errRadar)
        end
    end
    if Exploits.NoSpread or Exploits.NoRecoil then
        local now = os.clock()
        if now - weaponTick > 0.15 then
            weaponTick = now
            pcall(applyWeaponExploits)
        end
    end
end

conn = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(renderFrame)
    if not ok then
        local now = os.clock()
        if now - renderErrAt > 2 then
            renderErrAt = now
            warn("[Midnight] render error:", err)
        end
    end
end)

local Controller = {}
function Controller:Destroy(skipLibrary)
    persist()
    if conn then conn:Disconnect() conn = nil end
    pcall(function() FovCircle:Remove() end)
    pcall(function() RadarBg:Remove() RadarRing:Remove() RadarCrossH:Remove() RadarCrossV:Remove() RadarCenter:Remove() end)
    for _, dot in pairs(Radar.Dots) do pcall(function() dot:Remove() end) end
    Radar.Dots = {}
    for _, obj in pairs(Esp.Objects) do destroyEsp(obj) end
    Esp.Objects = {}
    Aim.ActiveTarget = nil Aim.StickyTarget = nil
    if weaponConns then for _, c in ipairs(weaponConns) do pcall(function() c:Disconnect() end) end weaponConns = {} end
    if not skipLibrary and Library then Library:Destroy() end
    getgenv().MidnightCheat = nil
end
getgenv().MidnightCheat = Controller
getgenv().MidnightState = { Aim = Aim, Esp = Esp, Radar = Radar, Exploits = Exploits }
persist()
print("[Midnight] loaded for " .. gameName)
print("[Midnight] esp=" .. tostring(Esp.Enabled) .. " radar=" .. tostring(Radar.Enabled) .. " players=" .. tostring(#Players:GetPlayers() - 1))
