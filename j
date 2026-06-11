local SCRIPT_NAME = "PetSquads"
local VERSION = "1.0.0"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local existing = rawget(getgenv and getgenv() or _G, "PetSquadsUI")
if existing and type(existing.Destroy) == "function" then
	pcall(existing.Destroy)
end

local env = getgenv and getgenv() or _G
local app = {
	Connections = {},
	Loops = {},
	State = {
		AutoFarm = false,
		AutoTap = false,
		AutoCollect = false,
		AutoTeleportBest = false,
		AutoRebirth = false,
		InfinitePetSpeed = false,
		AutoEgg = false,
		AutoRank = false,
		AntiAfk = false,
		TapDistance = 120,
		TapMode = "Normal",
		EggAmount = 1,
		SelectedEggId = nil,
		SelectedEggDir = nil
	},
	StatusLabels = {},
	Controls = {}
}
env.PetSquadsUI = app

local function log(...)
	print("[PetSquads]", ...)
end

local function warnLog(...)
	warn("[PetSquads]", ...)
end

local function connect(signal, fn)
	local ok, conn = pcall(function()
		return signal:Connect(fn)
	end)
	if ok and conn then
		table.insert(app.Connections, conn)
		return conn
	end
	return nil
end

local function safeCall(name, fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		warnLog(name .. " failed:", a)
		return nil
	end
	return a, b, c
end

local function waitFor(pathRoot, ...)
	local current = pathRoot
	for _, name in ipairs({ ... }) do
		current = current and current:WaitForChild(name, 10)
		if not current then
			return nil
		end
	end
	return current
end

local Library = waitFor(ReplicatedStorage, "Library")
local Client = Library and waitFor(Library, "Client")
local DirectoryModule = Library and Library:FindFirstChild("Directory")
local Types = Library and Library:FindFirstChild("Types")

local Modules = {}

local function requireModule(label, instance)
	if not instance then
		warnLog("Missing module:", label)
		return nil
	end
	local ok, result = pcall(require, instance)
	if not ok then
		warnLog("Require failed:", label, result)
		return nil
	end
	return result
end

if Library and Client then
	Modules.Directory = requireModule("Directory", DirectoryModule)
	Modules.Save = requireModule("Client.Save", Client:FindFirstChild("Save"))
	Modules.Network = requireModule("Client.Network", Client:FindFirstChild("Network"))
	Modules.AutoFarmCmds = requireModule("Client.AutoFarmCmds", Client:FindFirstChild("AutoFarmCmds"))
	Modules.EggCmds = requireModule("Client.EggCmds", Client:FindFirstChild("EggCmds"))
	Modules.HatchingCmds = requireModule("Client.HatchingCmds", Client:FindFirstChild("HatchingCmds"))
	Modules.ZoneCmds = requireModule("Client.ZoneCmds", Client:FindFirstChild("ZoneCmds"))
	Modules.RebirthCmds = requireModule("Client.RebirthCmds", Client:FindFirstChild("RebirthCmds"))
	Modules.TeleportMapCmds = requireModule("Client.TeleportMapCmds", Client:FindFirstChild("TeleportMapCmds"))
	Modules.QuestCmds = requireModule("Client.QuestCmds", Client:FindFirstChild("QuestCmds"))
	Modules.BreakableCmds = requireModule("Client.BreakableCmds", Client:FindFirstChild("BreakableCmds"))
	Modules.MapCmds = requireModule("Client.MapCmds", Client:FindFirstChild("MapCmds"))
	Modules.PlayerPet = requireModule("Client.PlayerPet", Client:FindFirstChild("PlayerPet"))
	Modules.HatchingTypes = Types and requireModule("Types.Hatching", Types:FindFirstChild("Hatching")) or nil
	Modules.QuestTypes = Types and requireModule("Types.Quests", Types:FindFirstChild("Quests")) or nil
end

local function getSave()
	if not Modules.Save or type(Modules.Save.Get) ~= "function" then
		return nil
	end
	return Modules.Save.Get()
end

local function setStatus(key, text)
	local label = app.StatusLabels[key]
	if label then
		label.Text = text
	end
end

local function startLoop(name, delayTime, fn)
	if app.Loops[name] then
		return
	end
	app.Loops[name] = true
	task.spawn(function()
		while app.Loops[name] do
			local ok, err = pcall(fn)
			if not ok then
				warnLog(name .. " loop error:", err)
			end
			task.wait(delayTime)
		end
	end)
end

local function stopLoop(name)
	app.Loops[name] = nil
end

local function stopAllLoops()
	for name in pairs(app.Loops) do
		app.Loops[name] = nil
	end
end

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", {
	Name = "PetSquadsUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PlayerGui)
app.Gui = gui

local openButton = make("TextButton", {
	Name = "OpenClose",
	Position = UDim2.fromOffset(18, 180),
	Size = UDim2.fromOffset(42, 34),
	BackgroundColor3 = Color3.fromRGB(42, 93, 150),
	BorderSizePixel = 0,
	Text = "PS",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(245, 248, 255)
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, openButton)
make("UIStroke", { Color = Color3.fromRGB(80, 135, 195), Thickness = 1, Transparency = 0.15 }, openButton)

local main = make("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 380),
	BackgroundColor3 = Color3.fromRGB(18, 20, 26),
	BorderSizePixel = 0
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, main)
make("UIStroke", { Color = Color3.fromRGB(70, 78, 94), Thickness = 1, Transparency = 0.25 }, main)

local titleBar = make("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundColor3 = Color3.fromRGB(25, 28, 36),
	BorderSizePixel = 0
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, titleBar)

make("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
	Text = "Pet Squads",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(238, 242, 250),
	TextXAlignment = Enum.TextXAlignment.Left
}, titleBar)

make("TextLabel", {
	Name = "Version",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -52, 0, 0),
	Size = UDim2.fromOffset(58, 46),
	BackgroundTransparency = 1,
	Text = "v" .. VERSION,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(135, 145, 164),
	TextXAlignment = Enum.TextXAlignment.Right
}, titleBar)

