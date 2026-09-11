--[[
	MidnightUI  —  a cosmetic Roblox UI library
	==========================================================================
	A reusable, draggable, tabbed panel library styled after the dark
	"internal menu" look: centred title bar, a row of big top tabs, a row of
	small sub-tabs, two scrolling content columns and a full-width footer.

	Controls: Toggle, Slider, Dropdown, Keybind, Button, Label, Divider.

	This library is PURELY VISUAL. Every control does exactly three things:
	  1. update its own appearance,
	  2. write its value into Library.Flags[flag],
	  3. call the Callback function you supply.
	There is no game logic, no character/camera code and no behaviour of any
	kind beyond the widgets themselves.

	--------------------------------------------------------------------------
	USAGE  (from a LocalScript, e.g. StarterPlayerScripts)
	--------------------------------------------------------------------------
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Library = require(ReplicatedStorage:WaitForChild("MidnightUI"))

		local Window = Library:CreateWindow({
			Title     = "Midnight Internal",
			Size      = UDim2.fromOffset(520, 470),
			ToggleKey = Enum.KeyCode.RightShift,
		})

		local Tab  = Window:AddTab("Exploits")
		local Page = Tab:AddPage("Player")

		Page.Left:AddToggle({ Text = "Option A", Flag = "OptionA", Default = true,
			Callback = function(v) print("OptionA ->", v) end })

		Page.Right:AddSlider({ Text = "Scale", Min = 1, Max = 100, Default = 1,
			Decimals = 1, Flag = "Scale" })

		Page.Right:AddKeybind({ Text = "Sprint Key", Default = Enum.KeyCode.C,
			Flag = "SprintKey" })

		Page.Bottom:AddDropdown({ Text = "Target Player",
			Options = { "No Valid Targets" }, Flag = "Target" })

	Every Add* function returns a control object with :Get(), :Set(value)
	and (for dropdowns) :SetOptions(list).

	Colours live in Library.Theme — edit them BEFORE calling CreateWindow.
	--------------------------------------------------------------------------
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local Library = {}
Library.Flags   = {}
Library.Windows = {}

Library.Theme = {
	Background   = Color3.fromRGB(22, 22, 27),
	Titlebar     = Color3.fromRGB(30, 30, 37),
	Element      = Color3.fromRGB(38, 38, 46),
	ElementHover = Color3.fromRGB(48, 48, 58),
	Border       = Color3.fromRGB(52, 52, 64),
	BorderLight  = Color3.fromRGB(72, 72, 88),
	Accent       = Color3.fromRGB(104, 100, 214),
	AccentHover  = Color3.fromRGB(118, 114, 226),
	AccentDim    = Color3.fromRGB(86, 82, 182),
	Knob         = Color3.fromRGB(158, 155, 235),
	Track        = Color3.fromRGB(96, 96, 112),
	Text         = Color3.fromRGB(228, 228, 235),
	SubText      = Color3.fromRGB(156, 156, 168),
	Dim          = Color3.fromRGB(120, 120, 132),
}

local T = Library.Theme

--==========================================================================
-- small helpers
--==========================================================================

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(radius, parent)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function stroke(color, parent, thickness)
	return new("UIStroke", {
		Color           = color or T.Border,
		Thickness       = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent          = parent,
	})
end

local function padding(parent, top, bottom, left, right)
	return new("UIPadding", {
		PaddingTop    = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft   = UDim.new(0, left or 0),
		PaddingRight  = UDim.new(0, right or 0),
		Parent        = parent,
	})
end

local function listLayout(parent, gap, horizontal)
	return new("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding       = UDim.new(0, gap or 6),
		SortOrder     = Enum.SortOrder.LayoutOrder,
		Parent        = parent,
	})
end

local function tween(inst, props, time)
	TweenService:Create(
		inst,
		TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function hoverFill(button, base, hover)
	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = hover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = base })
	end)
end

