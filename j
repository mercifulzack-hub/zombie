-- Rebirth Hatchers - Arrayfield Utility (Solara Optimized)
-- Paste this entire script into Solara Executor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
	warn("[RebirthHatchers] This utility must run from a LocalScript or client executor")
	return
end

local function loadArrayfield()
	if typeof(loadstring) ~= "function" then
		return false, "loadstring is not available in this executor"
	end

	return pcall(function()
		local source = game:HttpGet("https://raw.githubusercontent.com/UI-Interface/ArrayField/main/Source.lua")
		source = source:gsub(
			"if %(input%.KeyCode == Enum%.KeyCode%.RightShift and not processed%) then",
			"if false then"
		)
		return loadstring(source)()
	end)
end

-- Load Arrayfield UI
local okUi, ArrayField = loadArrayfield()
if not okUi or not ArrayField then
	warn("[RebirthHatchers] Failed to load Arrayfield UI", ArrayField)
	return
end

-- Services & Remotes
local Events = ReplicatedStorage:WaitForChild("Events")
local Functions = ReplicatedStorage:WaitForChild("Functions")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local ReplicaController = require(Modules.Libraries:WaitForChild("ReplicaController"))
local Eggs = require(Modules:WaitForChild("Eggs"))
local PlayTimeConfig = require(Modules:WaitForChild("playTimeConfig"))
local Achievements = require(Modules:WaitForChild("Achievements"))
local IndexRewards = require(Modules:WaitForChild("IndexRewards"))
local PrestigeConfig = require(Modules:WaitForChild("PrestigeConfig"))
local UpgradeConfig = require(ReplicatedStorage.NodeTree.Configs:WaitForChild("Nodes")).UpgradeConfig

local Click = Events:WaitForChild("Click")
local Rebirth = Events:WaitForChild("Rebirth")
local SetAutoRebirth = Events:WaitForChild("SetAutoRebirth")
local ActivateAutoRebirth = Events:WaitForChild("ActivateAutoRebirth")
local SetAutoHatch = Events:WaitForChild("SetAutoHatch")
local Hatch = Functions:WaitForChild("Hatch")
local PurchaseUpgrade = Functions:WaitForChild("PurchaseUpgrade")
local BuyPrestigeTier = Functions:WaitForChild("BuyPrestigeTier")
local ClaimPrestige = Functions:WaitForChild("ClaimPrestige")

local ClaimGroupReward = Functions:FindFirstChild("ClaimGroupReward")
local PremiumRewards = Functions:FindFirstChild("PremiumRewards")
local ClaimPlayTimeReward = Events:FindFirstChild("ClaimPlayTimeReward")
local CollectDailyReward = Events:FindFirstChild("CollectDailyReward")
local ClaimAchievement = Events:FindFirstChild("ClaimAchievement")
local ClaimIndexEggReward = Events:FindFirstChild("ClaimIndexEggReward")
local ClaimIndexTierReward = Events:FindFirstChild("ClaimIndexTierReward")

local playerReplica
local toggles = {
	autoTap = false,
	autoRebirth = false,
	autoHatch = false,
	autoUpgrades = false,
	autoRewards = false,
	autoPrestige = false,
	autoMastery = false,
}

local selectedEgg = "Common Egg"
local selectedHatchMode = "Single"
local selectedRebirthIndex = 1

local rebirthByText = {
	["1"] = 1, ["5"] = 2, ["10"] = 3, ["25"] = 4, ["50"] = 5,
	["100"] = 6, ["250"] = 7, ["500"] = 8, ["1K"] = 9,
	["2.5K"] = 10, ["5K"] = 11, ["10K"] = 12, ["25K"] = 13, ["50K"] = 14,
}

local rebirthOptions = { "1", "5", "10", "25", "50", "100", "250", "500", "1K", "2.5K", "5K", "10K", "25K", "50K" }
local hatchModes = { "Single", "Triple", "Max" }
local eggOptions = {}

for eggName in pairs(Eggs.eggs or {}) do
	table.insert(eggOptions, eggName)
end
table.sort(eggOptions)

if not table.find(eggOptions, selectedEgg) and eggOptions[1] then
	selectedEgg = eggOptions[1]
end

local function data()
	return playerReplica and playerReplica.Data or nil
end

local function safe(label, callback)
	local success, result = pcall(callback)
	if not success then
		warn("[RebirthHatchers]", label, result)
		return false
	end
	return result
