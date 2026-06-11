-- Rebirth Hatchers - ArrayField (Direct Executor Version, No Fallbacks)
-- Paste this entire script into your executor (Solara etc.)
-- Only ArrayField + core autos. Hardcoded from game data. No module requires.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
	warn("[RebirthHatchers] Run on client/executor only")
	return
end

local function loadArrayfield()
	if typeof(loadstring) ~= "function" then
		return false, "loadstring not available"
	end
	return pcall(function()
		local source = game:HttpGet("https://raw.githubusercontent.com/UI-Interface/ArrayField/main/Source.lua")
		-- Disable default RightShift toggle keybind
		source = source:gsub(
			"if %(input%.KeyCode == Enum%.KeyCode%.RightShift and not processed%) then",
			"if false then"
		)
		return loadstring(source)()
	end)
end

local okUi, ArrayField = loadArrayfield()
if not okUi or not ArrayField then
	warn("[RebirthHatchers] Failed to load ArrayField:", ArrayField)
	return
end

-- Remotes (from game)
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local Functions = ReplicatedStorage:WaitForChild("Functions", 10)

local Click = Events and Events:WaitForChild("Click", 5)
local Rebirth = Events and Events:WaitForChild("Rebirth", 5)
local SetAutoRebirth = Events and Events:WaitForChild("SetAutoRebirth", 5)
local ActivateAutoRebirth = Events and Events:WaitForChild("ActivateAutoRebirth", 5)
local SetAutoHatch = Events and Events:WaitForChild("SetAutoHatch", 5)
local Hatch = Functions and Functions:WaitForChild("Hatch", 5)

local ClaimGroupReward = Functions and Functions:FindFirstChild("ClaimGroupReward")
local PremiumRewards = Functions and Functions:FindFirstChild("PremiumRewards")
local ClaimPlayTimeReward = Events and Events:FindFirstChild("ClaimPlayTimeReward")
local CollectDailyReward = Events and Events:FindFirstChild("CollectDailyReward")

-- Hardcoded from game source (Eggs.lua) - no module load
local eggOptions = {
	"Common Egg", "Golden Common Egg",
	"Farm Egg", "Golden Farm Egg",
	"Desert Egg", "Golden Desert Egg",
	"Ocean Egg", "Golden Ocean Egg",
	"Cave Egg", "Golden Cave Egg",
	"Lava Egg", "Golden Lava Egg",
	"Jungle Egg", "Golden Jungle Egg",
	"Candy Egg", "Golden Candy Egg",
	"Beach Egg", "Golden Beach Egg",
	"Snow Egg", "Golden Snow Egg",
	"Samurai Egg", "Golden Samurai Egg",
	"Steampunk Egg", "Golden Steampunk Egg",
	"Breakables Egg", "Leaderboard Egg", "Dominus Egg", "Shop Egg"
}

local rebirthOptions = { "1", "5", "10", "25", "50", "100", "250", "500", "1K", "2.5K", "5K", "10K", "25K", "50K" }
local rebirthByText = {
	["1"] = 1, ["5"] = 2, ["10"] = 3, ["25"] = 4, ["50"] = 5,
	["100"] = 6, ["250"] = 7, ["500"] = 8, ["1K"] = 9,
	["2.5K"] = 10, ["5K"] = 11, ["10K"] = 12, ["25K"] = 13, ["50K"] = 14,
}
local hatchModes = { "Single", "Triple", "Max" }

-- State
local toggles = {
	autoTap = false,
	autoRebirth = false,
	autoHatch = false,
	autoMastery = false,
	autoRewards = false,
}

local selectedEgg = eggOptions[1] or "Common Egg"
local selectedHatchMode = "Single"
local selectedRebirthIndex = 1

-- UI
local Window = ArrayField:CreateWindow({
	Name = "Rebirth Hatchers",
	LoadingTitle = "Rebirth Hatchers",
	LoadingSubtitle = "ArrayField | Executor Ready",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "RebirthHatchers",
		FileName = "Settings",
	},
	Discord = { Enabled = false },
	KeySystem = false,
})

