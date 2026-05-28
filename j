--[[
    Hatch Cows Auto - Full Script
    UI: Rayfield (CustomFIeld fork) | No key system
    All remotes verified from game source code.

    Exploitable remotes confirmed:
      AddCow(name, rarityIdx, variant?)  - fires any cow into inventory
      SellMilk()                        - sells all milk
      MerchantBuy(item)                 - buys CheesePack / TicketPack
      PurchaseSkill(id)                 - buys skill tree node
      Rebirth()                         - performs rebirth
      SetSettings(key, value)           - changes server settings
      FuseStart(cow1, cow2)             - starts a fuse
      FuseClaim()                       - claims fuse result
      UseItem(id)                       - uses an item
      ClaimOffline()                    - claims offline earnings
      SyncEquipped(table)               - syncs equipped cow list
]]

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

-- ─── Load Rayfield ────────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua"
))()

-- ─── Verified Remote Events ───────────────────────────────────────────────────
local Shared         = ReplicatedStorage:WaitForChild("Shared")
local Events         = Shared:WaitForChild("Events")

local DataUpdate     = Events:WaitForChild("DataUpdate")
local AddCow         = Events:WaitForChild("AddCow")
local SellMilk       = Events:WaitForChild("SellMilk")
local GetMilkPrice   = Events:WaitForChild("GetMilkPrice")
local MerchantBuy    = Events:WaitForChild("MerchantBuy")
local PurchaseSkill  = Events:WaitForChild("PurchaseSkill")
local GetSkillTreeData = Events:WaitForChild("GetSkillTreeData")
local SyncEquipped   = Events:WaitForChild("SyncEquipped")
local Rebirth        = Events:WaitForChild("Rebirth")
local GetRebirthInfo = Events:WaitForChild("GetRebirthInfo")
local SetSettings    = Events:WaitForChild("SetSettings")
local FuseStart      = Events:WaitForChild("FuseStart")
local FuseClaim      = Events:WaitForChild("FuseClaim")
local UseItem        = Events:WaitForChild("UseItem")
local ClaimOffline   = Events:WaitForChild("ClaimOffline")
local UnlockBiome    = Events:WaitForChild("UnlockBiome")

-- ─── Biome Gate Config ───────────────────────────────────────────────────────
-- Inlined from BiomeGateConfig.lua (in order)
local BIOME_GATES = {
    { biomeId="Biome 2",  biomeName="Desert",       cost=5000 },
    { biomeId="Biome 3",  biomeName="Tundra",        cost=25000 },
    { biomeId="Biome 4",  biomeName="Volcano",       cost=75000 },
    { biomeId="Biome 5",  biomeName="Blossom",       cost=300000 },
    { biomeId="Biome 6",  biomeName="Swamp",         cost=1200000 },
    { biomeId="Biome 7",  biomeName="Crystal Cave",  cost=4200000 },
    { biomeId="Biome 8",  biomeName="Savanna",       cost=21000000 },
    { biomeId="Biome 9",  biomeName="Arctic",        cost=63000000 },
    { biomeId="Biome 10", biomeName="Mushroom",      cost=285000000 },
    { biomeId="Biome 11", biomeName="Jungle",        cost=1000000000 },
    { biomeId="Biome 12", biomeName="Wild West",     cost=4000000000 },
    { biomeId="Biome 13", biomeName="Autumn",        cost=20000000000 },
    { biomeId="Biome 14", biomeName="Haunted",       cost=60000000000 },
    { biomeId="Biome 15", biomeName="Coral Reef",    cost=270000000000 },
    { biomeId="Biome 16", biomeName="Meteor",        cost=950000000000 },
}

