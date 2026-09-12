# MidnightUI

A cosmetic Roblox UI library: a draggable dark panel with a centred title bar,
a row of wide top tabs, a row of small sub-tabs, two scrolling content columns
and a full-width footer.

**It is only a UI.** Every control does exactly three things — update its own
appearance, write its value into `Library.Flags[flag]`, and call the `Callback`
you pass it. There is no game, character, camera or network logic anywhere in
the library. It is a chrome/widget kit, nothing else.

```
MidnightUI/
├── src/
│   ├── MidnightUI.lua          ModuleScript — the library
│   └── Loader.client.lua       LocalScript  — minimal client-side loader
├── internal/
│   ├── loader.client.lua       Midnight Internal entry — picks the game module
│   └── games/
│       ├── registry.lua        PlaceId → game folder mapping
│       └── arsenal/
│           └── init.lua        Arsenal-specific cheat
├── examples/
│   ├── FullDemo.client.lua     LocalScript  — every control, larger layout
│   └── Internal.client.lua     Loads Midnight Internal via the central loader
└── default.project.json        Rojo mapping
```

## Midnight Internal (multi-game)

One loader detects the current game and pulls the matching module from GitHub.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/MidnightUI/main/internal/loader.client.lua"))()
```

### Add a new game

1. Create `internal/games/<folder>/init.lua` with the game-specific script.
2. Register it in `internal/games/registry.lua`:

```lua
return {
    [286090429] = { folder = "arsenal", name = "Arsenal" },
    [123456789] = { folder = "mygame", name = "My Game" },
}
```

The loader sets `getgenv().MidnightGame` (`key`, `name`, `placeId`) before running the module.
Unsupported games show a short alert with the place id.

## Install

### Option A — Rojo (recommended)

```bash
git clone https://github.com/Proxo123/MidnightUI.git
cd MidnightUI
rojo serve            # then connect from the Rojo plugin in Studio
```

`default.project.json` puts the files where they need to be:

| File | Becomes |
|---|---|
| `src/MidnightUI.lua` | `ReplicatedStorage.MidnightUI` (ModuleScript) |
| `src/Loader.client.lua` | `StarterPlayer.StarterPlayerScripts.MidnightUILoader` (LocalScript) |

Build a one-off place file instead of serving with `rojo build -o build.rbxl`.

### Option B — by hand in Studio

1. Insert a **ModuleScript** into `ReplicatedStorage`, name it `MidnightUI`,
   paste in `src/MidnightUI.lua`.
2. Insert a **LocalScript** into `StarterPlayer > StarterPlayerScripts`, paste
   in `src/Loader.client.lua`.
3. Play. Press **RightShift** to hide / show; drag the title bar to move it.

### Option C — publish the module, load it by asset id

Useful if you want the client to pull the library from Roblox at runtime
instead of shipping it in the place file. Right-click the `MidnightUI`
ModuleScript in Studio → **Publish as Asset**, then from your LocalScript:

```lua
local Library = require(123456789)   -- your asset id
```

The module must be owned by you (or your group) and published as a Model with
`Distribute on Creator Store` enabled if other places should be able to fetch
it. This is the supported way to load Luau from a remote source on the client —
this repo deliberately ships no `loadstring` / `HttpGet` bootstrapper, since
those APIs only exist in third-party executors.

## Minimal client-side usage

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage:WaitForChild("MidnightUI"))

local Window = Library:CreateWindow({
    Title     = "Midnight Internal",
    Size      = UDim2.fromOffset(520, 470),
    ToggleKey = Enum.KeyCode.RightShift,
})

local Page = Window:AddTab("Main"):AddPage("Player")

Page.Left:AddToggle({ Text = "Example Toggle", Flag = "ExampleToggle", Default = true,
    Callback = function(value) print("toggle ->", value) end })

Page.Right:AddSlider({ Text = "Example Slider", Min = 1, Max = 100, Decimals = 1,
    ShowValue = true, Flag = "ExampleSlider" })

Page.Right:AddKeybind({ Text = "Example Bind", Default = Enum.KeyCode.C, Flag = "ExampleBind" })

Page.Bottom:AddDropdown({ Text = "Example Dropdown", Options = { "First", "Second", "Third" } })
```