local closeButton = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = Color3.fromRGB(40, 45, 58),
	BorderSizePixel = 0,
	Text = "X",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(240, 245, 255)
}, titleBar)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeButton)

local side = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.fromOffset(140, 334),
	BackgroundColor3 = Color3.fromRGB(20, 23, 30),
	BorderSizePixel = 0
}, main)
make("UIListLayout", {
	Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder
}, side)
make("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10)
}, side)

local content = make("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(140, 46),
	Size = UDim2.new(1, -140, 1, -46),
	BackgroundTransparency = 1
}, main)

local pages = {}
local tabButtons = {}

local function resizeCanvas(scroller)
	local layout = scroller:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18)
	end
end

local function createPage(name)
	local page = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		Visible = false
	}, content)
	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder
	}, page)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14)
	}, page)
	connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		resizeCanvas(page)
	end)
	pages[name] = page
	return page
end

local function switchTab(name)
	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end
	for tabName, button in pairs(tabButtons) do
		button.BackgroundColor3 = tabName == name and Color3.fromRGB(54, 116, 181) or Color3.fromRGB(31, 36, 48)
	end
end

local function createTab(name)
	local button = make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(31, 36, 48),
		BorderSizePixel = 0,
		Text = name,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(238, 242, 250)
	}, side)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	tabButtons[name] = button
	connect(button.MouseButton1Click, function()
		switchTab(name)
	end)
	return createPage(name)
end

local function row(parent)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(25, 29, 38),
		BorderSizePixel = 0
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, frame)
	make("UIStroke", { Color = Color3.fromRGB(48, 55, 70), Thickness = 1, Transparency = 0.45 }, frame)
	return frame
end

local function section(parent, text)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 185, 205),
		TextXAlignment = Enum.TextXAlignment.Left
	}, parent)
end