-- ─── Game Config ──────────────────────────────────────────────────────────────
-- Inlined from SkillTreeConfig.lua (can't use require() in executor context)
-- Format: { id, branch, prereq={}, cost={Money=n, TotalRolls=n} }
local SKILL_NODES = {
    {id="loot_open",  branch="Loot",      prereq={},            cost={Money=0}},
    {id="auto_roll",  branch="Speed",     prereq={"loot_open"}, cost={Money=500}},
    {id="equip_1",    branch="Equip",     prereq={"loot_open"}, cost={Money=250}},
    {id="equip_2",    branch="Equip",     prereq={"equip_1"},   cost={Money=5000}},
    {id="luck_1",     branch="Luck",      prereq={"auto_roll"}, cost={Money=2000}},
    {id="luck_2",     branch="Luck",      prereq={"luck_1"},    cost={Money=5000}},
    {id="luck_3",     branch="Luck",      prereq={"luck_2"},    cost={Money=12000}},
    {id="luck_4",     branch="SuperLuck", prereq={"luck_3"},    cost={Money=28000}},
    {id="luck_5",     branch="SuperLuck", prereq={"luck_4"},    cost={Money=65000}},
    {id="luck_6",     branch="SuperLuck", prereq={"luck_5"},    cost={Money=150000}},
    {id="luck_7",     branch="SuperLuck", prereq={"luck_6"},    cost={Money=350000}},
    {id="luck_8",     branch="SuperLuck", prereq={"luck_7"},    cost={Money=800000}},
    {id="luck_9",     branch="SuperLuck", prereq={"luck_8"},    cost={Money=1800000}},
    {id="luck_10",    branch="SuperLuck", prereq={"luck_9"},    cost={Money=4000000}},
    {id="luck_11",    branch="SuperLuck", prereq={"luck_10"},   cost={Money=9000000}},
    {id="luck_12",    branch="SuperLuck", prereq={"luck_11"},   cost={Money=20000000}},
    {id="luck_13",    branch="SuperLuck", prereq={"luck_12"},   cost={Money=45000000}},
    {id="luck_14",    branch="SuperLuck", prereq={"luck_13"},   cost={Money=100000000}},
    {id="luck_15",    branch="SuperLuck", prereq={"luck_14"},   cost={Money=220000000}},
    {id="luck_16",    branch="SuperLuck", prereq={"luck_15"},   cost={Money=500000000}},
    {id="luck_17",    branch="SuperLuck", prereq={"luck_16"},   cost={Money=1100000000}},
    {id="luck_18",    branch="SuperLuck", prereq={"luck_17"},   cost={Money=2500000000}},
    {id="luck_19",    branch="SuperLuck", prereq={"luck_18"},   cost={Money=6000000000}},
    {id="luck_20",    branch="SuperLuck", prereq={"luck_19"},   cost={Money=15000000000}},
    {id="speed_1",    branch="Speed",     prereq={"auto_roll"}, cost={TotalRolls=100}},
    {id="speed_2",    branch="Speed",     prereq={"speed_1"},   cost={TotalRolls=500}},
    {id="speed_3",    branch="Speed",     prereq={"speed_2"},   cost={TotalRolls=2000}},
    {id="speed_4",    branch="Speed",     prereq={"speed_3"},   cost={TotalRolls=10000}},
    {id="friend_luck_1",  branch="Friend", prereq={"luck_2"},          cost={Money=1500}},
    {id="friend_luck_2",  branch="Friend", prereq={"friend_luck_1"},   cost={Money=5000}},
    {id="friend_luck_3",  branch="Friend", prereq={"friend_luck_2"},   cost={Money=15000}},
    {id="friend_luck_4",  branch="Friend", prereq={"friend_luck_3"},   cost={Money=40000}},
    {id="friend_luck_5",  branch="Friend", prereq={"friend_luck_4"},   cost={Money=100000}},
    {id="friend_luck_6",  branch="Friend", prereq={"friend_luck_5"},   cost={Money=300000}},
    {id="friend_luck_7",  branch="Friend", prereq={"friend_luck_6"},   cost={Money=800000}},
    {id="friend_luck_8",  branch="Friend", prereq={"friend_luck_7"},   cost={Money=2500000}},
    {id="friend_luck_9",  branch="Friend", prereq={"friend_luck_8"},   cost={Money=7500000}},
    {id="friend_luck_10", branch="Friend", prereq={"friend_luck_9"},   cost={Money=25000000}},
    {id="friend_luck_11", branch="Friend", prereq={"friend_luck_10"},  cost={Money=80000000}},
    {id="friend_luck_12", branch="Friend", prereq={"friend_luck_11"},  cost={Money=250000000}},
    {id="mut_wet",      branch="Mutation", prereq={"loot_unlock"}, cost={Money=5000}},
    {id="mut_thick",    branch="Mutation", prereq={"mut_wet"},     cost={Money=15000}},
    {id="mut_sweet",    branch="Mutation", prereq={"mut_thick"},   cost={Money=50000}},
    {id="mut_golden",   branch="Mutation", prereq={"mut_sweet"},   cost={Money=200000}},
    {id="mut_crystal",  branch="Mutation", prereq={"mut_golden"},  cost={Money=1500000}},
    {id="mut_toxic",    branch="Mutation", prereq={"mut_crystal"},  cost={Money=15000000}},
    {id="mut_frozen",   branch="Mutation", prereq={"mut_toxic"},   cost={Money=150000000}},
    {id="mut_void",     branch="Mutation", prereq={"mut_frozen"},  cost={Money=2000000000}},
    {id="mut_rainbow",  branch="Mutation", prereq={"mut_void"},    cost={Money=30000000000}},
    {id="mut_celestial",branch="Mutation", prereq={"mut_rainbow"}, cost={Money=500000000000}},
}

local CowSimulatorGui = PlayerGui:WaitForChild("CowSimulatorGui")

-- All cow names + rarity index from CowData.lua (verified)
-- Format: { name, rarityIndex }
local ALL_COWS = {
    {"Bamboo",1},{"Choco",1},{"Ivy",2},{"Mushy",2},{"Camo",2},{"Scriblo",2},
    {"Reefy",3},{"Minty",3},{"Buzzly",3},{"Moss",3},{"Frosty",4},{"Jackmoo",4},
    {"Medic",4},{"Citrush",4},{"Poppy",4},{"Voltmo",5},{"Puffy",5},{"Bloomsy",5},
    {"Voltix",6},{"Sweeto",6},{"Sakury",6},{"Obsy",6},{"Arcanox",7},{"Bugzo",7},
    {"Hexmoo",7},{"Voidor",8},{"Splashy",8},{"Mecha",8},{"Magmoo",8},{"Jelly",8},
    {"Grimoo",8},{"Glowbyte",9},{"Hornox",9},{"Toxsy",9},{"Corruptor",9},
    {"Bloodfang",10},{"Dracox",10},{"Matrix",10},{"Vexoo",10},{"Wake",11},
    {"Solar",11},{"Boo",11},{"Chrono",11},{"Nullix",11},{"Hexie",12},
    {"Parasite",12},{"Sprazy",12},{"Toy",13},{"Ronin",13},{"Xenmoo",13},
    {"Diavox",14},{"Reaper",14},
}

-- Build name-only list for dropdown
local COW_NAMES = {}
for _, v in ipairs(ALL_COWS) do
    table.insert(COW_NAMES, v[1])
end

-- Build lookup: name -> rarityIndex
local COW_RARITY = {}
for _, v in ipairs(ALL_COWS) do
    COW_RARITY[v[1]] = v[2]
end

-- Priority skill branches for smart upgrades (from SkillTreeConfig.lua)
local PRIORITY_BRANCHES = { Luck=true, SuperLuck=true, Speed=true, Milk=true }

-- ─── State ────────────────────────────────────────────────────────────────────
local State = {
    Money        = 0,
    Milk         = 0,
    Rolls        = 0,
    MilkPrice       = 1,
    MerchantData    = nil,
    UnlockedBiomes  = {},
    LastActivity    = tick(),
}

-- ─── Config Flags ─────────────────────────────────────────────────────────────
local Cfg = {
    AutoHatch      = false,
    AutoSell       = false,
    SellThreshold  = 10,
    AutoMerchant   = false,
    MerchantItem   = "CheesePack",
    AutoUpgrades   = false,
    SmartUpgrades  = true,
    AutoEquipBest  = false,
    AutoRebirth    = false,
    AntiAFK        = false,
    AutoUnlockBiome = false,
    -- Spawn cow settings
    SelectedCow    = "Reaper",
}

-- ─── Data Tracking ────────────────────────────────────────────────────────────
DataUpdate.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    if data.Money      ~= nil then State.Money        = data.Money end
    if data.Milk       ~= nil then State.Milk         = data.Milk  end
    if data.TotalRolls ~= nil then State.Rolls        = data.TotalRolls end
    if data.Merchant        ~= nil then State.MerchantData    = data.Merchant end
    if data.UnlockedBiomes  ~= nil then State.UnlockedBiomes = data.UnlockedBiomes end
    State.LastActivity = tick()
end)

