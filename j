--[[
    Hatch Cows Fully Automated Script
    Features:
    - Auto Hatch/Roll (uses game's built-in _G.__setAuto)
    - Auto Sell Milk (with price thresholds)
    - Auto Buy from Merchant (CheesePack / TicketPack)
    - Auto Skill Tree Upgrades (smart priority)
    - Auto Equip Best Cows
    - Auto Rebirth (when affordable)
    - Anti-AFK
    - Uses Rayfield/Arrayfield UI Library
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local CowData = require(ReplicatedStorage:WaitForChild("CowData"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════════
-- EVENTS (actual paths from game place files)
-- ══════════════════════════════════════════════════════════
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = Shared:WaitForChild("Events")

local AddCow = Events:WaitForChild("AddCow")
local SellMilk = Events:WaitForChild("SellMilk")
local GetMilkPrice = Events:WaitForChild("GetMilkPrice")
local MerchantBuy = Events:WaitForChild("MerchantBuy")
local PurchaseSkill = Events:WaitForChild("PurchaseSkill")
local GetSkillTreeData = Events:WaitForChild("GetSkillTreeData")
local DataUpdate = Events:WaitForChild("DataUpdate")
local SyncEquipped = Events:WaitForChild("SyncEquipped")
local Rebirth = Events:WaitForChild("Rebirth")
local GetRebirthInfo = Events:WaitForChild("GetRebirthInfo")

-- ══════════════════════════════════════════════════════════
-- UI REFERENCES (actual names from CowController)
-- ══════════════════════════════════════════════════════════
local CowSimulatorGui = PlayerGui:WaitForChild("CowSimulatorGui")
local BackpackPanelNEW = CowSimulatorGui:WaitForChild("BackpackPanelNEW")
local EquipBest = BackpackPanelNEW:FindFirstChild("EquipBest")

-- Silent and robust helper to trigger EquipBest click handler
local function TriggerEquipBest()
    if not EquipBest then return end
    pcall(function()
        if firesignal then
            firesignal(EquipBest.MouseButton1Click)
        else
            EquipBest.MouseButton1Click:Fire()
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════
local Config = {
    AutoHatch = false,
    AutoSell = false,
    SellThreshold = 10, -- numeric: 1-20
    AutoMerchant = false,
    MerchantItem = "CheesePack", -- CheesePack, TicketPack, Both
    AutoUpgrades = false,
    UpgradeMode = "Smart", -- Smart, All
    AutoEquipBest = false,
    AutoRebirth = false,
    AntiAFK = true,
    AutoSellInterval = 30,
    RebirthCheckInterval = 10
}

-- ══════════════════════════════════════════════════════════
-- STATE (matches actual DataUpdate payload fields)
-- ══════════════════════════════════════════════════════════
local State = {
    CurrentMilkPrice = 1, -- numeric price (1-20)
    NextPriceChangeTime = 0, -- os.time() based
    LastData = nil, -- full DataUpdate payload
    Money = 0,
    Milk = 0,
    TotalRolls = 0,
    Backpack = {},
    Equipped = {},
    Effects = {},
    Merchant = nil, -- {CheesePack=N, TicketPack=N, RestockAt=T}
    LastAction = tick()
}

-- Sell threshold name → numeric value mapping
local PriceThresholdNames = {
    Low = 5,
    Average = 10,
    Good = 15,
    Insane = 18
}

-- ══════════════════════════════════════════════════════════
-- CONFIG SAVE / LOAD
-- ══════════════════════════════════════════════════════════
local function SaveConfig()
    pcall(function()
        writefile("HatchCowsAuto_Config.json", HttpService:JSONEncode(Config))
    end)
end

local function LoadConfig()
    if not isfile or not isfile("HatchCowsAuto_Config.json") then return end
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile("HatchCowsAuto_Config.json"))
        if decoded then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- RAYFIELD UI SETUP (no key system as requested)
-- ══════════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua'))()

local Window = Rayfield:CreateWindow({
    Name = "🐄 Hatch Cows Auto",
    LoadingTitle = "Hatch Cows Auto",
    LoadingSubtitle = "by HatchCowsAuto",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "HatchCowsAuto_Rayfield"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- ═══════════════ TAB: Main Features ═══════════════
local MainTab = Window:CreateTab("Main Features", 4483362458)
local StatusTab = Window:CreateTab("Status")

-- ═══════════════ SECTION: Auto Hatch ═══════════════
local HatchSection = MainTab:CreateSection("Hatching", false)

MainTab:CreateToggle({
    Name = "🥚 Auto Hatch",
    Info = "Uses high-speed instant hatching. Failsafe roller bypasses executor restrictions and skill tree requirements!",
    CurrentValue = Config.AutoHatch,
    SectionParent = HatchSection,
    Flag = "AutoHatch",
    Callback = function(Value)
        Config.AutoHatch = Value
        SaveConfig()
        -- Fallback built-in toggling
        if _G.__setAuto then
            pcall(function() _G.__setAuto(Value) end)
        end
    end
})

-- ═══════════════ SECTION: Selling ═══════════════
local SellSection = MainTab:CreateSection("Milk Selling", false)

MainTab:CreateToggle({
    Name = "💰 Auto Sell Milk",
    Info = "Sells all milk when price meets your threshold.",
    CurrentValue = Config.AutoSell,
    SectionParent = SellSection,
    Flag = "AutoSell",
    Callback = function(Value)
        Config.AutoSell = Value
        SaveConfig()
    end
})

MainTab:CreateDropdown({
    Name = "Sell Threshold",
    Options = {"Low (5+)", "Average (10+)", "Good (15+)", "Insane (18+)"},
    CurrentOption = "Average (10+)",
    MultiSelection = false,
    SectionParent = SellSection,
    Flag = "SellThreshold",
    Callback = function(Option)
        if type(Option) == "table" then Option = Option[1] end
        local val = Option:match("(%d+)")
        Config.SellThreshold = tonumber(val) or 10
        SaveConfig()
    end
})

MainTab:CreateSlider({
    Name = "Sell Check Interval",
    Info = "Seconds between sell checks.",
    Range = {5, 120},
    Increment = 5,
    Suffix = "sec",
    CurrentValue = Config.AutoSellInterval,
    SectionParent = SellSection,
    Flag = "SellInterval",
    Callback = function(Value)
        Config.AutoSellInterval = Value
        SaveConfig()
    end
})

-- ═══════════════ SECTION: Merchant ═══════════════
local MerchantSection = MainTab:CreateSection("Merchant", false)

MainTab:CreateToggle({
    Name = "🛒 Auto Buy Merchant",
    Info = "Auto-buys from the Traveling Merchant when stock is available.",
    CurrentValue = Config.AutoMerchant,
    SectionParent = MerchantSection,
    Flag = "AutoMerchant",
    Callback = function(Value)
        Config.AutoMerchant = Value
        SaveConfig()
    end
})

MainTab:CreateDropdown({
    Name = "Merchant Item",
    Options = {"CheesePack", "TicketPack", "Both"},
    CurrentOption = Config.MerchantItem,
    MultiSelection = false,
    SectionParent = MerchantSection,
    Flag = "MerchantItem",
    Callback = function(Option)
        if type(Option) == "table" then Option = Option[1] end
        Config.MerchantItem = Option
        SaveConfig()
    end
})

-- ═══════════════ SECTION: Upgrades & Progression ═══════════════
local ProgressSection = MainTab:CreateSection("Progression", false)

MainTab:CreateToggle({
    Name = "⬆️ Auto Upgrades",
    Info = "Automatically purchases skill tree nodes.",
    CurrentValue = Config.AutoUpgrades,
    SectionParent = ProgressSection,
    Flag = "AutoUpgrades",
    Callback = function(Value)
        Config.AutoUpgrades = Value
        SaveConfig()
    end
})

MainTab:CreateDropdown({
    Name = "Upgrade Mode",
    Options = {"Smart", "All"},
    CurrentOption = Config.UpgradeMode,
    MultiSelection = false,
    SectionParent = ProgressSection,
    Flag = "UpgradeMode",
    Callback = function(Option)
        if type(Option) == "table" then Option = Option[1] end
        Config.UpgradeMode = Option
        SaveConfig()
    end
})

MainTab:CreateToggle({
    Name = "⭐ Auto Equip Best",
    Info = "Clicks the EquipBest button in the backpack periodically.",
    CurrentValue = Config.AutoEquipBest,
    SectionParent = ProgressSection,
    Flag = "AutoEquipBest",
    Callback = function(Value)
        Config.AutoEquipBest = Value
        SaveConfig()
    end
})

MainTab:CreateToggle({
    Name = "🔄 Auto Rebirth",
    Info = "Automatically rebirths when you can afford it (money + cheese).",
    CurrentValue = Config.AutoRebirth,
    SectionParent = ProgressSection,
    Flag = "AutoRebirth",
    Callback = function(Value)
        Config.AutoRebirth = Value
        SaveConfig()
    end
})

-- ═══════════════ SECTION: Utility ═══════════════
local UtilSection = MainTab:CreateSection("Utility", false)

MainTab:CreateToggle({
    Name = "🛡️ Anti-AFK",
    Info = "Prevents being kicked for inactivity.",
    CurrentValue = Config.AntiAFK,
    SectionParent = UtilSection,
    Flag = "AntiAFK",
    Callback = function(Value)
        Config.AntiAFK = Value
        SaveConfig()
    end
})

-- ═══════════════ STATUS TAB ═══════════════
local StatusSection = StatusTab:CreateSection("Live Stats", false)

local MoneyLabel = StatusTab:CreateLabel("Money: 0", StatusSection)
local MilkLabel = StatusTab:CreateLabel("Milk: 0", StatusSection)
local RollsLabel = StatusTab:CreateLabel("Total Rolls: 0", StatusSection)
local PriceLabel = StatusTab:CreateLabel("Milk Price: 1$/unit", StatusSection)
local MerchantLabel = StatusTab:CreateLabel("Merchant: N/A", StatusSection)

-- ══════════════════════════════════════════════════════════
-- DATA TRACKING (listens to the actual DataUpdate event)
-- ══════════════════════════════════════════════════════════
DataUpdate.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    
    State.LastData = data
    
    -- Money (actual field from DataTemplate)
    if type(data.Money) == "number" then
        State.Money = data.Money
    end
    
    -- Milk
    if type(data.Milk) == "number" then
        State.Milk = data.Milk
    end
    
    -- TotalRolls
    if type(data.TotalRolls) == "number" then
        State.TotalRolls = data.TotalRolls
    end
    
    -- Backpack (table of cow entries keyed by variant string)
    if type(data.Backpack) == "table" then
        State.Backpack = data.Backpack
    end
    
    -- Equipped (array of cow key strings)
    if type(data.Equipped) == "table" then
        State.Equipped = data.Equipped
    end
    
    -- Effects (skill tree computed effects)
    if type(data.Effects) == "table" then
        State.Effects = data.Effects
    end
    
    -- Merchant stock (from DataUpdate payload)
    if type(data.Merchant) == "table" then
        State.Merchant = data.Merchant
    end
end)

-- ══════════════════════════════════════════════════════════
-- AUTO FEATURES
-- ══════════════════════════════════════════════════════════

-- Anti-AFK: simple humanoid move
spawn(function()
    while true do
        wait(60)
        if Config.AntiAFK then
            if tick() - State.LastAction > 300 then
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum then
                        hum:Move(Vector3.new(0, 0, 0), true)
                    end
                end
                State.LastAction = tick()
            end
        end
    end
end)

-- Auto Hatch: custom robust loop simulating local performRoll and firing AddCow:FireServer
spawn(function()
    while true do
        wait(0.1)
        if Config.AutoHatch then
            -- 1. Try built-in game auto-roll as a fallback (if in the same global context)
            local gameAutoActive = false
            if _G.__setAuto and _G.__autoOn then
                pcall(function()
                    if not _G.__autoOn() then
                        _G.__setAuto(true)
                    end
                    gameAutoActive = true
                end)
            end
            
            -- 2. Robust Custom Failsafe / Fast Roller:
            -- Bypasses executor-sandboxed _G sandbox limitations and skill tree gates
            if not gameAutoActive then
                local success = pcall(function()
                    local effects = State.Effects or {}
                    local luck = (1 + (effects.LuckBonus or (effects.Luck or 0))) * (effects.LuckMul or 1)
                    
                    -- Check for NextRollLuckMul from save data
                    if State.LastData and State.LastData.NextRollLuckMul and State.LastData.NextRollLuckMul > 1 then
                        luck = luck * State.LastData.NextRollLuckMul
                    end
                    
                    -- Perform local roll computation
                    local rolledCow, rarity = CowData.RollCow(luck)
                    if rolledCow and rarity then
                        -- Determine rarity index
                        local rarityIndex = rolledCow.rarity or 1
                        for idx, r in ipairs(CowData.Rarities) do
                            if r == rarity then
                                rarityIndex = idx
                                break
                            end
                        end
                        
                        -- Determine size & mutation variants
                        local sizeObj = CowData.RollSize and CowData.RollSize(effects) or nil
                        local mutObj = CowData.RollMutation and CowData.RollMutation(effects) or nil
                        local sizeId = sizeObj and sizeObj.id or nil
                        local mutId = mutObj and mutObj.id or nil
                        
                        -- Apply forced next roll variant if set in save data
                        if State.LastData and State.LastData.NextRollForceVariant and State.LastData.NextRollForceVariant ~= "" then
                            local forceVariant = State.LastData.NextRollForceVariant
                            local sizeCheck = CowData.GetSize and CowData.GetSize(forceVariant)
                            local mutCheck = CowData.GetMutation and CowData.GetMutation(forceVariant)
                            if sizeCheck then
                                sizeId = forceVariant
                                mutId = nil
                            elseif mutCheck then
                                sizeId = nil
                                mutId = forceVariant
                            end
                        end
                        
                        -- Build variant string
                        local variantStr = nil
                        if sizeId or mutId then
                            variantStr = (sizeId or "normal") .. "_" .. (mutId or "normal")
                        end
                        
                        -- Fire the RemoteEvent directly to credit the cow to the server
                        AddCow:FireServer(rolledCow.name, rarityIndex, variantStr)
                    end
                    
                    -- Calculate dynamic wait interval based on roll speed effects
                    local speedMul = effects.RollSpeedMul or 1
                    local interval = 0.5 * speedMul
                    if interval < 0.05 then
                        interval = 0.05
                    end
                    wait(interval)
                end)
                
                if not success then
                    wait(1) -- Fallback wait on error
                end
            else
                wait(1)
            end
        end
    end
end)

-- Auto Sell Milk
spawn(function()
    while true do
        wait(Config.AutoSellInterval)
        if Config.AutoSell then
            local threshold = Config.SellThreshold
            if type(threshold) == "string" then
                threshold = PriceThresholdNames[threshold] or 10
            end
            
            if State.CurrentMilkPrice >= threshold and State.Milk > 0 then
                pcall(function()
                    SellMilk:FireServer()
                end)
            end
        end
    end
end)

-- Update Milk Price (GetMilkPrice returns a TABLE: {price=N, nextRepickTime=T})
spawn(function()
    while true do
        wait(15)
        pcall(function()
            local result = GetMilkPrice:InvokeServer()
            if result and type(result) == "table" then
                State.CurrentMilkPrice = result.price or 1
                State.NextPriceChangeTime = result.nextRepickTime or 0
            elseif type(result) == "number" then
                -- Fallback if it ever returns just a number
                State.CurrentMilkPrice = result
            end
        end)
    end
end)

-- Auto Merchant
spawn(function()
    while true do
        wait(5)
        if Config.AutoMerchant and State.Merchant then
            local merchant = State.Merchant
            
            if Config.MerchantItem == "CheesePack" or Config.MerchantItem == "Both" then
                if (merchant.CheesePack or 0) > 0 then
                    pcall(function()
                        MerchantBuy:FireServer("CheesePack")
                    end)
                end
            end
            
            if Config.MerchantItem == "TicketPack" or Config.MerchantItem == "Both" then
                if (merchant.TicketPack or 0) > 0 then
                    pcall(function()
                        MerchantBuy:FireServer("TicketPack")
                    end)
                end
            end
        end
    end
end)

-- Auto Upgrades (SkillTreeConfig uses .Nodes array, costs are .Money or .TotalRolls)
spawn(function()
    while true do
        wait(5)
        if Config.AutoUpgrades then
            local success, data = pcall(function()
                return GetSkillTreeData:InvokeServer()
            end)
            
            if success and data and type(data) == "table" then
                -- data from GetSkillTreeData has the player's unlocked skills and effects
                local unlockedSkills = data.UnlockedSkills or {}
                
                -- Try to require the SkillTreeConfig to get node definitions
                local configOk, SkillTreeConfig = pcall(function()
                    return require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
                end)
                
                if configOk and SkillTreeConfig and SkillTreeConfig.Nodes then
                    for _, node in ipairs(SkillTreeConfig.Nodes) do
                        if not unlockedSkills[node.id] then
                            -- Check prerequisites
                            local canBuy = true
                            if node.prereq then
                                for _, prereqId in ipairs(node.prereq) do
                                    if not unlockedSkills[prereqId] then
                                        canBuy = false
                                        break
                                    end
                                end
                            end
                            
                            if canBuy and node.cost then
                                -- Check if we can afford
                                local canAfford = true
                                if node.cost.Money and State.Money < node.cost.Money then
                                    canAfford = false
                                end
                                if node.cost.TotalRolls and State.TotalRolls < node.cost.TotalRolls then
                                    canAfford = false
                                end
                                
                                if canAfford then
                                    local shouldBuy = false
                                    
                                    if Config.UpgradeMode == "Smart" then
                                        -- Prioritize: Luck, RollSpeed, AutoRoll, EquipSlots
                                        local priorityTypes = {
                                            "Luck", "RollSpeed", "AutoRoll", "EquipSlots",
                                            "Composite" -- starter node
                                        }
                                        
                                        if node.effect and node.effect.Type then
                                            for _, pType in ipairs(priorityTypes) do
                                                if node.effect.Type == pType then
                                                    shouldBuy = true
                                                    break
                                                end
                                            end
                                        end
                                        -- Always buy if no effect (starter nodes)
                                        if not node.effect then
                                            shouldBuy = true
                                        end
                                    else
                                        shouldBuy = true -- Buy all available
                                    end
                                    
                                    if shouldBuy then
                                        pcall(function()
                                            PurchaseSkill:FireServer(node.id)
                                        end)
                                        wait(0.5)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Equip Best
spawn(function()
    while true do
        wait(10)
        if Config.AutoEquipBest then
            TriggerEquipBest()
        end
    end
end)

-- Auto Rebirth
spawn(function()
    while true do
        wait(Config.RebirthCheckInterval)
        if Config.AutoRebirth then
            local success, info = pcall(function()
                return GetRebirthInfo:InvokeServer()
            end)
            
            if success and info and type(info) == "table" and info.CanAfford then
                pcall(function()
                    Rebirth:FireServer()
                end)
                print("[HatchCowsAuto] Rebirth performed!")
                wait(3)
                
                -- Re-equip best after rebirth
                if Config.AutoEquipBest then
                    wait(2)
                    TriggerEquipBest()
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════
-- STATUS LABEL UPDATER
-- ══════════════════════════════════════════════════════════
local function FormatMoney(n)
    if not n then return "0" end
    local abs = math.abs(n)
    local result
    if abs >= 1e12 then
        result = string.format("%.1ft", abs / 1e12)
    elseif abs >= 1e9 then
        result = string.format("%.1fb", abs / 1e9)
    elseif abs >= 1e6 then
        result = string.format("%.1fm", abs / 1e6)
    elseif abs >= 1e3 then
        result = string.format("%.1fk", abs / 1e3)
    else
        result = tostring(math.floor(abs))
    end
    result = result:gsub("%.0([kmbt])", "%1") -- remove ".0" suffixes
    if n < 0 then result = "-" .. result end
    return result
end

spawn(function()
    while true do
        wait(3)
        pcall(function()
            MoneyLabel:Set("Money: " .. FormatMoney(State.Money))
            MilkLabel:Set("Milk: " .. FormatMoney(State.Milk))
            RollsLabel:Set("Total Rolls: " .. FormatMoney(State.TotalRolls))
            PriceLabel:Set("Milk Price: " .. tostring(State.CurrentMilkPrice) .. "$/unit")
            
            if State.Merchant then
                local cheese = State.Merchant.CheesePack or 0
                local ticket = State.Merchant.TicketPack or 0
                MerchantLabel:Set("Merchant: Cheese=" .. cheese .. " Ticket=" .. ticket)
            else
                MerchantLabel:Set("Merchant: N/A")
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════
-- INITIALIZATION
-- ══════════════════════════════════════════════════════════
LoadConfig()

-- Initial price fetch
spawn(function()
    wait(2)
    pcall(function()
        local result = GetMilkPrice:InvokeServer()
        if result and type(result) == "table" then
            State.CurrentMilkPrice = result.price or 1
            State.NextPriceChangeTime = result.nextRepickTime or 0
        end
    end)
end)

-- If auto hatch was saved as on, re-enable it after a delay
spawn(function()
    wait(5)
    if Config.AutoHatch and _G.__setAuto then
        pcall(function() _G.__setAuto(true) end)
    end
end)

print("[HatchCowsAuto] Loaded successfully!")