local function createToggle(parent, label, initial, callback)
	local frame = row(parent)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -92, 1, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(230, 235, 244),
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(62, 28),
		BackgroundColor3 = initial and Color3.fromRGB(55, 153, 102) or Color3.fromRGB(77, 84, 100),
		BorderSizePixel = 0,
		Text = initial and "ON" or "OFF",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	local value = initial
	local function setValue(nextValue, silent)
		value = nextValue == true
		button.Text = value and "ON" or "OFF"
		button.BackgroundColor3 = value and Color3.fromRGB(55, 153, 102) or Color3.fromRGB(77, 84, 100)
		if not silent then
			callback(value)
		end
	end
	connect(button.MouseButton1Click, function()
		setValue(not value)
	end)
	return {
		Set = setValue,
		Get = function()
			return value
		end
	}
end

local function createButton(parent, label, callback)
	local button = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(42, 93, 150),
		BorderSizePixel = 0,
		Text = label,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(245, 248, 255)
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, button)
	connect(button.MouseButton1Click, function()
		safeCall(label, callback)
	end)
	return button
end

local function createInput(parent, label, defaultValue, callback)
	local frame = row(parent)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -126, 1, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(230, 235, 244),
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	local box = make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(86, 28),
		BackgroundColor3 = Color3.fromRGB(36, 42, 55),
		BorderSizePixel = 0,
		Text = tostring(defaultValue),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(245, 248, 255),
		ClearTextOnFocus = false
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
	connect(box.FocusLost, function()
		local number = tonumber(box.Text)
		if not number then
			box.Text = tostring(defaultValue)
			return
		end
		callback(number, box)
	end)
	return box
end

local function createDropdown(parent, label, values, selected, callback)
	local frame = row(parent)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -148, 1, 0),
		BackgroundTransparency = 1,
		Text = label,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(230, 235, 244),
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	local index = 1
	for i, value in ipairs(values) do
		if value == selected then
			index = i
			break
		end
	end
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(112, 28),
		BackgroundColor3 = Color3.fromRGB(36, 42, 55),
		BorderSizePixel = 0,
		Text = tostring(values[index] or ""),
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(245, 248, 255)
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	connect(button.MouseButton1Click, function()
		index += 1
		if index > #values then
			index = 1
		end
		button.Text = tostring(values[index])
		callback(values[index])
	end)
	return {
		SetValues = function(nextValues, nextSelected)
			values = nextValues
			index = 1
			for i, value in ipairs(values) do
				if value == nextSelected then
					index = i
					break
				end
			end
			button.Text = tostring(values[index] or "")
		end,
		Get = function()
			return values[index]
		end
	}
end

local function createStatus(parent, key, text)
	local label = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(145, 158, 178),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top
	}, parent)
	app.StatusLabels[key] = label
	return label
end

local function getCharacterRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getCurrentZone()
	if Modules.MapCmds and type(Modules.MapCmds.GetCurrentZone) == "function" then
		return safeCall("GetCurrentZone", Modules.MapCmds.GetCurrentZone)
	end
	return nil
end

local function getBestOwnedZone()
	if Modules.ZoneCmds and type(Modules.ZoneCmds.GetMaxOwnedZone) == "function" then
		local zoneId = safeCall("GetMaxOwnedZone", Modules.ZoneCmds.GetMaxOwnedZone)
		return zoneId
	end
	return nil
end

local function teleportZone(zoneId)
	if not zoneId then
		return false
	end
	if Modules.TeleportMapCmds and type(Modules.TeleportMapCmds.TeleportZones) == "function" then
		return safeCall("TeleportZones", Modules.TeleportMapCmds.TeleportZones, zoneId)
	end
	return false
end