-- ─── Auto Hatch ───────────────────────────────────────────────────────────────
-- Uses game's _G.__setAuto (CowController.client.lua:1337)
task.spawn(function()
    while task.wait(0.5) do
        if not Cfg.AutoHatch then continue end
        if _G.__setAuto then
            if _G.__autoOn and not _G.__autoOn() then
                pcall(_G.__setAuto, true)
            end
        end
    end
end)

-- ─── Auto Sell Milk ───────────────────────────────────────────────────────────
-- SellMilk:FireServer() (ShopUI.lua:532,558) | GetMilkPrice:InvokeServer() (ShopUI.lua:354)
task.spawn(function()
    while task.wait(15) do
        if not Cfg.AutoSell then continue end
        pcall(function()
            local price = GetMilkPrice:InvokeServer()
            if price then State.MilkPrice = price end
        end)
        if State.Milk > 0 and State.MilkPrice >= Cfg.SellThreshold then
            pcall(function() SellMilk:FireServer() end)
        end
    end
end)

-- ─── Auto Merchant ────────────────────────────────────────────────────────────
-- MerchantBuy:FireServer(item) (MerchantController.client.lua:196-208)
task.spawn(function()
    while task.wait(5) do
        if not Cfg.AutoMerchant then continue end
        local m = State.MerchantData
        if not m then continue end
        if (Cfg.MerchantItem == "CheesePack" or Cfg.MerchantItem == "Both") and (m.CheesePack or 0) > 0 then
            pcall(function() MerchantBuy:FireServer("CheesePack") end)
        end
        if (Cfg.MerchantItem == "TicketPack" or Cfg.MerchantItem == "Both") and (m.TicketPack or 0) > 0 then
            pcall(function() MerchantBuy:FireServer("TicketPack") end)
        end
    end
end)