local function label(parent, text, size, color, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Text                   = text or "",
		TextSize               = size or 11,
		TextColor3             = color or T.SubText,
		TextXAlignment         = align or Enum.TextXAlignment.Left,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		Size                   = UDim2.fromScale(1, 1),
		Parent                 = parent,
	})
end

local KEY_ALIASES = {
	LeftShift = "Shift",  RightShift = "RShift",
	LeftControl = "Ctrl", RightControl = "RCtrl",
	LeftAlt = "Alt",      RightAlt = "RAlt",
	Return = "Enter",     Escape = "Esc",
	MouseButton1 = "M1",  MouseButton2 = "M2", MouseButton3 = "M3",
	Unknown = "None",
}

local function keyName(key)
	if key == nil then
		return "None"
	end
	if typeof(key) == "EnumItem" then
		return KEY_ALIASES[key.Name] or key.Name
	end
	return tostring(key)
end

--==========================================================================
-- Container  (a content column: Left / Right / Bottom)
--==========================================================================

local Container = {}
Container.__index = Container

local function newContainer(frame, window)
	return setmetatable({ Frame = frame, Window = window, _order = 0 }, Container)
end

function Container:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function Container:_row(height, name)
	return new("Frame", {
		Name                   = name or "Row",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, height),
		LayoutOrder            = self:_nextOrder(),
		Parent                 = self.Frame,
	})
end

local function setFlag(flag, value)
	if flag then
		Library.Flags[flag] = value
	end
end

--------------------------------------------------------------------------
-- Label / Divider / Spacer
--------------------------------------------------------------------------

function Container:AddLabel(options)
	if type(options) == "string" then
		options = { Text = options }
	end
	options = options or {}

	local row  = self:_row(options.Height or 14, "Label")
	local text = label(row, options.Text or "", options.TextSize or 11,
		options.Color or T.Text)

	local api = {}
	function api:SetText(value)
		text.Text = tostring(value)
	end
	return api
end

function Container:AddDivider()
	local row = self:_row(7, "Divider")
	new("Frame", {
		BackgroundColor3 = T.Border,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, 0, 0, 1),
		Position         = UDim2.new(0, 0, 0.5, 0),
		Parent           = row,
	})
end

function Container:AddSpacer(height)
	self:_row(height or 8, "Spacer")
end

--------------------------------------------------------------------------
-- Toggle  (small square checkbox + text, exactly like the reference)
--------------------------------------------------------------------------

function Container:AddToggle(options)
	options = options or {}
	local text     = options.Text or "Toggle"
	local flag     = options.Flag
	local callback = options.Callback
	local value    = options.Default and true or false

	local row = self:_row(18, "Toggle")

	local box = new("Frame", {
		BackgroundColor3 = T.Element,
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(11, 11),
		Position         = UDim2.new(0, 1, 0.5, 0),
		AnchorPoint      = Vector2.new(0, 0.5),
		Parent           = row,
	})
	corner(2, box)
	local boxStroke = stroke(T.Border, box)

	local text_ = label(row, text, 11, T.SubText)
	text_.Position = UDim2.new(0, 20, 0, 0)
	text_.Size     = UDim2.new(1, -20, 1, 0)

	local hit = new("TextButton", {
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Size                   = UDim2.fromScale(1, 1),
		Parent                 = row,
	})

	local api = {}

	local function redraw()
		if value then
			tween(box, { BackgroundColor3 = T.Accent })
			boxStroke.Color = T.AccentHover
			text_.TextColor3 = T.Text
		else
			tween(box, { BackgroundColor3 = T.Element })
			boxStroke.Color = T.Border
			text_.TextColor3 = T.SubText
		end
	end

	function api:Get()
		return value
	end

	function api:Set(newValue, silent)
		value = newValue and true or false
		setFlag(flag, value)
		redraw()
		if callback and not silent then
			callback(value)
		end
	end

	function api:Toggle()
		api:Set(not value)
	end

	hit.MouseEnter:Connect(function()
		if not value then
			text_.TextColor3 = T.Text
		end
	end)
	hit.MouseLeave:Connect(function()
		if not value then
			text_.TextColor3 = T.SubText
		end
	end)
	hit.MouseButton1Click:Connect(function()
		api:Toggle()
	end)

	api:Set(value, true)
	return api
