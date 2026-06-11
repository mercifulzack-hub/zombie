-- Pet Squads Executor UI
-- Host this file at:
-- https://raw.githubusercontent.com/mercifulzack-hub/zombie/main/j

local VERSION = "1.1.0"
local ARRAYFIELD_URL = "https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local env = getgenv and getgenv() or _G
if env.PetSquadsUI and type(env.PetSquadsUI.Destroy) == "function" then
	pcall(env.PetSquadsUI.Destroy)
end

local App = {
	Connections = {},
	Loops = {},
	State = {
		AutoFarm = false,
		AutoTap = false,
		AutoCollect = false,
		AutoTeleportBest = false,
		AutoRebirth = false,
		AutoEgg = false,
		AutoRank = false,
		AntiAfk = false,
		TapDistance = 120,
		TapMode = "Normal",
		EggAmount = 1,
		SelectedEgg = nil
	}
}
env.PetSquadsUI = App

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
		table.insert(App.Connections, conn)
		return conn
	end
	return nil
end

local function startLoop(name, delayTime, fn)
	if App.Loops[name] then
		return
	end
	App.Loops[name] = true
	task.spawn(function()
		while App.Loops[name] do
			local ok, err = pcall(fn)
			if not ok then
				warnLog(name .. " loop error:", err)
			end
			task.wait(delayTime)
		end
	end)
end

local function stopLoop(name)
	App.Loops[name] = nil
end

local function stopAllLoops()
	for name in pairs(App.Loops) do
		App.Loops[name] = nil
	end
end

local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getThings()
	return Workspace:FindFirstChild("__THINGS")
end