`Library.Flags.ExampleToggle` is now `true`, which makes saving a config
trivial.

## API

```lua
Library:CreateWindow({
    Title, Size, Position,      -- UDim2s; Position defaults to centred
    ToggleKey,                  -- Enum.KeyCode, or false to disable the hotkey
    Scheme,                     -- "Midnight" | "Crimson" | "Emerald" | "Amber"
    OnUnload,                   -- callback when the built-in Unload button is pressed
    SettingsTab,                -- false to hide the pinned Settings tab (default true)
    DisplayOrder, Name,
})  --> Window
```

Every window gets a **Settings** tab pinned on the far right. It ships with
menu toggle keybind, colour-scheme picker, and an Unload button. Add your own
rows through `Window.Settings` (same `.Left` / `.Right` / `.Bottom` containers
as any page).

```lua
Window.Settings.Right:AddButton({ Text = "Save Config", Callback = save })
```

| Object | Methods |
|---|---|
| `Window` | `:AddTab(name)` `:SelectTab(name)` `:SetToggleKey(key)` `:ApplyScheme(name)` `:SetVisible(bool)` `:Toggle()` `:Destroy()` |
| `Tab` | `:AddPage(name)` `:SelectPage(name)` — pass `nil` as the name to hide the sub-tab row |
| `Page` | `.Left` `.Right` `.Bottom` (containers) |
| `Window.Settings` | Built-in settings page containers (always last tab) |
| `Library` | `.Flags` `.Theme` `.Windows` `:Destroy()` |

Containers accept:

```lua
c:AddToggle({   Text, Default, Flag, Callback })
c:AddSlider({   Text, Min, Max, Default, Decimals, Step, ShowValue, Flag, Callback })
c:AddDropdown({ Text, Options, Default, Placeholder, LabelPosition, Width, Flag, Callback })
c:AddKeybind({  Text, Default, Flag, Callback })
c:AddButton({   Text, Width, Height, Callback })
c:AddLabel({    Text, TextSize, Color })        -- or AddLabel("text")
c:AddDivider()
c:AddSpacer(height)
```

Each returns a handle:

| Control | Methods |
|---|---|
| Toggle | `:Get()` `:Set(bool)` `:Toggle()` |
| Slider | `:Get()` `:Set(number)` |
| Dropdown | `:Get()` `:Set(value)` `:GetOptions()` `:SetOptions(list, keepSelection)` |
| Keybind | `:Get()` `:Set(keyCode)` |
| Button / Label | `:SetText(text)` |

`LabelPosition` on a dropdown is `"Right"` (default — caption sits beside the
`‹ value ›` control) or `"Top"`.

Keybind capture: click the bind button, then press any key. **Esc** cancels,
**Backspace** clears the bind; right and middle mouse can also be bound.

## Theme

Built-in schemes: `Midnight`, `Crimson`, `Emerald`, `Amber`. Pick one at
creation with `Scheme = "Crimson"`, change it later from the Settings tab, or
call `Window:ApplyScheme("Emerald")` from code.

Edit `Library.Theme` **before** calling `CreateWindow` for full manual control:

```lua
Library.Theme.Accent     = Color3.fromRGB(104, 100, 214)   -- the purple
Library.Theme.Background = Color3.fromRGB(22, 22, 27)
```

Keys: `Background`, `Titlebar`, `Element`, `ElementHover`, `Border`,
`BorderLight`, `Accent`, `AccentHover`, `AccentDim`, `Knob`, `Track`, `Text`,
`SubText`, `Dim`.

## License

MIT — see [LICENSE](LICENSE).