end

--------------------------------------------------------------------------
-- Slider  (title above, thin track, tall knob, min / max under the ends)
--------------------------------------------------------------------------

function Container:AddSlider(options)
	options = options or {}
	local text      = options.Text or "Slider"
	local min       = options.Min or 0
	local max       = options.Max or 100
	local decimals  = options.Decimals or 0
	local step      = options.Step
	local flag      = options.Flag
	local callback  = options.Callback
	local showValue = options.ShowValue and true or false
	local value     = math.clamp(options.Default or min, min, max)

	local row   = self:_row(46, "Slider")
	local title = label(row, text, 11, T.SubText)
	title.Size  = UDim2.new(1, 0, 0, 13)

	local track = new("Frame", {
		BackgroundColor3 = T.Track,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 0, 0, 20),
		Size             = UDim2.new(1, 0, 0, 5),
		Parent           = row,
	})
	corner(2, track)
	stroke(T.Border, track)

	local knob = new("Frame", {
		BackgroundColor3 = T.Knob,
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(7, 14),
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.new(0, 0, 0.5, 0),
		ZIndex           = 2,
		Parent           = track,
	})
	corner(2, knob)

	local minLabel = label(row, "", 10, T.Dim)
	minLabel.Position = UDim2.new(0, 0, 0, 30)
	minLabel.Size     = UDim2.new(0.5, 0, 0, 12)

	local maxLabel = label(row, "", 10, T.Dim, Enum.TextXAlignment.Right)
	maxLabel.Position = UDim2.new(0.5, 0, 0, 30)
	maxLabel.Size     = UDim2.new(0.5, 0, 0, 12)

	local function format(number)
		return string.format("%." .. tostring(decimals) .. "f", number)
	end

	minLabel.Text = format(min)
	maxLabel.Text = format(max)

	local hit = new("TextButton", {
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Position               = UDim2.new(0, 0, 0, 14),
		Size                   = UDim2.new(1, 0, 0, 17),
		Parent                 = row,
	})

	local api = {}

	local function redraw()
		local alpha = 0
		if max > min then
			alpha = (value - min) / (max - min)
		end
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		title.Text = showValue and (text .. ": " .. format(value)) or text
	end

	function api:Get()
		return value
	end

	function api:Set(newValue, silent)
		newValue = math.clamp(tonumber(newValue) or min, min, max)
		if step and step > 0 then
			newValue = min + math.floor((newValue - min) / step + 0.5) * step
			newValue = math.clamp(newValue, min, max)
		end
		value = tonumber(format(newValue)) or newValue
		setFlag(flag, value)
		redraw()
		if callback and not silent then
			callback(value)
		end
	end

	local dragging = false

	local function updateFromX(x)
		local left  = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		local alpha = 0
		if width > 0 then
			alpha = math.clamp((x - left) / width, 0, 1)
		end
		api:Set(min + (max - min) * alpha)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, { BackgroundColor3 = T.Text }, 0.08)
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, { BackgroundColor3 = T.Knob }, 0.08)
		end
	end)

	api:Set(value, true)
	return api
end

--------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------