local function findNearbyBreakables()
	local out = {}
	local root = getCharacterRoot()
	if not root then
		return out
	end
	local currentZone = getCurrentZone() or getBestOwnedZone()
	if Modules.BreakableCmds and currentZone then
		for _, class in ipairs({ "Normal", "Chest" }) do
			local list = nil
			if type(Modules.BreakableCmds.AllByZoneAndClass) == "function" then
				list = safeCall("AllByZoneAndClass", Modules.BreakableCmds.AllByZoneAndClass, currentZone, class)
			elseif type(Modules.BreakableCmds.LegacyAllByZoneAndClass) == "function" then
				list = safeCall("LegacyAllByZoneAndClass", Modules.BreakableCmds.LegacyAllByZoneAndClass, currentZone, class)
			end
			if type(list) == "table" then
				for _, breakable in pairs(list) do
					local model = breakable.model or breakable.Model
					local pivot = nil
					if typeof(model) == "Instance" and model:IsA("Model") then
						pivot = model:GetPivot().Position
					elseif typeof(model) == "Instance" and model:IsA("BasePart") then
						pivot = model.Position
					end
					if pivot and (pivot - root.Position).Magnitude <= app.State.TapDistance then
						table.insert(out, breakable)
					end
				end
			end
		end
	end
	return out
end

local function damageBreakables()
	if not Modules.Network or type(Modules.Network.UnreliableFire) ~= "function" then
		return
	end
	local maxHits = app.State.TapMode == "Extreme" and 10 or 3
	local sent = 0
	for _, breakable in ipairs(findNearbyBreakables()) do
		local uid = breakable.uid or breakable.UID or breakable.id or breakable.Id
		if uid then
			Modules.Network.UnreliableFire("Breakables_PlayerDealDamage", uid)
			sent += 1
			if sent >= maxHits then
				break
			end
		end
	end
	setStatus("Farm", sent > 0 and ("Tapped " .. sent .. " breakables") or "Auto tap ready")
end

