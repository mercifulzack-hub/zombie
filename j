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

local ClaimGroupReward = Functions and Functions:WaitForChild("ClaimGroupReward", 5)
local PremiumRewards = Functions and Functions:WaitForChild("PremiumRewards", 5)
local PurchaseUpgrade = Functions and Functions:WaitForChild("PurchaseUpgrade", 5)
local BuyPrestigeTier = Functions and Functions:WaitForChild("BuyPrestigeTier", 5)
local ClaimPrestige = Functions and Functions:WaitForChild("ClaimPrestige", 5)
local ClaimPlayTimeReward = Events and Events:WaitForChild("ClaimPlayTimeReward", 5)
local CollectDailyReward = Events and Events:WaitForChild("CollectDailyReward", 5)
local ClaimAchievement = Events and Events:WaitForChild("ClaimAchievement", 5)
local ClaimIndexEggReward = Events and Events:WaitForChild("ClaimIndexEggReward", 5)
local ClaimIndexTierReward = Events and Events:WaitForChild("ClaimIndexTierReward", 5)
local FollowReward = Events and Events:WaitForChild("FollowReward", 5)

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
local upgradeOrder = {
	{ "Spawn", "HatchSpeed" },
	{ "Spawn", "WalkSpeed" },
	{ "Spawn", "HoverboardSpeed" },
	{ "Spawn", "HoverboardJump" },
	{ "Spawn", "ClickMulti" },
	{ "Spawn", "GemMulti" },
	{ "Spawn", "LuckMulti" },
	{ "Spawn", "GemChance" },
	{ "Spawn", "CriticalChance" },
	{ "Spawn", "MoreStorage" },
	{ "Spawn", "PetEquip" },
	{ "Spawn", "ChestAutoCollect" },
	{ "Spawn", "RebirthButtons" },
}
local followRewardKeys = {
	"FollowedReaperGaming332",
	"FollowedGems12835384",
}

-- State
local toggles = {
	autoTap = false,
	autoRebirth = false,
	autoHatch = false,
	autoMastery = false,
	autoUpgrades = false,
	autoPrestige = false,
	autoRewards = false,
	autoAchievements = false,
	autoIndexRewards = false,
}

local selectedEgg = eggOptions[1] or "Common Egg"
local selectedHatchMode = "Single"
local selectedRebirthIndex = 1
local prestigeRewardCount = 50
local achievementClaimList = {}
local indexEggNames = {}
local indexTierCount = 20

local function loadModule(path, context)
	local ok, module = pcall(require, path)
	if not ok then
		warnf(context .. " module unavailable", module)
		return nil
	end
	return module
end

local function refreshPrestigeRewardCount()
	local PrestigeConfig = loadModule(ReplicatedStorage.Modules.PrestigeConfig, "PrestigeConfig")

	if PrestigeConfig and type(PrestigeConfig.GetTotal) == "function" then
		local totalOk, total = pcall(PrestigeConfig.GetTotal)
		if totalOk and type(total) == "number" and total > 0 then
			prestigeRewardCount = total
		end
	end
end

local function refreshAchievementClaimList()
	local Achievements = loadModule(ReplicatedStorage.Modules.Achievements, "Achievements")
	if not Achievements then
		return
	end

	local list = {}
	for category, tiers in pairs(Achievements) do
		if type(category) == "string" and type(tiers) == "table" then
			for tier = 1, #tiers do
				table.insert(list, { category, tier })
			end
		end
	end

	achievementClaimList = list
end

local function refreshIndexClaimLists()
	local IndexRewards = loadModule(ReplicatedStorage.Modules.IndexRewards, "IndexRewards")
	if not IndexRewards then
		return
	end

	local eggNames = {}
	for eggName in pairs(IndexRewards.EggRewards or {}) do
		table.insert(eggNames, eggName)
	end
	table.sort(eggNames)

	indexEggNames = eggNames
	indexTierCount = #(IndexRewards.TierRewards or {})
	if indexTierCount <= 0 then
		indexTierCount = 20
	end
end

refreshPrestigeRewardCount()
refreshAchievementClaimList()
refreshIndexClaimLists()