function Container:AddButton(options)
	options = options or {}
	local text     = options.Text or "Button"
	local callback = options.Callback

	local row = new("Frame", {
		Name                   = "Button",
		BackgroundTransparency = 1,
		Size                   = options.Width
			and UDim2.new(0, options.Width, 0, options.Height or 22)
			or  UDim2.new(1, 0, 0, options.Height or 22),
		LayoutOrder            = self:_nextOrder(),
		Parent                 = self.Frame,
	})

	local button = new("TextButton", {
		BackgroundColor3 = T.Element,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Font             = Enum.Font.Gotham,
		Text             = text,
		TextSize         = 11,
		TextColor3       = T.Text,
		Size             = UDim2.fromScale(1, 1),
		Parent           = row,
	})
	corner(3, button)
	stroke(T.Border, button)
	hoverFill(button, T.Element, T.ElementHover)

	button.MouseButton1Click:Connect(function()
		button.BackgroundColor3 = T.AccentDim
		tween(button, { BackgroundColor3 = T.Element }, 0.22)
		if callback then
			callback()
		end
	end)

	local api = {}
	function api:SetText(value)
		button.Text = tostring(value)
	end
	return api
end

--------------------------------------------------------------------------
-- Keybind  (title above, wide button that captures the next key pressed)
--------------------------------------------------------------------------

function Container:AddKeybind(options)
	options = options or {}
	local text     = options.Text or "Keybind"
	local flag     = options.Flag
	local callback = options.Callback
	local key      = options.Default

	local row   = self:_row(38, "Keybind")
	local title = label(row, text, 11, T.SubText)
	title.Size  = UDim2.new(1, 0, 0, 13)

	local button = new("TextButton", {
		BackgroundColor3 = T.Element,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Font             = Enum.Font.Gotham,
		Text             = keyName(key),
		TextSize         = 11,
		TextColor3       = T.Text,
		Position         = UDim2.new(0, 0, 0, 16),
		Size             = UDim2.new(1, 0, 0, 20),
		Parent           = row,
	})
	corner(3, button)
	stroke(T.Border, button)
	hoverFill(button, T.Element, T.ElementHover)

	local api = {}
	local listening = false
	local connection

	function api:Get()
		return key
	end

	function api:Set(newKey, silent)
		key = newKey
		setFlag(flag, key)
		button.Text = keyName(key)
		if callback and not silent then
			callback(key)
		end
	end

	button.MouseButton1Click:Connect(function()
		if listening then
			return
		end
		listening   = true
		button.Text = "..."
		button.TextColor3 = T.Knob

		connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			local chosen
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					chosen = key            -- cancel, keep the old bind
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					chosen = nil            -- clear the bind
				else
					chosen = input.KeyCode
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				chosen = input.UserInputType
			else
				return
			end

			listening = false
			button.TextColor3 = T.Text
			if connection then
				connection:Disconnect()
				connection = nil
			end
			api:Set(chosen)
		end)
	end)

	api:Set(key, true)
	return api
end

--------------------------------------------------------------------------
-- Dropdown  ( < value >  with the caption to its right, like the reference)
--------------------------------------------------------------------------

