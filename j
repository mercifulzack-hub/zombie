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

local function warnf(message, detail)
	if detail ~= nil then
		warn("[RebirthHatchers] " .. message .. ": " .. tostring(detail))
	else
		warn("[RebirthHatchers] " .. message)
	end
end

local function safeRemoteCall(remote, methodName, context, ...)
	if not remote then
		warnf(context .. " skipped", "remote is nil")
		return false, "remote is nil"
	end

	local method = remote[methodName]
	if type(method) ~= "function" then
		warnf(context .. " skipped", "missing " .. tostring(methodName))
		return false, "missing " .. tostring(methodName)
	end

	local ok, result = pcall(method, remote, ...)
	if not ok then
		warnf(context .. " failed", result)
	end
	return ok, result
end

local function safeTask(context, fn)
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			warnf(context .. " failed", err)
		end
	end)
end

local function loadArrayfield()
	if typeof(loadstring) ~= "function" then
		return false, "loadstring not available"
	end
	return pcall(function()
		local source = game:HttpGet("https://raw.githubusercontent.com/UI-Interface/ArrayField/main/Source.lua")
		if type(source) ~= "string" or source == "" then
			error("ArrayField download returned empty content")
		end
		-- Disable default RightShift toggle keybind
		source = source:gsub(
			"if %(input%.KeyCode == Enum%.KeyCode%.RightShift and not processed%) then",
			"if false then"
		)
		-- Guard KeySettings access so ArrayField can load with KeySystem removed.
		source = source:gsub(
			"if typeof%(Settings%.KeySettings%.Key%) == \"string\" then Settings%.KeySettings%.Key = %{Settings%.KeySettings%.Key%} end",
			"if Settings.KeySettings and typeof(Settings.KeySettings.Key) == \"string\" then Settings.KeySettings.Key = {Settings.KeySettings.Key} end"
		)
		-- Skip the Discord invite block unless an actual invite code exists.
		source = source:gsub(
			"if Settings%.Discord then",
			"if Settings.Discord and Settings.Discord.Invite then"
		)
		return loadstring(source)()
	end)
end

local okUi, ArrayField = loadArrayfield()
if not okUi or not ArrayField then
	warnf("Failed to load ArrayField", ArrayField)
	return
end

-- Remotes (from game)
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local Functions = ReplicatedStorage:WaitForChild("Functions", 10)

if not Events then
	warnf("Events folder missing", "WaitForChild timed out")
end

if not Functions then
	warnf("Functions folder missing", "WaitForChild timed out")
end

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
		safeRemoteCall(SetAutoRebirth, "FireServer", "Auto Rebirth amount update", v and selectedRebirthIndex or 0)
		safeRemoteCall(ActivateAutoRebirth, "FireServer", "Auto Rebirth toggle", v)
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
		if toggles.autoHatch then
			safeRemoteCall(SetAutoHatch, "FireServer", "Auto Hatch egg update", selectedEgg)
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
		safeRemoteCall(SetAutoHatch, "FireServer", "Auto Hatch toggle", v and selectedEgg or nil)
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
		safeTask("Claim Rewards Once", function()
			safeRemoteCall(ClaimGroupReward, "InvokeServer", "Claim group reward")
			safeRemoteCall(PremiumRewards, "InvokeServer", "Claim premium rewards")

			if CollectDailyReward then
				for i = 1, 30 do
					safeRemoteCall(CollectDailyReward, "FireServer", "Claim daily reward " .. tostring(i), tostring(i))
					task.wait(0.02)
				end
			end

			if ClaimPlayTimeReward then
				for i = 1, 15 do
					safeRemoteCall(ClaimPlayTimeReward, "FireServer", "Claim playtime reward " .. tostring(i), i)
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
				local ok, err = pcall(fn)
				if not ok then
					warnf(name .. " loop failed", err)
				end
			end
		end
	end)
end

if Click then
	runLoop("autoTap", 0.07, function() safeRemoteCall(Click, "FireServer", "Auto Tap") end)
end

if Rebirth then
	runLoop("autoRebirth", 0.35, function() safeRemoteCall(Rebirth, "FireServer", "Auto Rebirth", selectedRebirthIndex) end)
end

if Hatch then
	runLoop("autoHatch", 0.22, function()
		safeRemoteCall(Hatch, "InvokeServer", "Auto Hatch", selectedEgg, selectedHatchMode)
	end)
end

runLoop("autoMastery", 0.22, function()
	safeRemoteCall(Click, "FireServer", "Auto Mastery tap")
	safeRemoteCall(Hatch, "InvokeServer", "Auto Mastery hatch", selectedEgg, selectedHatchMode)
	safeRemoteCall(Rebirth, "FireServer", "Auto Mastery rebirth", selectedRebirthIndex)
end)

-- Rewards loop (hardcoded claims only)
task.spawn(function()
	while task.wait(10) do
		if toggles.autoRewards then
			safeRemoteCall(ClaimGroupReward, "InvokeServer", "Auto claim group reward")
			safeRemoteCall(PremiumRewards, "InvokeServer", "Auto claim premium rewards")
			if CollectDailyReward then
				for i = 1, 30 do
					safeRemoteCall(CollectDailyReward, "FireServer", "Auto claim daily reward " .. tostring(i), tostring(i))
				end
			end
			if ClaimPlayTimeReward then
				for i = 1, 15 do
					safeRemoteCall(ClaimPlayTimeReward, "FireServer", "Auto claim playtime reward " .. tostring(i), i)
				end
			end
			task.wait(1)
		end
	end
end)

print("[RebirthHatchers] Loaded (ArrayField direct, no fallbacks)")