end

local function runLoop(toggleName, waitTime, callback)
	task.spawn(function()
		while task.wait(waitTime) do
			if toggles[toggleName] then
				callback()
			end
		end
	end)
end

-- Prestige & Upgrade Helpers
local prestigeUnlockNodeIds = {prestige_unlock_1 = 1, prestige_unlock_2 = 2, prestige_unlock_3 = 3, prestige_unlock_4 = 4}

local function nodeTier(nodeId)
	return prestigeUnlockNodeIds[nodeId] or tonumber(tostring(nodeId):match("_(%d+)$")) or 1
end

local function ownedUpgrade(currentData, nodeId, config)
	if config.upgradeType == "Prestige" then
		local prestigeData = currentData.PrestigeData or {}
		return (prestigeData.TierUnlocks or 0) >= (prestigeUnlockNodeIds[nodeId] or 999)
	end
	local bucket = currentData[config.dataKey]
	return typeof(bucket) == "table" and (bucket[config.upgradeName] or 0) >= nodeTier(nodeId)
end

local function parentOwned(currentData, config)
	if not config.parentNodeId then return true end
	local parentConfig = UpgradeConfig[config.parentNodeId]
	if not parentConfig or not parentConfig.upgradeName then return true end
	return ownedUpgrade(currentData, config.parentNodeId, parentConfig)
end

local upgradeOrder = {}
for nodeId, config in pairs(UpgradeConfig) do
	if config.upgradeName then
		table.insert(upgradeOrder, {
			nodeId = nodeId,
			config = config,
			tier = nodeTier(nodeId),
		})
	end
end
table.sort(upgradeOrder, function(a, b)
	if a.config.upgradeType ~= b.config.upgradeType then
		return a.config.upgradeType < b.config.upgradeType
	end
	if a.config.upgradeName ~= b.config.upgradeName then
		return a.config.upgradeName < b.config.upgradeName
	end
	return a.tier < b.tier
end)

local function buyNextUpgrade()
	local currentData = data()
	if not currentData then return end

	for _, item in ipairs(upgradeOrder) do
		local config = item.config
		if not ownedUpgrade(currentData, item.nodeId, config) and parentOwned(currentData, config) then
			if config.upgradeType == "Prestige" then
				local tier = prestigeUnlockNodeIds[item.nodeId]
				if tier then
					safe("Buy Prestige Tier", function() return BuyPrestigeTier:InvokeServer(tier) end)
				end
			else
				safe("Purchase Upgrade", function() return PurchaseUpgrade:InvokeServer(config.upgradeType, config.upgradeName) end)
			end
			return
		end
	end
end

local function claimPrestige()
	local currentData = data()
	local prestigeData = currentData and currentData.PrestigeData
	if not prestigeData then return end

	for index = 1, PrestigeConfig.GetTotal() do
		local prestige = PrestigeConfig.GetPrestige(index)
		local alreadyClaimed = table.find(prestigeData.Claimed or {}, index) ~= nil
		if prestige and not alreadyClaimed and (prestigeData.XP or 0) >= (prestige.XPRequired or math.huge) then
			safe("Claim Prestige", function() return ClaimPrestige:InvokeServer(index) end)
			return
		end
	end
end

local function claimRewards()
	if ClaimGroupReward then safe("Group Reward", function() ClaimGroupReward:InvokeServer() end) end
	if PremiumRewards then safe("Premium Rewards", function() PremiumRewards:InvokeServer() end) end

	if ClaimPlayTimeReward then
		for index in ipairs(PlayTimeConfig) do
			safe("Playtime", function() ClaimPlayTimeReward:FireServer(index) end)
			task.wait(0.05)
		end
	end

	if CollectDailyReward then
		for i = 1, 30 do
			safe("Daily", function() CollectDailyReward:FireServer(tostring(i)) end)
			task.wait(0.03)
		end
	end

	if ClaimAchievement then
		for category, rewards in pairs(Achievements) do
			if typeof(rewards) == "table" then
				for i in ipairs(rewards) do
					safe("Achievement", function() ClaimAchievement:FireServer(category, i) end)
					task.wait(0.03)
				end
			end
		end
	end

	if ClaimIndexEggReward then
		for eggName in pairs(IndexRewards.EggRewards or {}) do
			safe("Index Egg", function() ClaimIndexEggReward:FireServer(eggName) end)
			task.wait(0.03)
		end
	end

	if ClaimIndexTierReward then
		for tier in pairs(IndexRewards.TierRewards or {}) do
			safe("Index Tier", function() ClaimIndexTierReward:FireServer(tier) end)
			task.wait(0.03)
		end
	end