local function claimStandardRewards(shouldContinue)
	safeRemoteCall(ClaimGroupReward, "InvokeServer", "Claim group reward")
	safeRemoteCall(PremiumRewards, "InvokeServer", "Claim premium rewards")

	for _, key in ipairs(followRewardKeys) do
		if shouldContinue and not shouldContinue() then return end
		safeRemoteCall(FollowReward, "FireServer", "Claim follow reward " .. key, key)
		task.wait(0.02)
	end

	for i = 1, prestigeRewardCount do
		if shouldContinue and not shouldContinue() then return end
		safeRemoteCall(ClaimPrestige, "InvokeServer", "Claim prestige reward " .. tostring(i), i)
		task.wait(0.02)
	end

	if CollectDailyReward then
		for i = 1, 30 do
			if shouldContinue and not shouldContinue() then return end
			safeRemoteCall(CollectDailyReward, "FireServer", "Claim daily reward " .. tostring(i), tostring(i))
			task.wait(0.02)
		end
	end

	if ClaimPlayTimeReward then
		for i = 1, 15 do
			if shouldContinue and not shouldContinue() then return end
			safeRemoteCall(ClaimPlayTimeReward, "FireServer", "Claim playtime reward " .. tostring(i), i)
			task.wait(0.02)
		end
	end
end

local function claimAchievements(shouldContinue)
	if #achievementClaimList == 0 then
		refreshAchievementClaimList()
	end

	for _, claim in ipairs(achievementClaimList) do
		if shouldContinue and not shouldContinue() then return end
		safeRemoteCall(ClaimAchievement, "FireServer", "Claim achievement " .. claim[1] .. " " .. tostring(claim[2]), claim[1], claim[2])
		task.wait(0.02)
	end
end

local function claimIndexRewards(shouldContinue)
	if #indexEggNames == 0 then
		refreshIndexClaimLists()
	end

	for _, eggName in ipairs(indexEggNames) do
		if shouldContinue and not shouldContinue() then return end
		safeRemoteCall(ClaimIndexEggReward, "FireServer", "Claim index egg reward " .. eggName, eggName)
		task.wait(0.02)
	end

	for tier = 1, indexTierCount do
		if shouldContinue and not shouldContinue() then return end
		safeRemoteCall(ClaimIndexTierReward, "FireServer", "Claim index tier reward " .. tostring(tier), tier)
		task.wait(0.02)
	end
end

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
		if toggles.autoRebirth then
			safeRemoteCall(SetAutoRebirth, "FireServer", "Auto Rebirth amount update", selectedRebirthIndex)
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

FarmTab:CreateSection("Progression", false)
FarmTab:CreateToggle({
	Name = "Auto Upgrades",
	CurrentValue = false,
	Flag = "AutoUpgrades",
	Callback = function(v) toggles.autoUpgrades = v end
})

FarmTab:CreateToggle({
	Name = "Auto Prestige",
	CurrentValue = false,
	Flag = "AutoPrestige",
	Callback = function(v) toggles.autoPrestige = v end
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

MiscTab:CreateToggle({
	Name = "Auto Claim Achievements",
	CurrentValue = false,
	Flag = "AutoAchievements",
	Callback = function(v) toggles.autoAchievements = v end
})

MiscTab:CreateToggle({
	Name = "Auto Claim Index Rewards",
	CurrentValue = false,
	Flag = "AutoIndexRewards",
	Callback = function(v) toggles.autoIndexRewards = v end
})

MiscTab:CreateButton({
	Name = "Claim Rewards Once",
	Callback = function()
		safeTask("Claim Rewards Once", function()
			claimStandardRewards()
			claimAchievements()
			claimIndexRewards()
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

runLoop("autoUpgrades", 1.25, function()
	for _, upgrade in ipairs(upgradeOrder) do
		if not toggles.autoUpgrades then
			return
		end

		safeRemoteCall(PurchaseUpgrade, "InvokeServer", "Auto Upgrade " .. upgrade[2], upgrade[1], upgrade[2])
		task.wait(0.05)
	end
end)

runLoop("autoPrestige", 2.5, function()
	for tier = 1, 4 do
		if not toggles.autoPrestige then
			return
		end

		safeRemoteCall(BuyPrestigeTier, "InvokeServer", "Auto Prestige tier " .. tostring(tier), tier)
		task.wait(0.05)
	end

	for i = 1, prestigeRewardCount do
		if not toggles.autoPrestige then
			return
		end

		safeRemoteCall(ClaimPrestige, "InvokeServer", "Auto Prestige reward " .. tostring(i), i)
		task.wait(0.03)
	end
end)

-- Rewards loop (hardcoded claims only)
task.spawn(function()
	while task.wait(10) do
		if toggles.autoRewards then
			claimStandardRewards(function() return toggles.autoRewards end)
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while task.wait(12) do
		if toggles.autoAchievements then
			claimAchievements(function() return toggles.autoAchievements end)
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while task.wait(15) do
		if toggles.autoIndexRewards then
			claimIndexRewards(function() return toggles.autoIndexRewards end)
			task.wait(1)
		end
	end
end)

print("[RebirthHatchers] Loaded (ArrayField direct, no fallbacks)")