function Container:AddDropdown(options)
	options = options or {}
	local text        = options.Text or "Dropdown"
	local list        = options.Options or {}
	local flag        = options.Flag
	local callback    = options.Callback
	local placeholder = options.Placeholder or "None"
	local captionTop  = (options.LabelPosition == "Top")
	local value       = options.Default or list[1] or placeholder

	local row = self:_row(captionTop and 38 or 20, "Dropdown")

	local control = new("Frame", {
		BackgroundColor3 = T.Element,
		BorderSizePixel  = 0,
		Parent           = row,
	})
	corner(3, control)
	stroke(T.Border, control)

	local caption
	if captionTop then
		caption = label(row, text, 11, T.SubText)
		caption.Size     = UDim2.new(1, 0, 0, 13)
		control.Position = UDim2.new(0, 0, 0, 16)
		control.Size     = UDim2.new(1, 0, 0, 20)
	else
		control.Position = UDim2.new(0, 0, 0, 0)
		control.Size     = UDim2.new(options.Width and 0 or 0.62, options.Width or 0, 1, 0)
		caption = label(row, text, 11, T.SubText)
		caption.Position = UDim2.new(0, 0, 0, 0)
		caption.Size     = UDim2.new(1, 0, 1, 0)
		control:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			caption.Position = UDim2.new(0, control.AbsoluteSize.X + 9, 0, 0)
			caption.Size     = UDim2.new(1, -(control.AbsoluteSize.X + 9), 1, 0)
		end)
		caption.Position = UDim2.new(0.62, 9, 0, 0)
		caption.Size     = UDim2.new(0.38, -9, 1, 0)
	end

	local function arrow(glyph, alignRight)
		local button = new("TextButton", {
			BackgroundTransparency = 1,
			AutoButtonColor        = false,
			Font                   = Enum.Font.GothamBold,
			Text                   = glyph,
			TextSize               = 13,
			TextColor3             = T.Dim,
			Size                   = UDim2.new(0, 20, 1, 0),
			Position               = alignRight and UDim2.new(1, -20, 0, 0) or UDim2.new(0, 0, 0, 0),
			Parent                 = control,
		})
		button.MouseEnter:Connect(function()
			button.TextColor3 = T.Text
		end)
		button.MouseLeave:Connect(function()
			button.TextColor3 = T.Dim
		end)
		return button
	end

	local prev = arrow("\u{2039}", false)
	local next_ = arrow("\u{203A}", true)

	local main = new("TextButton", {
		BackgroundTransparency = 1,
		AutoButtonColor        = false,
		Font                   = Enum.Font.Gotham,
		Text                   = tostring(value),
		TextSize               = 11,
		TextColor3             = T.Text,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		Position               = UDim2.new(0, 20, 0, 0),
		Size                   = UDim2.new(1, -40, 1, 0),
		Parent                 = control,
	})

	local api = {}
	local popup

	function api:Get()
		return value
	end

	function api:Set(newValue, silent)
		value     = newValue
		main.Text = tostring(value == nil and placeholder or value)
		setFlag(flag, value)
		if callback and not silent then
			callback(value)
		end
	end

	function api:GetOptions()
		return list
	end

	local function closePopup()
		if popup then
			popup:Destroy()
			popup = nil
		end
	end

	function api:SetOptions(newList, keepSelection)
		list = newList or {}
		closePopup()
		local stillThere = false
		for _, item in ipairs(list) do
			if item == value then
				stillThere = true
				break
			end
		end
		if not (keepSelection and stillThere) then
			api:Set(list[1] or placeholder, true)
		end
	end

	local function cycle(delta)
		if #list == 0 then
			return
		end
		local index = 1
		for i, item in ipairs(list) do
			if item == value then
				index = i
				break
			end
		end
		index = ((index - 1 + delta) % #list) + 1
		api:Set(list[index])
	end

	prev.MouseButton1Click:Connect(function()
		cycle(-1)
	end)
	next_.MouseButton1Click:Connect(function()
		cycle(1)
	end)

	main.MouseButton1Click:Connect(function()
		if popup then
			closePopup()
			return
		end
		if #list == 0 then
			return
		end

		local window = self.Window
		local height = math.min(#list * 19 + 8, 152)

		popup = new("Frame", {
			Name             = "DropdownPopup",
			BackgroundColor3 = T.Titlebar,
			BorderSizePixel  = 0,
			ZIndex           = 60,
			ClipsDescendants = true,
			Position         = UDim2.fromOffset(
				main.AbsolutePosition.X,
				main.AbsolutePosition.Y + main.AbsoluteSize.Y + 3
			),
			Size             = UDim2.fromOffset(math.max(main.AbsoluteSize.X, 110), height),
			Parent           = window.Gui,
		})
		corner(4, popup)
		stroke(T.BorderLight, popup)

		local scroller = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			ScrollBarThickness     = 3,
			ScrollBarImageColor3   = T.BorderLight,
			CanvasSize             = UDim2.new(),
			Size                   = UDim2.fromScale(1, 1),
			ZIndex                 = 61,
			Parent                 = popup,
		})
		padding(scroller, 4, 4, 4, 4)
		local layout = listLayout(scroller, 2)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroller.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
		end)

		for index, item in ipairs(list) do
			local selected = (item == value)
			local option = new("TextButton", {
				BackgroundColor3       = selected and T.AccentDim or T.Element,
				BackgroundTransparency = selected and 0 or 1,
				BorderSizePixel        = 0,
				AutoButtonColor        = false,
				Font                   = Enum.Font.Gotham,
				Text                   = "  " .. tostring(item),
				TextSize               = 11,
				TextColor3             = selected and T.Text or T.SubText,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Size                   = UDim2.new(1, -4, 0, 17),
				LayoutOrder            = index,
				ZIndex                 = 62,
				Parent                 = scroller,
			})
			corner(3, option)

			option.MouseEnter:Connect(function()
				if not selected then
					option.BackgroundTransparency = 0
					option.BackgroundColor3       = T.ElementHover
					option.TextColor3             = T.Text
				end
			end)
			option.MouseLeave:Connect(function()
				if not selected then
					option.BackgroundTransparency = 1
					option.TextColor3             = T.SubText
				end
			end)
			option.MouseButton1Click:Connect(function()
				api:Set(item)
				closePopup()
			end)
		end

		-- click anywhere outside the popup to dismiss it
		local outside
		outside = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			task.defer(function()
				if not popup then
					if outside then
						outside:Disconnect()
					end
					return
				end
				local mouse = UserInputService:GetMouseLocation()
				local topLeft = popup.AbsolutePosition
				local size    = popup.AbsoluteSize
				local insidePopup =
					mouse.X >= topLeft.X and mouse.X <= topLeft.X + size.X and
					mouse.Y >= topLeft.Y and mouse.Y <= topLeft.Y + size.Y
				if not insidePopup then
					closePopup()
					if outside then
						outside:Disconnect()
						outside = nil
					end
				end
			end)
		end)
	end)

	api:Set(value, true)
	return api