end

-- UI Creation
local Window = ArrayField:CreateWindow({
	Name = "Rebirth Hatchers",
	LoadingTitle = "Rebirth Hatchers Utility",
	LoadingSubtitle = "Solara Edition",
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
local ProgressTab = Window:CreateTab("Progress", 4483362458)
local RewardTab = Window:CreateTab("Rewards", 4483362458)

-- Farm Tab
FarmTab:CreateSection("Main", false)
FarmTab:CreateToggle({Name = "Auto Tap", CurrentValue = false, Flag = "AutoTap", Callback = function(v) toggles.autoTap = v end})
FarmTab:CreateDropdown({Name = "Auto Rebirth Amount", Options = rebirthOptions, CurrentOption = "1", MultiSelection = false, Callback = function(opt)
	selectedRebirthIndex = rebirthByText[opt] or 1
	if toggles.autoRebirth then
		SetAutoRebirth:FireServer(selectedRebirthIndex)
	end
end})
FarmTab:CreateToggle({Name = "Auto Rebirth", CurrentValue = false, Flag = "AutoRebirth", Callback = function(v)
	toggles.autoRebirth = v
	SetAutoRebirth:FireServer(v and selectedRebirthIndex or 0)
	ActivateAutoRebirth:FireServer(v)
end})

-- Egg Tab
EggTab:CreateSection("Hatching", false)
EggTab:CreateDropdown({Name = "Egg", Options = eggOptions, CurrentOption = selectedEgg, MultiSelection = false, Callback = function(opt)
	selectedEgg = opt
	if toggles.autoHatch then
		SetAutoHatch:FireServer(selectedEgg)
	end
end})
EggTab:CreateDropdown({Name = "Hatch Mode", Options = hatchModes, CurrentOption = selectedHatchMode, MultiSelection = false, Callback = function(opt)
	selectedHatchMode = opt
end})
EggTab:CreateToggle({Name = "Auto Hatch", CurrentValue = false, Flag = "AutoHatch", Callback = function(v)
	toggles.autoHatch = v
	SetAutoHatch:FireServer(v and selectedEgg or nil)
end})

-- Progress Tab
ProgressTab:CreateSection("Progression", false)
ProgressTab:CreateToggle({Name = "Auto Upgrades", CurrentValue = false, Flag = "AutoUpgrades", Callback = function(v) toggles.autoUpgrades = v end})
ProgressTab:CreateToggle({Name = "Auto Prestige", CurrentValue = false, Flag = "AutoPrestige", Callback = function(v) toggles.autoPrestige = v end})
ProgressTab:CreateToggle({Name = "Auto Mastery (Tap + Hatch + Rebirth)", CurrentValue = false, Flag = "AutoMastery", Callback = function(v) toggles.autoMastery = v end})

-- Rewards Tab
RewardTab:CreateSection("Claims", false)
RewardTab:CreateToggle({Name = "Auto Claim Rewards", CurrentValue = false, Flag = "AutoRewards", Callback = function(v) toggles.autoRewards = v end})
RewardTab:CreateButton({Name = "Claim All Rewards Once", Callback = function() task.spawn(claimRewards) end})

-- Replica
ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
	playerReplica = replica
end)

-- Main Loops
runLoop("autoTap", 0.08, function() Click:FireServer() end)
runLoop("autoRebirth", 0.4, function() Rebirth:FireServer(selectedRebirthIndex) end)
runLoop("autoHatch", 0.25, function()
	safe("Hatch", function() return Hatch:InvokeServer(selectedEgg, selectedHatchMode) end)
end)
runLoop("autoUpgrades", 0.35, buyNextUpgrade)
runLoop("autoPrestige", 0.75, claimPrestige)
runLoop("autoMastery", 0.25, function()
	Click:FireServer()
	safe("Mastery Hatch", function() return Hatch:InvokeServer(selectedEgg, selectedHatchMode) end)
	Rebirth:FireServer(selectedRebirthIndex)
end)

task.spawn(function()
	while task.wait(12) do
		if toggles.autoRewards then
			claimRewards()
		end
	end
end)

print("[RebirthHatchers] Utility loaded successfully")