local function collectOrbs()
	if not Modules.Network or type(Modules.Network.Fire) ~= "function" then
		return
	end
	local folder = workspace:FindFirstChild("__THINGS")
	folder = folder and folder:FindFirstChild("Orbs")
	if not folder then
		return
	end
	local batch = {}
	for _, child in ipairs(folder:GetChildren()) do
		table.insert(batch, child.Name)
		if #batch >= 80 then
			break
		end
	end
	if #batch > 0 then
		Modules.Network.Fire("Orbs: Collect", batch)
		setStatus("Farm", "Collecting " .. #batch .. " drops")
	end
end

local function applyPetSpeed()
	if not app.State.InfinitePetSpeed then
		return
	end
	local PlayerPet = Modules.PlayerPet
	if not PlayerPet or type(PlayerPet.GetByPlayer) ~= "function" then
		return
	end
	local pets = PlayerPet.GetByPlayer(LocalPlayer)
	if type(pets) ~= "table" then
		return
	end
	for _, pet in pairs(pets) do
		pcall(function()
			pet.speedMult = 250
			if pet.cpet and type(pet.cpet.Broadcast) == "function" then
				pet.cpet:Broadcast("petSpeedMult", pet.speedMult)
			end
		end)
	end
end

local function autoRebirth()
	if not Modules.RebirthCmds or type(Modules.RebirthCmds.GetNextRebirth) ~= "function" or type(Modules.RebirthCmds.Rebirth) ~= "function" then
		return
	end
	local nextRebirth = Modules.RebirthCmds.GetNextRebirth()
	if nextRebirth then
		local ok = Modules.RebirthCmds.Rebirth(nextRebirth.RebirthNumber)
		if ok then
			setStatus("Farm", "Rebirth requested")
		end
	end
end

local function getEggList()
	local Directory = Modules.Directory
	local EggCmds = Modules.EggCmds
	local eggs = {}
	if not Directory or not Directory.Eggs then
		return eggs
	end
	for id, dir in pairs(Directory.Eggs) do
		local include = dir.eggNumber ~= nil
		if include and EggCmds and type(EggCmds.IsEggAvailable) == "function" then
			include = EggCmds.IsEggAvailable(id)
		end
		if include then
			table.insert(eggs, { Id = id, Dir = dir, Label = tostring(id) })
		end
	end
	table.sort(eggs, function(a, b)
		local an = tonumber(a.Dir.eggNumber) or 999999
		local bn = tonumber(b.Dir.eggNumber) or 999999
		if an == bn then
			return a.Id < b.Id
		end
		return an < bn
	end)
	return eggs
end

local function refreshSelectedEgg()
	local eggs = getEggList()
	app.EggList = eggs
	if not app.State.SelectedEggId and eggs[1] then
		app.State.SelectedEggId = eggs[1].Id
		app.State.SelectedEggDir = eggs[1].Dir
	end
	local labels = {}
	for _, egg in ipairs(eggs) do
		table.insert(labels, egg.Label)
	end
	if app.Controls.EggDropdown then
		app.Controls.EggDropdown.SetValues(labels, app.State.SelectedEggId)
	end
	setStatus("Eggs", app.State.SelectedEggId and ("Selected: " .. app.State.SelectedEggId) or "No available eggs found")
end

local function setEggByLabel(label)
	for _, egg in ipairs(app.EggList or getEggList()) do
		if egg.Label == label then
			app.State.SelectedEggId = egg.Id
			app.State.SelectedEggDir = egg.Dir
			setStatus("Eggs", "Selected: " .. egg.Id)
			return
		end
	end
end

local function cappedEggAmount(amount)
	local maxHatch = 1
	if Modules.EggCmds and type(Modules.EggCmds.GetMaxHatch) == "function" then
		maxHatch = Modules.EggCmds.GetMaxHatch(app.State.SelectedEggDir)
	end
	amount = math.floor(math.clamp(tonumber(amount) or 1, 1, maxHatch))
	return amount, maxHatch
end

local function buySelectedEgg()
	if not app.State.SelectedEggId or not Modules.EggCmds or type(Modules.EggCmds.RequestPurchase) ~= "function" then
		return false
	end
	local amount = cappedEggAmount(app.State.EggAmount)
	app.State.EggAmount = amount
	local ok, reason = Modules.EggCmds.RequestPurchase(app.State.SelectedEggId, amount)
	if ok then
		setStatus("Eggs", "Purchased " .. amount .. " " .. app.State.SelectedEggId)
	else
		setStatus("Eggs", reason and tostring(reason) or "Egg purchase failed")
	end
	return ok
end

local function autoHatchSelectedEgg()
	local Hatching = Modules.HatchingTypes
	if Modules.HatchingCmds and Hatching and Hatching.Options and Hatching.Options.AUTO then
		pcall(function()
			Modules.HatchingCmds.SetupEgg(app.State.SelectedEggDir, app.State.EggAmount)
			Modules.HatchingCmds.Enable(Hatching.Options.AUTO)
			Modules.HatchingCmds.AttemptHatch()
		end)
	else
		buySelectedEgg()
	end
end

local function findEggZone()
	local dir = app.State.SelectedEggDir
	if not dir then
		return nil
	end
	local zoneNumber = dir.zoneNumber or dir.ZoneNumber or dir.fromZoneNumber
	if not zoneNumber and dir.eggNumber then
		zoneNumber = dir.eggNumber
	end
	local Directory = Modules.Directory
	if Directory and Directory.Zones then
		for zoneId, zoneDir in pairs(Directory.Zones) do
			if zoneDir.ZoneNumber == zoneNumber or zoneId == dir.zone or zoneId == dir.Zone or zoneId == dir.ZoneID then
				return zoneId
			end
		end
	end
	return nil
end

local function teleportToEggZone()
	local zoneId = findEggZone()
	if zoneId then
		teleportZone(zoneId)
		setStatus("Eggs", "Teleporting to " .. tostring(zoneId))
	else
		setStatus("Eggs", "No zone found for selected egg")
	end
end

local supportedRankGoals = {}

local function supportsGoal(goal)
	local Quests = Modules.QuestTypes and Modules.QuestTypes.Goals
	if not Quests or type(goal) ~= "table" then
		return false
	end
	return goal.Type == Quests.EGG
		or goal.Type == Quests.BEST_EGG
		or goal.Type == Quests.HATCH_CUSTOM_EGG
		or goal.Type == Quests.BREAKABLE
		or goal.Type == Quests.CURRENT_BREAKABLE
		or goal.Type == Quests.CURRENCY
		or goal.Type == Quests.OBTAIN_CURRENCY
		or goal.Type == Quests.COLLECT_LOOTBAG
		or goal.Type == Quests.DIAMOND_BREAKABLE
end

local function handleAutoRank()
	local save = getSave()
	if not save or type(save.Goals) ~= "table" then
		setStatus("Rank", "Waiting for goals")
		return
	end
	local Quests = Modules.QuestTypes and Modules.QuestTypes.Goals
	if not Quests then
		setStatus("Rank", "Quest types unavailable")
		return
	end
	local supported = 0
	local active = nil
	for _, goal in pairs(save.Goals) do
		if type(goal) == "table" and (goal.Progress or 0) < (goal.Amount or 1) and supportsGoal(goal) then
			supported += 1
			active = active or goal
		end
	end
	if not active then
		setStatus("Rank", "No supported active rank goals")
		return
	end
	if active.Type == Quests.EGG or active.Type == Quests.BEST_EGG or active.Type == Quests.HATCH_CUSTOM_EGG then
		if active.EggID and Modules.Directory and Modules.Directory.Eggs and Modules.Directory.Eggs[active.EggID] then
			app.State.SelectedEggId = active.EggID
			app.State.SelectedEggDir = Modules.Directory.Eggs[active.EggID]
		end
		autoHatchSelectedEgg()
	else
		if Modules.AutoFarmCmds and type(Modules.AutoFarmCmds.Enable) == "function" then
			Modules.AutoFarmCmds.Enable()
		end
		damageBreakables()
		collectOrbs()
	end
	setStatus("Rank", "Working supported goals: " .. supported)
end

local autoFarmPage = createTab("Auto Farm")
local eggPage = createTab("Eggs")
local rankPage = createTab("Auto Rank")
local settingsPage = createTab("Settings")

section(autoFarmPage, "Farming")
app.Controls.AutoFarm = createToggle(autoFarmPage, "Auto Farm", false, function(value)
	app.State.AutoFarm = value
	if Modules.AutoFarmCmds then
		if value and type(Modules.AutoFarmCmds.Enable) == "function" then
			Modules.AutoFarmCmds.Enable()
		elseif not value and type(Modules.AutoFarmCmds.Disable) == "function" then
			Modules.AutoFarmCmds.Disable()
		end
	end
end)
app.Controls.AutoTap = createToggle(autoFarmPage, "Auto Farm/Tap", false, function(value)
	app.State.AutoTap = value
	if value then
		startLoop("AutoTap", app.State.TapMode == "Extreme" and 0.08 or 0.18, damageBreakables)
	else
		stopLoop("AutoTap")
	end
end)
createInput(autoFarmPage, "Auto Farm/Tap Distance", app.State.TapDistance, function(value, box)
	app.State.TapDistance = math.floor(math.clamp(value, 10, 1000))
	box.Text = tostring(app.State.TapDistance)
end)
createDropdown(autoFarmPage, "Tap Mode", { "Normal", "Extreme" }, app.State.TapMode, function(value)
	app.State.TapMode = value
	if app.State.AutoTap then
		stopLoop("AutoTap")
		startLoop("AutoTap", value == "Extreme" and 0.08 or 0.18, damageBreakables)
	end
end)
app.Controls.AutoCollect = createToggle(autoFarmPage, "Auto Collect Drops", false, function(value)
	app.State.AutoCollect = value
	if value then
		startLoop("AutoCollect", 0.35, collectOrbs)
	else
		stopLoop("AutoCollect")
	end
end)
if Modules.PlayerPet and type(Modules.PlayerPet.GetByPlayer) == "function" then
	app.Controls.InfinitePetSpeed = createToggle(autoFarmPage, "Infinite Pet Speed", false, function(value)
		app.State.InfinitePetSpeed = value
		if value then
			startLoop("PetSpeed", 0.5, applyPetSpeed)
		else
			stopLoop("PetSpeed")
		end
	end)
end
section(autoFarmPage, "Travel")
app.Controls.AutoTeleportBest = createToggle(autoFarmPage, "Auto Teleport To Best Area", false, function(value)
	app.State.AutoTeleportBest = value
	if value then
		startLoop("AutoTeleportBest", 5, function()
			teleportZone(getBestOwnedZone())
		end)
	else
		stopLoop("AutoTeleportBest")
	end
end)
app.Controls.AutoRebirth = createToggle(autoFarmPage, "Auto Rebirth", false, function(value)
	app.State.AutoRebirth = value
	if value then
		startLoop("AutoRebirth", 4, autoRebirth)
	else
		stopLoop("AutoRebirth")
	end
end)
createStatus(autoFarmPage, "Farm", "Ready")

section(eggPage, "Eggs")
local eggLabels = {}
for _, egg in ipairs(getEggList()) do
	table.insert(eggLabels, egg.Label)
end
app.Controls.EggDropdown = createDropdown(eggPage, "Select Egg", eggLabels, eggLabels[1], setEggByLabel)
createInput(eggPage, "Select Egg Amount", app.State.EggAmount, function(value, box)
	local amount, maxHatch = cappedEggAmount(value)
	app.State.EggAmount = amount
	box.Text = tostring(amount)
	setStatus("Eggs", "Amount capped at " .. amount .. " / " .. maxHatch)
end)
createButton(eggPage, "Teleport To Egg Zone", teleportToEggZone)
createButton(eggPage, "Buy Selected Egg Once", buySelectedEgg)
app.Controls.AutoEgg = createToggle(eggPage, "Auto Buy Selected Egg", false, function(value)
	app.State.AutoEgg = value
	if value then
		startLoop("AutoEgg", 2.6, autoHatchSelectedEgg)
	else
		stopLoop("AutoEgg")
		if Modules.HatchingCmds and Modules.HatchingTypes and Modules.HatchingTypes.Options then
			pcall(function()
				Modules.HatchingCmds.ForceDisable(Modules.HatchingTypes.Options.AUTO)
			end)
		end
	end
end)
createButton(eggPage, "Refresh Egg List", refreshSelectedEgg)
createStatus(eggPage, "Eggs", "Ready")
refreshSelectedEgg()

section(rankPage, "Supported Rank Goals")
app.Controls.AutoRank = createToggle(rankPage, "Auto Rank", false, function(value)
	app.State.AutoRank = value
	if value then
		startLoop("AutoRank", 2, handleAutoRank)
	else
		stopLoop("AutoRank")
	end
end)
createStatus(rankPage, "Rank", "Supports hatch, best egg, breakable, currency, and lootbag goals.")

section(settingsPage, "Interface")
createButton(settingsPage, "Close UI", function()
	main.Visible = false
end)
createButton(settingsPage, "Destroy UI", function()
	app.Destroy()
end)
app.Controls.AntiAfk = createToggle(settingsPage, "Anti AFK", false, function(value)
	app.State.AntiAfk = value
end)
createStatus(settingsPage, "Settings", "RightShift toggles the UI.")

local dragging = false
local dragStart = nil
local startPos = nil
connect(titleBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
connect(titleBar.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
connect(closeButton.MouseButton1Click, function()
	main.Visible = false
end)
connect(openButton.MouseButton1Click, function()
	main.Visible = not main.Visible
end)
connect(UserInputService.InputBegan, function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)
connect(LocalPlayer.Idled, function()
	if not app.State.AntiAfk then
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

function app.Destroy()
	stopAllLoops()
	for _, control in pairs(app.Controls) do
		if type(control) == "table" and type(control.Set) == "function" then
			pcall(control.Set, false, true)
		end
	end
	if Modules.AutoFarmCmds and type(Modules.AutoFarmCmds.Disable) == "function" then
		pcall(Modules.AutoFarmCmds.Disable)
	end
	if Modules.HatchingCmds and Modules.HatchingTypes and Modules.HatchingTypes.Options then
		pcall(function()
			Modules.HatchingCmds.ForceDisable(Modules.HatchingTypes.Options.AUTO)
		end)
	end
	for _, conn in ipairs(app.Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	app.Connections = {}
	if gui then
		gui:Destroy()
	end
	if env.PetSquadsUI == app then
		env.PetSquadsUI = nil
	end
end

switchTab("Auto Farm")
log("UI ready")

return app