local function findRemote(remoteName)
	local network = ReplicatedStorage:FindFirstChild("Network")
	if network then
		local direct = network:FindFirstChild(remoteName)
		if direct and (direct:IsA("RemoteEvent") or direct:IsA("RemoteFunction") or direct:IsA("UnreliableRemoteEvent")) then
			return direct
		end
	end

	for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
		if instance.Name == remoteName and (instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")) then
			return instance
		end
	end

	return nil
end

local RemoteCache = {}

local function remote(remoteName)
	if RemoteCache[remoteName] and RemoteCache[remoteName].Parent then
		return RemoteCache[remoteName]
	end
	local found = findRemote(remoteName)
	RemoteCache[remoteName] = found
	return found
end

local function fireRemote(remoteName, ...)
	local r = remote(remoteName)
	if not r then
		warnLog("Missing remote:", remoteName)
		return false
	end
	if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
		r:FireServer(...)
		return true
	end
	if r:IsA("RemoteFunction") then
		local ok, a, b = pcall(function(...)
			return r:InvokeServer(...)
		end, ...)
		if not ok then
			warnLog(remoteName .. " invoke failed:", a)
			return false
		end
		return a, b
	end
	return false
end

local function invokeRemote(remoteName, ...)
	local r = remote(remoteName)
	if not r then
		warnLog("Missing remote:", remoteName)
		return false
	end
	if r:IsA("RemoteFunction") then
		local ok, a, b = pcall(function(...)
			return r:InvokeServer(...)
		end, ...)
		if not ok then
			warnLog(remoteName .. " invoke failed:", a)
			return false
		end
		return a, b
	end
	if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
		r:FireServer(...)
		return true
	end
	return false
end

local function getZoneFolders()
	local things = getThings()
	local out = {}
	if things then
		for _, name in ipairs({ "__FAKE_GROUND", "__FAKE_INSTANCE_GROUND", "__FAKE_INSTANCE_BREAK_ZONES" }) do
			local folder = things:FindFirstChild(name)
			if folder then
				table.insert(out, folder)
			end
		end
	end
	local map = Workspace:FindFirstChild("Map")
	if map then
		table.insert(out, map)
	end
	return out
end

local function getCurrentZoneFromGround()
	local root = getRoot()
	if not root then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true
	params.FilterDescendantsInstances = getZoneFolders()

	local hit = Workspace:Raycast(root.Position + Vector3.new(0, 8, 0), Vector3.new(0, -180, 0), params)
	if not hit or not hit.Instance then
		return nil
	end

	local instance = hit.Instance
	while instance and instance ~= Workspace do
		local zoneId = instance:GetAttribute("ZoneId") or instance:GetAttribute("ZoneID")
		if zoneId then
			return tostring(zoneId)
		end
		instance = instance.Parent
	end

	return hit.Instance.Name
end

local function getOwnedZoneIds()
	local zones = {}
	local directory = ReplicatedStorage:FindFirstChild("__DIRECTORY")
	directory = directory and directory:FindFirstChild("Zones")
	if directory then
		for _, child in ipairs(directory:GetDescendants()) do
			if child:IsA("ModuleScript") then
				table.insert(zones, child.Name)
			end
		end
	end
	return zones
end

local function teleportToZone(zoneId)
	if not zoneId or zoneId == "" then
		return false
	end
	local ok = invokeRemote("Teleports_RequestTeleport", zoneId)
	if ok then
		log("Teleport requested:", zoneId)
	end
	return ok
end

local function teleportToBestKnownArea()
	local zones = getOwnedZoneIds()
	if #zones == 0 then
		local current = getCurrentZoneFromGround()
		return current and teleportToZone(current)
	end

	local bestId = zones[#zones]
	local bestNumber = -math.huge
	for _, zoneId in ipairs(zones) do
		local number = tonumber(zoneId:match("%d+")) or (zoneId == "Spawn" and 1 or -1)
		if number > bestNumber then
			bestNumber = number
			bestId = zoneId
		end
	end

	return teleportToZone(bestId)
end

local function getBreakableFolder()
	local things = getThings()
	if not things then
		return nil
	end
	return things:FindFirstChild("Breakables")
		or things:FindFirstChild("__BREAKABLES")
		or things:FindFirstChild("Breakable")
end

local function getBreakablePosition(instance)
	if not instance or not instance:IsA("Instance") then
		return nil
	end
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	local model = instance:FindFirstAncestorOfClass("Model")
	if model then
		return model:GetPivot().Position
	end
	return nil
end

local function getBreakableUid(instance)
	local current = instance
	while current and current ~= Workspace do
		local uid = current:GetAttribute("BreakableUID")
			or current:GetAttribute("UID")
			or current:GetAttribute("uid")
		if uid then
			return uid
		end
		current = current.Parent
	end
	return nil
end

local function nearbyBreakableUids()
	local folder = getBreakableFolder()
	local root = getRoot()
	local found = {}
	if not folder or not root then
		return found
	end

	for _, child in ipairs(folder:GetDescendants()) do
		local uid = getBreakableUid(child)
		if uid then
			local position = getBreakablePosition(child)
			if position then
				local distance = (position - root.Position).Magnitude
				if distance <= App.State.TapDistance then
					table.insert(found, { Uid = uid, Distance = distance })
				end
			end
		end
	end

	table.sort(found, function(a, b)
		return a.Distance < b.Distance
	end)

	local uids = {}
	local seen = {}
	for _, item in ipairs(found) do
		if not seen[item.Uid] then
			seen[item.Uid] = true
			table.insert(uids, item.Uid)
		end
	end

	return uids
end

local function autoTap()
	local limit = App.State.TapMode == "Extreme" and 12 or 4
	local sent = 0
	for _, uid in ipairs(nearbyBreakableUids()) do
		fireRemote("Breakables_PlayerDealDamage", uid)
		sent += 1
		if sent >= limit then
			break
		end
	end
	if sent > 0 then
		log("Tapped nearest breakables:", sent)
	end
end

local function autoFarmToggle(enabled)
	App.State.AutoFarm = enabled
	if enabled then
		teleportToBestKnownArea()
		invokeRemote("AutoFarm_Enable")
	else
		invokeRemote("AutoFarm_Disable")
	end
end

local function collectDrops()
	local things = getThings()
	local orbs = things and things:FindFirstChild("Orbs")
	if not orbs then
		warnLog("No workspace.__THINGS.Orbs folder found")
		return
	end

	local batch = {}
	for _, orb in ipairs(orbs:GetChildren()) do
		table.insert(batch, orb.Name)
		if #batch >= 100 then
			break
		end
	end

	if #batch == 0 then
		return
	end

	local ok = fireRemote("Orbs: Collect", batch)
	if ok then
		log("Collect drops sent:", #batch)
	end
end

local function autoRebirth()
	invokeRemote("Rebirth_Request")
end

local function getEggIds()
	local ids = {}
	local eggsFolder = ReplicatedStorage:FindFirstChild("__DIRECTORY")
	eggsFolder = eggsFolder and eggsFolder:FindFirstChild("Eggs")

	if eggsFolder then
		for _, child in ipairs(eggsFolder:GetDescendants()) do
			if child:IsA("ModuleScript") then
				table.insert(ids, child.Name)
			end
		end
	end

	table.sort(ids)
	if #ids == 0 then
		table.insert(ids, "No eggs found")
	end
	return ids
end

local function setSelectedEgg(option)
	if type(option) == "table" then
		option = option[1]
	end
	if option == "No eggs found" then
		App.State.SelectedEgg = nil
	else
		App.State.SelectedEgg = tostring(option)
	end
	log("Selected egg:", App.State.SelectedEgg or "nil")
end

local function buySelectedEgg()
	if not App.State.SelectedEgg then
		warnLog("No egg selected")
		return
	end
	local amount = math.max(1, math.floor(tonumber(App.State.EggAmount) or 1))
	local ok, msg = invokeRemote("Eggs_RequestPurchase", App.State.SelectedEgg, amount)
	if not ok and msg then
		warnLog("Egg purchase failed:", msg)
	end
end

local function autoRankStep()
	-- Without requiring Client.Save, rank goals are not safely readable from this executor context.
	-- Best effort: keep farm/tap/drop collection and egg purchase loops active so supported goals progress.
	if App.State.SelectedEgg then
		buySelectedEgg()
	end
	autoTap()
	collectDrops()
end

local function destroy()
	stopAllLoops()
	pcall(function()
		invokeRemote("AutoFarm_Disable")
	end)
	for _, conn in ipairs(App.Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	App.Connections = {}
	if env.PetSquadsUI == App then
		env.PetSquadsUI = nil
	end
	log("Destroyed")
end
App.Destroy = destroy

local ArrayField
local ok, result = pcall(function()
	return loadstring(game:HttpGet(ARRAYFIELD_URL))()
end)

if ok then
	ArrayField = result
else
	warnLog("ArrayField failed to load:", result)
	return
end

local Window = ArrayField:CreateWindow({
	Name = "Pet Squads",
	LoadingTitle = "Pet Squads",
	LoadingSubtitle = "v" .. VERSION,
	ConfigurationSaving = {
		Enabled = false,
		FolderName = nil,
		FileName = "PetSquads"
	},
	Discord = {
		Enabled = false,
		Invite = "",
		RememberJoins = false
	},
	KeySystem = false,
	KeySettings = {
		Title = "Pet Squads",
		Subtitle = "",
		Note = "",
		FileName = "PetSquadsKey",
		SaveKey = false,
		GrabKeyFromSite = false,
		Key = ""
	}
})

local AutoFarmTab = Window:CreateTab("Auto Farm", 4483362458)
local EggsTab = Window:CreateTab("Eggs", 4483362458)
local RankTab = Window:CreateTab("Auto Rank", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

AutoFarmTab:CreateSection("Farming", false)
AutoFarmTab:CreateToggle({
	Name = "Auto Farm",
	Info = "Teleports to best known area, then requests built-in auto farm.",
	CurrentValue = false,
	Flag = "PS_AutoFarm",
	Callback = function(value)
		autoFarmToggle(value)
	end
})
AutoFarmTab:CreateToggle({
	Name = "Auto Farm/Tap",
	Info = "Taps nearest breakables/coin piles/chests in your tap distance.",
	CurrentValue = false,
	Flag = "PS_AutoTap",
	Callback = function(value)
		App.State.AutoTap = value
		if value then
			startLoop("AutoTap", App.State.TapMode == "Extreme" and 0.08 or 0.18, autoTap)
		else
			stopLoop("AutoTap")
		end
	end
})
AutoFarmTab:CreateSlider({
	Name = "Auto Farm/Tap Distance",
	Range = { 10, 1000 },
	Increment = 10,
	Suffix = "studs",
	CurrentValue = App.State.TapDistance,
	Flag = "PS_TapDistance",
	Callback = function(value)
		App.State.TapDistance = tonumber(value) or 120
	end
})
AutoFarmTab:CreateDropdown({
	Name = "Tap Mode",
	Options = { "Normal", "Extreme" },
	CurrentOption = "Normal",
	MultiSelection = false,
	Flag = "PS_TapMode",
	Callback = function(option)
		if type(option) == "table" then
			option = option[1]
		end
		App.State.TapMode = tostring(option or "Normal")
		if App.State.AutoTap then
			stopLoop("AutoTap")
			startLoop("AutoTap", App.State.TapMode == "Extreme" and 0.08 or 0.18, autoTap)
		end
	end
})
AutoFarmTab:CreateToggle({
	Name = "Auto Collect Drops",
	Info = "Collects visible coin, diamond, item, and lootbag orb ids if the collect remote accepts them.",
	CurrentValue = false,
	Flag = "PS_AutoCollect",
	Callback = function(value)
		App.State.AutoCollect = value
		if value then
			startLoop("AutoCollect", 0.35, collectDrops)
		else
			stopLoop("AutoCollect")
		end
	end
})
AutoFarmTab:CreateSection("Travel", false)
AutoFarmTab:CreateToggle({
	Name = "Auto Teleport To Best Area",
	CurrentValue = false,
	Flag = "PS_AutoTeleportBest",
	Callback = function(value)
		App.State.AutoTeleportBest = value
		if value then
			startLoop("AutoTeleportBest", 5, teleportToBestKnownArea)
		else
			stopLoop("AutoTeleportBest")
		end
	end
})
AutoFarmTab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "PS_AutoRebirth",
	Callback = function(value)
		App.State.AutoRebirth = value
		if value then
			startLoop("AutoRebirth", 4, autoRebirth)
		else
			stopLoop("AutoRebirth")
		end
	end
})

EggsTab:CreateSection("Eggs", false)
local eggIds = getEggIds()
setSelectedEgg(eggIds[1])
EggsTab:CreateDropdown({
	Name = "Select Egg",
	Options = eggIds,
	CurrentOption = eggIds[1],
	MultiSelection = false,
	Flag = "PS_SelectEgg",
	Callback = setSelectedEgg
})
EggsTab:CreateInput({
	Name = "Select Egg Amount",
	PlaceholderText = "1",
	NumbersOnly = true,
	OnEnter = false,
	RemoveTextAfterFocusLost = false,
	Callback = function(text)
		App.State.EggAmount = math.max(1, math.floor(tonumber(text) or 1))
	end
})
EggsTab:CreateButton({
	Name = "Buy Selected Egg Once",
	Interact = "Buy",
	Callback = buySelectedEgg
})
EggsTab:CreateToggle({
	Name = "Auto Buy Selected Egg",
	CurrentValue = false,
	Flag = "PS_AutoEgg",
	Callback = function(value)
		App.State.AutoEgg = value
		if value then
			startLoop("AutoEgg", 2.6, buySelectedEgg)
		else
			stopLoop("AutoEgg")
		end
	end
})
EggsTab:CreateButton({
	Name = "Teleport To Egg Zone",
	Interact = "Teleport",
	Callback = function()
		-- Egg-to-zone metadata is not safely readable without requiring Directory.
		-- This teleports to the best known area as the safest available fallback.
		teleportToBestKnownArea()
	end
})

RankTab:CreateSection("Best Effort", false)
RankTab:CreateToggle({
	Name = "Auto Rank",
	Info = "Best effort without unsafe Save require: farm/tap/collect/hatch loops progress supported goals.",
	CurrentValue = false,
	Flag = "PS_AutoRank",
	Callback = function(value)
		App.State.AutoRank = value
		if value then
			startLoop("AutoRank", 2, autoRankStep)
		else
			stopLoop("AutoRank")
		end
	end
})

SettingsTab:CreateSection("Settings", false)
SettingsTab:CreateToggle({
	Name = "Anti AFK",
	CurrentValue = false,
	Flag = "PS_AntiAfk",
	Callback = function(value)
		App.State.AntiAfk = value
	end
})
SettingsTab:CreateButton({
	Name = "Destroy Script",
	Interact = "Destroy",
	Callback = destroy
})

connect(LocalPlayer.Idled, function()
	if not App.State.AntiAfk then
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

log("ArrayField UI loaded. Custom Discord/key system disabled.")
return App