-- ─── Auto Upgrades ────────────────────────────────────────────────────────────
-- PurchaseSkill:FireServer(id) (SkillTreeController.client.lua:658)
-- GetSkillTreeData:InvokeServer() returns { OwnedNodes={}, Skills={} }
task.spawn(function()
    while task.wait(4) do
        if not Cfg.AutoUpgrades then continue end
        local ok, data = pcall(function() return GetSkillTreeData:InvokeServer() end)
        if not ok or not data then continue end
        local owned = data.OwnedNodes or data.Skills or {}

        for _, node in ipairs(SKILL_NODES) do
            local id = node.id
            if owned[id] then continue end

            local prereqMet = true
            for _, pre in ipairs(node.prereq or {}) do
                if not owned[pre] then prereqMet = false; break end
            end
            if not prereqMet then continue end

            local cost = node.cost or {}
            if State.Money < (cost.Money or 0) then continue end
            if State.Rolls  < (cost.TotalRolls or 0) then continue end

            if Cfg.SmartUpgrades and not PRIORITY_BRANCHES[node.branch] then continue end

            pcall(function() PurchaseSkill:FireServer(id) end)
            task.wait(0.4)
        end
    end
end)

-- ─── Auto Equip Best ─────────────────────────────────────────────────────────
task.spawn(function()
    while task.wait(10) do
        if not Cfg.AutoEquipBest then continue end
        local bp = CowSimulatorGui:FindFirstChild("BackpackPanelNEW")
        if not bp then continue end
        local btn = bp:FindFirstChild("EquipBest") or bp:FindFirstChild("EquipBestButton")
        if btn then pcall(function() btn.MouseButton1Click:Fire() end) end
    end
end)

-- ─── Auto Rebirth ─────────────────────────────────────────────────────────────
-- Rebirth:FireServer() | GetRebirthInfo:InvokeServer() (RebirthPanel.lua:270,148)
task.spawn(function()
    while task.wait(10) do
        if not Cfg.AutoRebirth then continue end
        local ok, info = pcall(function() return GetRebirthInfo:InvokeServer() end)
        if ok and info and info.CanAfford then
            pcall(function() Rebirth:FireServer() end)
            print("[HatchCowsAuto] Rebirth performed!")
            task.wait(3)
            if Cfg.AutoEquipBest then
                local bp = CowSimulatorGui:FindFirstChild("BackpackPanelNEW")
                if bp then
                    local btn = bp:FindFirstChild("EquipBest") or bp:FindFirstChild("EquipBestButton")
                    if btn then pcall(function() btn.MouseButton1Click:Fire() end) end
                end
            end
        end
    end
end)

-- ─── Teleport helper ────────────────────────────────────────────────────────
local function tpToBiome(biomeId)
    local gates = workspace:FindFirstChild("New Gates")
    if not gates then return end
    for _, g in ipairs(gates:GetChildren()) do
        if g:GetAttribute("BiomeId") == biomeId then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local pos = g:GetPivot().Position + Vector3.new(0, 5, 15)
                root.CFrame = CFrame.new(pos)
                print("[HatchCowsAuto] Teleported to " .. biomeId)
            end
            return
        end
    end
end