end

--==========================================================================
-- Page  (one sub-tab: two scrolling columns + a full-width footer)
--==========================================================================

local function buildPage(window, parent)
	local page = new("Frame", {
		Name                   = "Page",
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Visible                = false,
		Parent                 = parent,
	})

	local columns = new("Frame", {
		Name                   = "Columns",
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Parent                 = page,
	})

	local function column(xScale, xOffset, widthScale, widthOffset)
		local scroller = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			ScrollBarThickness     = 3,
			ScrollBarImageColor3   = T.Border,
			ScrollingDirection     = Enum.ScrollingDirection.Y,
			CanvasSize             = UDim2.new(),
			Position               = UDim2.new(xScale, xOffset, 0, 0),
			Size                   = UDim2.new(widthScale, widthOffset, 1, 0),
			Parent                 = columns,
		})
		padding(scroller, 2, 6, 1, 6)
		local layout = listLayout(scroller, 6)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroller.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
		end)
		return scroller
	end

	local leftFrame  = column(0, 0, 0.45, -6)
	local rightFrame = column(0.45, 8, 0.55, -8)

	local footerFrame = new("Frame", {
		Name                   = "Footer",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0, 1),
		Position               = UDim2.new(0, 0, 1, 0),
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		Parent                 = page,
	})
	listLayout(footerFrame, 6)
	padding(footerFrame, 8, 0, 1, 1)

	footerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		columns.Size = UDim2.new(1, 0, 1, -footerFrame.AbsoluteSize.Y)
	end)

	return {
		Frame  = page,
		Left   = newContainer(leftFrame, window),
		Right  = newContainer(rightFrame, window),
		Bottom = newContainer(footerFrame, window),
	}
end

--==========================================================================
-- Tab  (one top-level tab: a row of sub-tabs + its pages)
--==========================================================================

local Tab = {}
Tab.__index = Tab

