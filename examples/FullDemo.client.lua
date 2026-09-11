--[[
	FullDemo.client.lua  —  rebuilds the exact layout from the reference
	screenshot using MidnightUI.

	This file is NOT part of the Rojo tree. To run it:
	  * Rojo: point "MidnightUILoader" in default.project.json at
	    examples/FullDemo.client.lua instead of src/Loader.client.lua, or
	  * by hand: paste it into a LocalScript in StarterPlayerScripts
	    (and remove the other loader so you don't get two windows).

	Nothing here does anything to the game. Every control just prints its new
	value to the output window so you can see the widgets working.

	RightShift shows / hides the panel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage:WaitForChild("MidnightUI"))

local function log(name)
	return function(value)
		print(string.format("[UI] %s = %s", name, tostring(value)))
	end
end

local Window = Library:CreateWindow({
	Title     = "Midnight Internal",
	Size      = UDim2.fromOffset(520, 470),
	ToggleKey = Enum.KeyCode.RightShift,
})

--==========================================================================
-- Tab 1 — Aimbot   (demo content)
--==========================================================================

local aimbot     = Window:AddTab("Aimbot")
local aimGeneral = aimbot:AddPage("General")

aimGeneral.Left:AddToggle({ Text = "Enable",          Flag = "AimEnable", Default = true, Callback = log("AimEnable") })
aimGeneral.Left:AddToggle({ Text = "Draw FOV Circle", Flag = "AimDrawFov", Callback = log("AimDrawFov") })
aimGeneral.Left:AddToggle({ Text = "Visible Check",   Flag = "AimVisible", Default = true, Callback = log("AimVisible") })
aimGeneral.Left:AddDivider()
aimGeneral.Left:AddToggle({ Text = "Prediction",      Flag = "AimPrediction", Callback = log("AimPrediction") })

aimGeneral.Right:AddSlider({ Text = "Field of View", Min = 0, Max = 360, Default = 90, ShowValue = true, Flag = "AimFov",    Callback = log("AimFov") })
aimGeneral.Right:AddSlider({ Text = "Smoothing",     Min = 1, Max = 20,  Default = 5, Decimals = 1, ShowValue = true, Flag = "AimSmooth", Callback = log("AimSmooth") })
aimGeneral.Right:AddDropdown({ Text = "Hit Part", LabelPosition = "Top",
	Options = { "Head", "Torso", "Nearest" }, Default = "Head", Flag = "AimPart", Callback = log("AimPart") })
aimGeneral.Right:AddKeybind({ Text = "Aim Key", Default = Enum.KeyCode.LeftAlt, Flag = "AimKey", Callback = log("AimKey") })

aimbot:AddPage("Silent")
aimbot:AddPage("Config")

--==========================================================================
-- Tab 2 — Visuals   (demo content)
--==========================================================================

local visuals  = Window:AddTab("Visuals")
local visPlayer = visuals:AddPage("Players")

visPlayer.Left:AddToggle({ Text = "Boxes",      Flag = "VisBoxes", Default = true, Callback = log("VisBoxes") })
visPlayer.Left:AddToggle({ Text = "Skeletons",  Flag = "VisSkeleton", Callback = log("VisSkeleton") })
visPlayer.Left:AddToggle({ Text = "Names",      Flag = "VisNames", Default = true, Callback = log("VisNames") })
visPlayer.Left:AddToggle({ Text = "Distance",   Flag = "VisDistance", Callback = log("VisDistance") })
visPlayer.Left:AddToggle({ Text = "Health Bar", Flag = "VisHealth", Default = true, Callback = log("VisHealth") })

visPlayer.Right:AddSlider({ Text = "Render Distance", Min = 10, Max = 1000, Default = 300, ShowValue = true, Flag = "VisDist", Callback = log("VisDist") })
visPlayer.Right:AddDropdown({ Text = "Box Style", LabelPosition = "Top",
	Options = { "Full", "Corner", "Filled" }, Flag = "VisBoxStyle", Callback = log("VisBoxStyle") })
visPlayer.Right:AddButton({ Text = "Reset Visuals", Callback = function() print("[UI] Reset Visuals clicked") end })

visuals:AddPage("World")
visuals:AddPage("Other")

--==========================================================================
-- Tab 3 — Exploits   (this is the page in the screenshot)
--==========================================================================

local exploits = Window:AddTab("Exploits")
local player   = exploits:AddPage("Player")

-- left column ------------------------------------------------------------
local leftToggles = {
	{ "Spinbot",              false },
	{ "Player Fly",           true  },
	{ "1337 Fly",             false },
	{ "1337 Fly 2",           false },
	{ "1337 Fly 3",           false },
	{ "Super Jump",           true  },
	{ "NoFall",               true  },
	{ "Sonic",                false },
	{ "Redeploy Glider",      false },
	{ "Player Speed",         true  },
	{ "Hitbox Expander",      false },
	{ "Fullbob",              false },
	{ "Head Hitbox Expander", true  },
	{ "SkinChanger [SHIFT]",  false },
	{ "Enable Stealer",       true  },
	{ "Steal Outfit",         true  },
	{ "Steal Pickaxe",        false },
}

for _, item in ipairs(leftToggles) do
	local text, default = item[1], item[2]
	player.Left:AddToggle({
		Text     = text,
		Flag     = text,
		Default  = default,
		Callback = log(text),
	})
end

-- right column -----------------------------------------------------------
player.Right:AddToggle({ Text = "Enable Charms", Flag = "EnableCharms", Callback = log("EnableCharms") })

player.Right:AddSlider({
	Text     = "Head Hitbox Scale",
	Min      = 1,
	Max      = 100,
	Decimals = 1,
	Default  = 1,
	Flag     = "HeadHitboxScale",
	Callback = log("HeadHitboxScale"),
})

player.Right:AddKeybind({ Text = "Sprint Key",     Default = Enum.KeyCode.C,         Flag = "SprintKey",    Callback = log("SprintKey") })
player.Right:AddKeybind({ Text = "NoFall Bind",    Default = Enum.KeyCode.G,         Flag = "NoFallBind",   Callback = log("NoFallBind") })
player.Right:AddKeybind({ Text = "SuperJump Bind", Default = Enum.KeyCode.LeftShift, Flag = "SuperJumpBind", Callback = log("SuperJumpBind") })

player.Right:AddButton({ Text = "Thank Bus Driver", Callback = function() print("[UI] Thank Bus Driver clicked") end })
player.Right:AddButton({ Text = "Respawn",          Callback = function() print("[UI] Respawn clicked") end })

-- footer -----------------------------------------------------------------
local targetDropdown = player.Bottom:AddDropdown({
	Text     = "Target Player",
	Options  = { "No Valid Targets" },
	Flag     = "TargetPlayer",
	Callback = log("TargetPlayer"),
})

player.Bottom:AddButton({
	Text     = "Apply Skin Changer",
	Width    = 150,
	Callback = function() print("[UI] Apply Skin Changer clicked") end,
})

-- the other sub-tabs from the screenshot, with a little demo content
local weapon = exploits:AddPage("Weapon")
weapon.Left:AddToggle({ Text = "Rapid Fire",    Flag = "RapidFire", Callback = log("RapidFire") })
weapon.Left:AddToggle({ Text = "No Spread",     Flag = "NoSpread", Callback = log("NoSpread") })
weapon.Right:AddSlider({ Text = "Fire Rate Multiplier", Min = 1, Max = 10, Decimals = 2, Default = 1, ShowValue = true, Flag = "FireRate", Callback = log("FireRate") })

local vehicle = exploits:AddPage("Vehicle")
vehicle.Left:AddToggle({ Text = "Vehicle Fly",  Flag = "VehicleFly", Callback = log("VehicleFly") })
vehicle.Left:AddToggle({ Text = "Infinite Fuel", Flag = "InfFuel", Callback = log("InfFuel") })

local other = exploits:AddPage("Other")
other.Left:AddLabel({ Text = "Nothing here yet.", Color = Color3.fromRGB(150, 150, 162) })

local developer = exploits:AddPage("Developer")
developer.Left:AddLabel({ Text = "Widget gallery", TextSize = 12 })
developer.Left:AddDivider()
developer.Left:AddToggle({ Text = "Toggle example", Default = true, Callback = log("ToggleExample") })
developer.Left:AddButton({ Text = "Button example", Callback = function() print("[UI] Button example clicked") end })
developer.Right:AddSlider({ Text = "Slider example", Min = 0, Max = 1, Decimals = 2, Step = 0.05, Default = 0.5, ShowValue = true, Callback = log("SliderExample") })
developer.Right:AddKeybind({ Text = "Keybind example", Default = Enum.KeyCode.F, Callback = log("KeybindExample") })
developer.Right:AddDropdown({ Text = "Dropdown (caption on top)", LabelPosition = "Top",
	Options = { "First", "Second", "Third" }, Callback = log("DropdownExample") })
developer.Bottom:AddDropdown({ Text = "Caption on the right", Options = { "Alpha", "Beta", "Gamma" }, Callback = log("DropdownRight") })

--==========================================================================
-- Settings tab (built-in, always pinned right)
--==========================================================================

Window.Settings.Left:AddToggle({ Text = "Show Watermark", Flag = "Watermark", Default = true, Callback = log("Watermark") })
Window.Settings.Left:AddToggle({ Text = "Show Keybinds",  Flag = "ShowBinds", Callback = log("ShowBinds") })
Window.Settings.Right:AddButton({ Text = "Save Config", Callback = function() print("[UI] Save Config clicked") end })

--==========================================================================
-- open on the page from the screenshot
--==========================================================================

Window:SelectTab("Exploits")
exploits:SelectPage("Player")

-- example of updating a dropdown's options at runtime:
-- targetDropdown:SetOptions({ "Alice", "Bob", "Carol" })
print("[UI] MidnightUI example loaded. Press RightShift to hide / show.")