-- ─── Auto Unlock Biome ──────────────────────────────────────────────────────
-- UnlockBiome:FireServer(biomeId) confirmed in BiomeGatesClient.lua:709
-- Server checks Money >= cost and that biome isn't already unlocked
task.spawn(function()
    while task.wait(8) do
        if not Cfg.AutoUnlockBiome then continue end
        for _, gate in ipairs(BIOME_GATES) do
            if not State.UnlockedBiomes[gate.biomeId] then
                if State.Money >= gate.cost then
                    pcall(function() UnlockBiome:FireServer(gate.biomeId) end)
                    print("[HatchCowsAuto] Unlocked biome: " .. gate.biomeName)
                    task.wait(2)
                    tpToBiome(gate.biomeId)
                end
                break
            end
        end
    end
end)

-- ─── Anti-AFK ─────────────────────────────────────────────────────────────────
task.spawn(function()
    while task.wait(60) do
        if not Cfg.AntiAFK then continue end
        if tick() - State.LastActivity > 240 then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true
                task.wait(0.1)
                hum.Jump = false
            end
            State.LastActivity = tick()
        end
    end
end)

-- ─── Rayfield Window ─────────────────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name            = "Hatch Cows Auto",
    LoadingTitle    = "Hatch Cows Auto",
    LoadingSubtitle = "Initialising...",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "HatchCowsAuto",
        FileName   = "Config",
    },
    Discord   = { Enabled = false },
    KeySystem = false,
})

-- ══ Tab: Automation ══════════════════════════════════════════════════════════
local AutoTab = Window:CreateTab("Automation", 4483362458)

AutoTab:CreateSection("Hatching", false)

AutoTab:CreateToggle({
    Name         = "Auto Hatch",
    Info         = "Keeps the game's built-in auto-roll running via _G.__setAuto.",
    CurrentValue = false,
    Flag         = "AutoHatch",
    Callback     = function(v)
        Cfg.AutoHatch = v
        if v and _G.__setAuto then pcall(_G.__setAuto, true) end
    end,
})

AutoTab:CreateSection("Selling", false)

AutoTab:CreateToggle({
    Name         = "Auto Sell Milk",
    Info         = "Fires SellMilk to server when price meets your threshold.",
    CurrentValue = false,
    Flag         = "AutoSell",
    Callback     = function(v) Cfg.AutoSell = v end,
})

AutoTab:CreateDropdown({
    Name          = "Sell Threshold",
    Info          = "Minimum milk price (out of 20) before auto-selling.",
    Options       = {"Low (5)", "Average (10)", "Good (15)", "Insane (18)"},
    CurrentOption = "Average (10)",
    MultiSelection = false,
    Flag          = "SellThreshold",
    Callback      = function(opt)
        local map = {["Low (5)"]=5,["Average (10)"]=10,["Good (15)"]=15,["Insane (18)"]=18}
        Cfg.SellThreshold = map[opt] or 10
    end,
})

AutoTab:CreateSection("Merchant", false)

AutoTab:CreateToggle({
    Name         = "Auto Buy Merchant",
    Info         = "Fires MerchantBuy when the Travelling Merchant has stock.",
    CurrentValue = false,
    Flag         = "AutoMerchant",
    Callback     = function(v) Cfg.AutoMerchant = v end,
})

AutoTab:CreateDropdown({
    Name          = "Merchant Item",
    Info          = "Which item to buy from the merchant.",
    Options       = {"CheesePack", "TicketPack", "Both"},
    CurrentOption = "CheesePack",
    MultiSelection = false,
    Flag          = "MerchantItem",
    Callback      = function(opt) Cfg.MerchantItem = opt end,
})

AutoTab:CreateSection("Upgrades", false)

AutoTab:CreateToggle({
    Name         = "Auto Upgrades",
    Info         = "Purchases skill tree nodes via PurchaseSkill when affordable.",
    CurrentValue = false,
    Flag         = "AutoUpgrades",
    Callback     = function(v) Cfg.AutoUpgrades = v end,
})

AutoTab:CreateToggle({
    Name         = "Smart Upgrades",
    Info         = "Only buy Luck, SuperLuck, Speed and Milk branches first.",
    CurrentValue = true,
    Flag         = "SmartUpgrades",
    Callback     = function(v) Cfg.SmartUpgrades = v end,
})

AutoTab:CreateSection("Cows & Rebirth", false)

AutoTab:CreateToggle({
    Name         = "Auto Equip Best",
    Info         = "Clicks the Equip Best button every 10 seconds.",
    CurrentValue = false,
    Flag         = "AutoEquipBest",
    Callback     = function(v) Cfg.AutoEquipBest = v end,
})