function Tab:AddPage(name)
	local page = buildPage(self.Window, self.PageHolder)
	page.Name  = name

	local entry = { Page = page, Button = nil }

	if name then
		local button = new("TextButton", {
			BackgroundColor3 = T.Element,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			Font             = Enum.Font.Gotham,
			Text             = name,
			TextSize         = 11,
			TextColor3       = T.SubText,
			AutomaticSize    = Enum.AutomaticSize.X,
			Size             = UDim2.new(0, 0, 1, 0),
			LayoutOrder      = #self._pages + 1,
			Parent           = self.SubBar,
		})
		corner(3, button)
		stroke(T.Border, button)
		padding(button, 0, 0, 9, 9)

		entry.Button = button
		button.MouseButton1Click:Connect(function()
			self:SelectPage(name)
		end)
		button.MouseEnter:Connect(function()
			if self._current ~= entry then
				tween(button, { BackgroundColor3 = T.ElementHover })
			end
		end)
		button.MouseLeave:Connect(function()
			if self._current ~= entry then
				tween(button, { BackgroundColor3 = T.Element })
			end
		end)
	else
		self.SubBar.Visible = false
		self.Divider.Visible = false
		self.PageHolder.Position = UDim2.new(0, 0, 0, 0)
		self.PageHolder.Size     = UDim2.new(1, 0, 1, 0)
	end

	table.insert(self._pages, entry)
	if #self._pages == 1 then
		self:_select(entry)
	end

	return page
end

function Tab:_select(entry)
	for _, other in ipairs(self._pages) do
		other.Page.Frame.Visible = (other == entry)
		if other.Button then
			local active = (other == entry)
			tween(other.Button, {
				BackgroundColor3 = active and T.Accent or T.Element,
				TextColor3       = active and T.Text or T.SubText,
			})
		end
	end
	self._current = entry
end

function Tab:SelectPage(name)
	for _, entry in ipairs(self._pages) do
		if entry.Page.Name == name then
			self:_select(entry)
			return
		end
	end
end

--==========================================================================
-- Window
--==========================================================================

local Window = {}
Window.__index = Window

function Window:AddTab(name)
	local holder = new("Frame", {
		Name                   = "Tab_" .. tostring(name),
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Visible                = false,
		Parent                 = self.Body,
	})

	local subBar = new("Frame", {
		Name                   = "SubBar",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 19),
		Parent                 = holder,
	})
	listLayout(subBar, 4, true)

	local divider = new("Frame", {
		Name             = "Divider",
		BackgroundColor3 = T.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 0, 0, 25),
		Size             = UDim2.new(1, 0, 0, 1),
		Parent           = holder,
	})

	local pageHolder = new("Frame", {
		Name                   = "Pages",
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 0, 0, 32),
		Size                   = UDim2.new(1, 0, 1, -32),
		Parent                 = holder,
	})

	local tab = setmetatable({
		Name       = name,
		Window     = self,
		Frame      = holder,
		SubBar     = subBar,
		Divider    = divider,
		PageHolder = pageHolder,
		_pages     = {},
	}, Tab)

	local button = new("TextButton", {
		BackgroundColor3 = T.Element,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		Font             = Enum.Font.Gotham,
		Text             = name,
		TextSize         = 12,
		TextColor3       = T.SubText,
		Size             = UDim2.fromScale(1, 1),
		LayoutOrder      = #self._tabs + 1,
		Parent           = self.TabBar,
	})
	corner(3, button)
	stroke(T.Border, button)

	local entry = { Tab = tab, Button = button }

	button.MouseButton1Click:Connect(function()
		self:SelectTab(name)
	end)
	button.MouseEnter:Connect(function()
		if self._currentTab ~= entry then
			tween(button, { BackgroundColor3 = T.ElementHover })
		end
	end)
	button.MouseLeave:Connect(function()
		if self._currentTab ~= entry then
			tween(button, { BackgroundColor3 = T.Element })
		end
	end)

	table.insert(self._tabs, entry)
	self:_layoutTabs()

	if #self._tabs == 1 then
		self:_selectTab(entry)
	end

	return tab
end

function Window:_layoutTabs()
	local count = #self._tabs
	if count == 0 then
		return
	end
	local gap = 5
	for _, entry in ipairs(self._tabs) do
		entry.Button.Size = UDim2.new(1 / count, -(gap * (count - 1)) / count, 1, 0)
	end