local FarmTab = Window:CreateTab("Farm", 4483362458)
local EggTab = Window:CreateTab("Eggs", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- Farm
FarmTab:CreateSection("Core Farming", false)
FarmTab:CreateToggle({
	Name = "Auto Tap (Click)",
	CurrentValue = false,
	Flag = "AutoTap",
	Callback = function(v) toggles.autoTap = v end
})

FarmTab:CreateDropdown({
	Name = "Auto Rebirth Amount",
	Options = rebirthOptions,
	CurrentOption = "1",
	MultiSelection = false,
	Callback = function(opt)
		selectedRebirthIndex = rebirthByText[opt] or 1
		if toggles.autoRebirth and SetAutoRebirth then
			SetAutoRebirth:FireServer(selectedRebirthIndex)
		end
	end
})

FarmTab:CreateToggle({
	Name = "Auto Rebirth (Game + Loop)",
	CurrentValue = false,
	Flag = "AutoRebirth",
	Callback = function(v)
		toggles.autoRebirth = v
		if SetAutoRebirth then
			SetAutoRebirth:FireServer(v and selectedRebirthIndex or 0)
		end
		if ActivateAutoRebirth then
			ActivateAutoRebirth:FireServer(v)
		end
	end
})

-- Eggs
EggTab:CreateSection("Hatching", false)
EggTab:CreateDropdown({
	Name = "Egg",
	Options = eggOptions,
	CurrentOption = selectedEgg,
	MultiSelection = false,
	Callback = function(opt)
		selectedEgg = opt
		if toggles.autoHatch and SetAutoHatch then
			SetAutoHatch:FireServer(selectedEgg)
		end
	end
})

EggTab:CreateDropdown({
	Name = "Hatch Mode",
	Options = hatchModes,
	CurrentOption = selectedHatchMode,
	MultiSelection = false,
	Callback = function(opt) selectedHatchMode = opt end
})

EggTab:CreateToggle({
	Name = "Auto Hatch (Game + Loop)",
	CurrentValue = false,
	Flag = "AutoHatch",
	Callback = function(v)
		toggles.autoHatch = v
		if SetAutoHatch then
			SetAutoHatch:FireServer(v and selectedEgg or nil)
		end
	end
})

-- Misc
MiscTab:CreateSection("Combo & Claims", false)
MiscTab:CreateToggle({
	Name = "Auto Mastery (Tap + Hatch + Rebirth)",
	CurrentValue = false,
	Flag = "AutoMastery",
	Callback = function(v) toggles.autoMastery = v end
})

MiscTab:CreateToggle({
	Name = "Auto Claim Rewards",
	CurrentValue = false,
	Flag = "AutoRewards",
	Callback = function(v) toggles.autoRewards = v end
})

MiscTab:CreateButton({
	Name = "Claim Rewards Once",
	Callback = function()
		task.spawn(function()
			if ClaimGroupReward then pcall(function() ClaimGroupReward:InvokeServer() end) end
			if PremiumRewards then pcall(function() PremiumRewards:InvokeServer() end) end
			if CollectDailyReward then
				for i = 1, 30 do
					pcall(function() CollectDailyReward:FireServer(tostring(i)) end)
					task.wait(0.02)
				end
			end
			if ClaimPlayTimeReward then
				for i = 1, 15 do
					pcall(function() ClaimPlayTimeReward:FireServer(i) end)
					task.wait(0.02)
				end
			end
		end)
	end
})

-- Loops (direct, no data/replica/config needed)
local function runLoop(name, delay, fn)
	task.spawn(function()
		while task.wait(delay) do
			if toggles[name] then
				pcall(fn)
			end
		end
	end)
end

if Click then
	runLoop("autoTap", 0.07, function() Click:FireServer() end)
end

if Rebirth then
	runLoop("autoRebirth", 0.35, function() Rebirth:FireServer(selectedRebirthIndex) end)
end

if Hatch then
	runLoop("autoHatch", 0.22, function()
		Hatch:InvokeServer(selectedEgg, selectedHatchMode)
	end)
end

runLoop("autoMastery", 0.22, function()
	if Click then Click:FireServer() end
	if Hatch then pcall(function() Hatch:InvokeServer(selectedEgg, selectedHatchMode) end) end
	if Rebirth then Rebirth:FireServer(selectedRebirthIndex) end
end)

-- Rewards loop (hardcoded claims only)
task.spawn(function()
	while task.wait(10) do
		if toggles.autoRewards then
			if ClaimGroupReward then pcall(function() ClaimGroupReward:InvokeServer() end) end
			if PremiumRewards then pcall(function() PremiumRewards:InvokeServer() end) end
			if CollectDailyReward then
				for i = 1, 30 do
					pcall(function() CollectDailyReward:FireServer(tostring(i)) end)
				end
			end
			if ClaimPlayTimeReward then
				for i = 1, 15 do
					pcall(function() ClaimPlayTimeReward:FireServer(i) end)
				end
			end
			task.wait(1)
		end
	end
end)

print("[RebirthHatchers] Loaded (ArrayField direct, no fallbacks)")
