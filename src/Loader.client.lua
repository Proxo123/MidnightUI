--[[
	MidnightUI — minimal client-side loader
	=========================================================================
	A LocalScript. It loads the library from ReplicatedStorage and builds a
	small panel with one of every control.

	Where this goes:
	    ReplicatedStorage
	        MidnightUI                  <- ModuleScript (src/MidnightUI.lua)
	    StarterPlayer
	        StarterPlayerScripts
	            MidnightUILoader        <- LocalScript (this file)

	If you sync the repo with Rojo, `default.project.json` already puts both
	files in those places for you.

	Press RightShift in game to hide / show the panel.
=========================================================================]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Library = require(ReplicatedStorage:WaitForChild("MidnightUI"))

-- 1. the window --------------------------------------------------------------
local Window = Library:CreateWindow({
	Title     = "Midnight Internal",
	Size      = UDim2.fromOffset(520, 470),
	ToggleKey = Enum.KeyCode.RightShift,
})

-- 2. a tab and a sub-tab page ------------------------------------------------
local Tab  = Window:AddTab("Main")
local Page = Tab:AddPage("Player")

-- 3. controls ----------------------------------------------------------------
-- left column
Page.Left:AddToggle({
	Text     = "Example Toggle",
	Flag     = "ExampleToggle",
	Default  = true,
	Callback = function(value)
		print("toggle ->", value)
	end,
})

Page.Left:AddToggle({ Text = "Another Toggle", Flag = "AnotherToggle" })
Page.Left:AddDivider()
Page.Left:AddLabel({ Text = "Anything with a Flag lands in Library.Flags" })

-- right column
Page.Right:AddSlider({
	Text      = "Example Slider",
	Min       = 1,
	Max       = 100,
	Decimals  = 1,
	Default   = 1,
	ShowValue = true,
	Flag      = "ExampleSlider",
	Callback  = function(value)
		print("slider ->", value)
	end,
})

Page.Right:AddKeybind({
	Text     = "Example Bind",
	Default  = Enum.KeyCode.C,
	Flag     = "ExampleBind",
	Callback = function(key)
		print("bind ->", key)
	end,
})

Page.Right:AddButton({
	Text     = "Example Button",
	Callback = function()
		print("button clicked; toggle is", Library.Flags.ExampleToggle)
	end,
})

-- footer (full width)
Page.Bottom:AddDropdown({
	Text     = "Example Dropdown",
	Options  = { "First", "Second", "Third" },
	Flag     = "ExampleDropdown",
	Callback = function(value)
		print("dropdown ->", value)
	end,
})

print("[MidnightUI] loaded — press RightShift to hide / show.")