end

function Window:_selectTab(entry)
	for _, other in ipairs(self._tabs) do
		local active = (other == entry)
		other.Tab.Frame.Visible = active
		tween(other.Button, {
			BackgroundColor3 = active and T.Accent or T.Element,
			TextColor3       = active and T.Text or T.SubText,
		})
	end
	self._currentTab = entry
end

function Window:SelectTab(name)
	for _, entry in ipairs(self._tabs) do
		if entry.Tab.Name == name then
			self:_selectTab(entry)
			return
		end
	end
end

function Window:SetVisible(state)
	self.Root.Visible = state and true or false
end

function Window:Toggle()
	self.Root.Visible = not self.Root.Visible
end

function Window:Destroy()
	self.Gui:Destroy()
end

--==========================================================================
-- Library:CreateWindow
--==========================================================================

function Library:CreateWindow(options)
	options = options or {}

	local parent
	local player = Players.LocalPlayer
	if player then
		parent = player:WaitForChild("PlayerGui")
	else
		error("MidnightUI: CreateWindow must run in a LocalScript (no LocalPlayer found)")
	end

	local gui = new("ScreenGui", {
		Name             = options.Name or "MidnightUI",
		ResetOnSpawn     = false,
		IgnoreGuiInset   = true,
		DisplayOrder     = options.DisplayOrder or 100,
		ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
		Parent           = parent,
	})

	local size = options.Size or UDim2.fromOffset(520, 470)

	local root = new("Frame", {
		Name             = "Root",
		BackgroundColor3 = T.Background,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
		Size             = size,
		Position         = options.Position
			or UDim2.new(0.5, -math.floor(size.X.Offset / 2), 0.5, -math.floor(size.Y.Offset / 2)),
		Parent           = gui,
	})
	corner(5, root)
	stroke(T.BorderLight, root)

	-- title bar -----------------------------------------------------------
	local titleBar = new("Frame", {
		Name             = "TitleBar",
		BackgroundColor3 = T.Titlebar,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, 0, 0, 22),
		Parent           = root,
	})

	local titleText = label(titleBar, options.Title or "MidnightUI", 11, T.SubText,
		Enum.TextXAlignment.Center)
	titleText.Font = Enum.Font.GothamMedium

	new("Frame", {
		BackgroundColor3 = T.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 0, 1, -1),
		Size             = UDim2.new(1, 0, 0, 1),
		Parent           = titleBar,
	})

	-- top tab row ---------------------------------------------------------
	local tabBar = new("Frame", {
		Name                   = "TabBar",
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 8, 0, 29),
		Size                   = UDim2.new(1, -16, 0, 24),
		Parent                 = root,
	})
	listLayout(tabBar, 5, true)

	-- body ----------------------------------------------------------------
	local body = new("Frame", {
		Name                   = "Body",
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 8, 0, 60),
		Size                   = UDim2.new(1, -16, 1, -68),
		Parent                 = root,
	})

	local window = setmetatable({
		Gui      = gui,
		Root     = root,
		TitleBar = titleBar,
		TabBar   = tabBar,
		Body     = body,
		_tabs    = {},
	}, Window)

	-- dragging ------------------------------------------------------------
	do
		local dragging, dragStart, startPos = false, nil, nil

		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging  = true
				dragStart = input.Position
				startPos  = root.Position
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- show / hide key -----------------------------------------------------
	local toggleKey = options.ToggleKey
	if toggleKey ~= false then
		toggleKey = toggleKey or Enum.KeyCode.RightShift
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard
				and input.KeyCode == toggleKey then
				window:Toggle()
			end
		end)
	end

	table.insert(Library.Windows, window)
	return window
end

function Library:Destroy()
	for _, window in ipairs(Library.Windows) do
		pcall(function()
			window:Destroy()
		end)
	end
	Library.Windows = {}
end

return Library