AutoTab:CreateToggle({
    Name         = "Auto Rebirth",
    Info         = "Fires Rebirth as soon as GetRebirthInfo returns CanAfford=true.",
    CurrentValue = false,
    Flag         = "AutoRebirth",
    Callback     = function(v) Cfg.AutoRebirth = v end,
})

AutoTab:CreateSection("Worlds", false)

AutoTab:CreateToggle({
    Name         = "Auto Unlock Next World",
    Info         = "Fires UnlockBiome when you can afford the next locked biome. Checks every 8 seconds.",
    CurrentValue = false,
    Flag         = "AutoUnlockBiome",
    Callback     = function(v) Cfg.AutoUnlockBiome = v end,
})

-- ══ Tab: Spawn Cow ═══════════════════════════════════════════════════════════
-- AddCow:FireServer(name, rarityIndex, variant?) confirmed exploitable
local SpawnTab = Window:CreateTab("Spawn Cow")

SpawnTab:CreateSection("Add Any Cow", false)

SpawnTab:CreateParagraph({
    Title   = "How it works",
    Content = "Fires AddCow to the server with the selected cow name and its rarity index. The server adds it directly to your inventory.",
})

SpawnTab:CreateDropdown({
    Name          = "Select Cow",
    Info          = "Choose which cow to add to your inventory.",
    Options       = COW_NAMES,
    CurrentOption = "Reaper",
    MultiSelection = false,
    Flag          = "SelectedCow",
    Callback      = function(opt) Cfg.SelectedCow = opt end,
})

SpawnTab:CreateButton({
    Name     = "Spawn Selected Cow",
    Info     = "Fires AddCow:FireServer(name, rarityIndex) to add it now.",
    Interact = "Spawn",
    Callback = function()
        local name = Cfg.SelectedCow
        local rarity = COW_RARITY[name] or 1
        local ok, err = pcall(function()
            AddCow:FireServer(name, rarity)
        end)
        if ok then
            print("[HatchCowsAuto] Spawned cow: " .. name .. " (rarity " .. rarity .. ")")
        else
            warn("[HatchCowsAuto] AddCow failed: " .. tostring(err))
        end
    end,
})

SpawnTab:CreateButton({
    Name     = "Spam Best Cow (Reaper x10)",
    Info     = "Fires AddCow 10 times for Reaper (rarity 14).",
    Interact = "Spam",
    Callback = function()
        for i = 1, 10 do
            pcall(function() AddCow:FireServer("Reaper", 14) end)
            task.wait(0.15)
        end
        print("[HatchCowsAuto] Spammed 10x Reaper")
    end,
})

SpawnTab:CreateSection("Claim Offline Earnings", false)

SpawnTab:CreateButton({
    Name     = "Claim Offline Earnings",
    Info     = "Fires ClaimOffline:FireServer() to instantly collect offline money.",
    Interact = "Claim",
    Callback = function()
        pcall(function() ClaimOffline:FireServer() end)
        print("[HatchCowsAuto] Claimed offline earnings")
    end,
})

-- ══ Tab: Settings ════════════════════════════════════════════════════════════
local SettingsTab = Window:CreateTab("Settings")

SettingsTab:CreateSection("Anti-AFK", false)

SettingsTab:CreateToggle({
    Name         = "Anti-AFK",
    Info         = "Jumps every 4 minutes of inactivity to prevent kick.",
    CurrentValue = false,
    Flag         = "AntiAFK",
    Callback     = function(v)
        Cfg.AntiAFK = v
        pcall(function() SetSettings:FireServer("antiAfk", v) end)
    end,
})

SettingsTab:CreateSection("Quick Actions", false)

SettingsTab:CreateButton({
    Name     = "Sell Milk Now",
    Info     = "Immediately fires SellMilk regardless of price.",
    Interact = "Sell",
    Callback = function()
        pcall(function() SellMilk:FireServer() end)
        print("[HatchCowsAuto] Sold milk")
    end,
})

SettingsTab:CreateButton({
    Name     = "Claim Fuse",
    Info     = "Fires FuseClaim:FireServer() to collect a pending fuse.",
    Interact = "Claim",
    Callback = function()
        pcall(function() FuseClaim:FireServer() end)
        print("[HatchCowsAuto] Claimed fuse")
    end,
})

print("[HatchCowsAuto] Loaded successfully!")
