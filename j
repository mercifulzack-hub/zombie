--[[
    Hatch Cows Fully Automated Script
    Features:
    - Auto Hatch/Roll
    - Auto Sell Milk (with price thresholds)
    - Auto Buy from Merchant
    - Auto Skill Tree Upgrades (smart)
    - Auto Equip Best Cows
    - Auto Rebirth (when affordable)
    - Anti-AFK
    - Settings persistence
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Events
local Events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
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

-- UI References
local CowSimulatorGui = PlayerGui:WaitForChild("CowSimulatorGui")
local BackpackPanelNEW = CowSimulatorGui:WaitForChild("BackpackPanelNEW")
local EquipBest = BackpackPanelNEW:FindFirstChild("EquipBest")

-- Config
local Config = {
    AutoHatch = false,
    AutoSell = false,
    SellThreshold = "Average", -- Low, Average, Good, Insane
    AutoMerchant = false,
    MerchantItem = "CheesePack", -- CheesePack, TicketPack, Both
    AutoUpgrades = false,
    UpgradeMode = "Smart", -- Smart, All
    AutoEquipBest = false,
    AutoRebirth = false,
    AntiAFK = true,
    MinRollDelay = 0.5,
    AutoSellInterval = 30,
    RebirthCheckInterval = 10
}

-- State
local State = {
    CurrentMilkPrice = 1,
    NextPriceChange = 0,
    IsRolling = false,
    LastAction = tick(),
    Inventory = {},
    Equipped = {},
    SkillTreeData = nil,
    Money = 0,
    Milk = 0,
    Rolls = 0
}

-- Price thresholds (1-20)
local PriceThresholds = {
    Low = 5,
    Average = 10,
    Good = 15,
    Insane = 18
}

-- UI Library (simplified, compatible with existing)
local UI = {}

function UI:Create(name)
    local existing = PlayerGui:FindFirstChild(name)
    if existing then existing:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = name
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
    
    return ScreenGui
end

function UI:CreateMainGUI()
    local gui = self:Create("HatchCowsAutoGUI")
    
    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "MainFrame"
    Main.Size = UDim2.new(0, 300, 0, 420)
    Main.Position = UDim2.new(0, 10, 0.5, -210)
    Main.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    
    -- Corner
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = Main
    
    -- Stroke
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(255, 200, 80)
    Stroke.Thickness = 2
    Stroke.Parent = Main
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    Title.Text = "🐄 Hatch Cows Auto"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.FredokaOne
    Title.Parent = Main
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    -- Toggle Button
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleBtn"
    ToggleBtn.Size = UDim2.new(0, 30, 0, 30)
    ToggleBtn.Position = UDim2.new(1, -35, 0, 5)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    ToggleBtn.Text = "-"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize = 20
    ToggleBtn.Font = Enum.Font.FredokaOne
    ToggleBtn.Parent = Main
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleBtn
    
    -- Scroll Frame
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = "Scroll"
    Scroll.Size = UDim2.new(1, -20, 1, -60)
    Scroll.Position = UDim2.new(0, 10, 0, 50)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 4
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 80)
    Scroll.Parent = Main
    
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.Parent = Scroll
    
    return gui, Main, Scroll, ToggleBtn
end

function UI:CreateToggle(parent, text, configKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 40)
    Row.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    Row.BorderSizePixel = 0
    Row.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Row
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 14
    Label.Font = Enum.Font.FredokaOne
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    
    local Toggle = Instance.new("TextButton")
    Toggle.Name = "Toggle"
    Toggle.Size = UDim2.new(0, 50, 0, 26)
    Toggle.Position = UDim2.new(1, -60, 0.5, -13)
    Toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 80, 80)
    Toggle.Text = Config[configKey] and "ON" or "OFF"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 12
    Toggle.Font = Enum.Font.FredokaOne
    Toggle.Parent = Row
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 13)
    ToggleCorner.Parent = Toggle
    
    Toggle.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        Toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(200, 80, 80)
        Toggle.Text = Config[configKey] and "ON" or "OFF"
        SaveConfig()
        if callback then callback(Config[configKey]) end
    end)
    
    return Row, Toggle
end

function UI:CreateDropdown(parent, text, options, configKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 70)
    Row.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    Row.BorderSizePixel = 0
    Row.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Row
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 25)
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 13
    Label.Font = Enum.Font.FredokaOne
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    
    local Dropdown = Instance.new("TextButton")
    Dropdown.Size = UDim2.new(1, -20, 0, 30)
    Dropdown.Position = UDim2.new(0, 10, 0, 35)
    Dropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    Dropdown.Text = "▼ " .. Config[configKey]
    Dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    Dropdown.TextSize = 12
    Dropdown.Font = Enum.Font.FredokaOne
    Dropdown.Parent = Row
    
    local DropCorner = Instance.new("UICorner")
    DropCorner.CornerRadius = UDim.new(0, 6)
    DropCorner.Parent = Dropdown
    
    local open = false
    local OptionsFrame = nil
    
    Dropdown.MouseButton1Click:Connect(function()
        open = not open
        if open then
            OptionsFrame = Instance.new("Frame")
            OptionsFrame.Size = UDim2.new(1, 0, 0, #options * 28)
            OptionsFrame.Position = UDim2.new(0, 0, 1, 5)
            OptionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            OptionsFrame.BorderSizePixel = 0
            OptionsFrame.ZIndex = 100
            OptionsFrame.Parent = Dropdown
            
            local OptCorner = Instance.new("UICorner")
            OptCorner.CornerRadius = UDim.new(0, 6)
            OptCorner.Parent = OptionsFrame
            
            for i, opt in ipairs(options) do
                local Opt = Instance.new("TextButton")
                Opt.Size = UDim2.new(1, 0, 0, 26)
                Opt.Position = UDim2.new(0, 0, 0, (i-1) * 28 + 2)
                Opt.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                Opt.Text = opt
                Opt.TextColor3 = Color3.fromRGB(255, 255, 255)
                Opt.TextSize = 12
                Opt.Font = Enum.Font.FredokaOne
                Opt.ZIndex = 101
                Opt.Parent = OptionsFrame
                
                Opt.MouseButton1Click:Connect(function()
                    Config[configKey] = opt
                    Dropdown.Text = "▼ " .. opt
                    open = false
                    OptionsFrame:Destroy()
                    SaveConfig()
                    if callback then callback(opt) end
                end)
            end
        else
            if OptionsFrame then OptionsFrame:Destroy() end
        end
    end)
    
    return Row
end

function UI:CreateLabel(parent, text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 11
    Label.Font = Enum.Font.FredokaOne
    Label.TextXAlignment = Enum.TextXAlignment.Center
    Label.Parent = parent
    return Label
end

-- Config Save/Load
function SaveConfig()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(Config)
    end)
    if success then
        writefile("HatchCowsAuto_Config.json", encoded)
    end
end

function LoadConfig()
    if isfile("HatchCowsAuto_Config.json") then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile("HatchCowsAuto_Config.json"))
        end)
        if success and decoded then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end
end

-- Auto Features
local AutoFeatures = {}

function AutoFeatures:AntiAFK()
    if not Config.AntiAFK then return end
    
    spawn(function()
        while Config.AntiAFK do
            wait(60)
            if tick() - State.LastAction > 300 then -- 5 minutes
                -- Simulate activity
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
    end)
end

function AutoFeatures:AutoHatch()
    spawn(function()
        while wait(Config.MinRollDelay) do
            if Config.AutoHatch and not State.IsRolling then
                -- Check if we have AutoRoll gamepass or enough rolls
                local data = State.SkillTreeData
                if data and data.AutoRoll then
                    -- Use game's built-in auto if available
                    if _G.__setAuto then
                        pcall(function() _G.__setAuto(true) end)
                    end
                else
                    -- Manual roll via the RollButton
                    local RollButton = CowSimulatorGui:FindFirstChild("BottomHUD", true) and 
                                      CowSimulatorGui.BottomHUD:FindFirstChild("RollButton")
                    if RollButton then
                        pcall(function()
                            RollButton.MouseButton1Click:Fire()
                        end)
                    end
                end
            end
        end
    end)
end

function AutoFeatures:AutoSell()
    spawn(function()
        while wait(Config.AutoSellInterval) do
            if Config.AutoSell then
                -- Check current price
                local threshold = PriceThresholds[Config.SellThreshold] or 10
                
                if State.CurrentMilkPrice >= threshold and State.Milk > 0 then
                    -- Find and click sell button or fire remote
                    pcall(function()
                        SellMilk:FireServer()
                    end)
                    
                    -- Also try UI method
                    local ShopPanel = CowSimulatorGui:FindFirstChild("ShopPanel2") or 
                                     CowSimulatorGui:FindFirstChild("ShopPanel")
                    if ShopPanel then
                        local SellBtn = ShopPanel:FindFirstChild("SellAll", true) or
                                       ShopPanel:FindFirstChild("SellAllButton", true)
                        if SellBtn then
                            pcall(function() SellBtn.MouseButton1Click:Fire() end)
                        end
                    end
                end
            end
        end
    end)
end

function AutoFeatures:UpdatePrice()
    spawn(function()
        while wait(10) do
            pcall(function()
                local price, nextChange = GetMilkPrice:InvokeServer()
                if price then
                    State.CurrentMilkPrice = price
                    State.NextPriceChange = nextChange
                end
            end)
        end
    end)
end

function AutoFeatures:AutoMerchant()
    spawn(function()
        while wait(5) do
            if Config.AutoMerchant then
                local data = State.SkillTreeData
                if data and data.Merchant then
                    local merchant = data.Merchant
                    
                    if Config.MerchantItem == "CheesePack" or Config.MerchantItem == "Both" then
                        if merchant.CheesePack and merchant.CheesePack > 0 then
                            pcall(function()
                                MerchantBuy:FireServer("CheesePack")
                            end)
                        end
                    end
                    
                    if Config.MerchantItem == "TicketPack" or Config.MerchantItem == "Both" then
                        if merchant.TicketPack and merchant.TicketPack > 0 then
                            pcall(function()
                                MerchantBuy:FireServer("TicketPack")
                            end)
                        end
                    end
                end
            end
        end
    end)
end

function AutoFeatures:AutoUpgrades()
    spawn(function()
        while wait(3) do
            if Config.AutoUpgrades then
                local success, data = pcall(function()
                    return GetSkillTreeData:InvokeServer()
                end)
                
                if success and data and data.Skills then
                    local skills = data.Skills
                    local skillConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
                    
                    -- Get available nodes
                    for id, node in pairs(skillConfig.ById) do
                        if not skills[id] then -- Not owned
                            -- Check if prerequisites are met
                            local canBuy = true
                            for _, prereq in ipairs(node.prereq or {}) do
                                if not skills[prereq] then
                                    canBuy = false
                                    break
                                end
                            end
                            
                            if canBuy then
                                -- Check cost
                                local canAfford = true
                                if node.cost then
                                    if node.cost.Money and State.Money < node.cost.Money then
                                        canAfford = false
                                    end
                                    if node.cost.TotalRolls and State.Rolls < node.cost.TotalRolls then
                                        canAfford = false
                                    end
                                end
                                
                                if canAfford then
                                    -- Smart mode: prioritize certain upgrades
                                    if Config.UpgradeMode == "Smart" then
                                        local priorityEffects = {
                                            "Luck",
                                            "RollSpeed",
                                            "MilkMultiplier",
                                            "AutoRoll"
                                        }
                                        
                                        local isPriority = false
                                        if node.effect then
                                            for _, effect in ipairs(priorityEffects) do
                                                if node.effect.Type:find(effect) then
                                                    isPriority = true
                                                    break
                                                end
                                            end
                                        end
                                        
                                        if isPriority or not node.effect then
                                            pcall(function()
                                                PurchaseSkill:FireServer(id)
                                            end)
                                            wait(0.5)
                                        end
                                    else
                                        -- Buy all available
                                        pcall(function()
                                            PurchaseSkill:FireServer(id)
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
    end)
end

function AutoFeatures:AutoEquipBest()
    spawn(function()
        while wait(10) do
            if Config.AutoEquipBest then
                -- Click EquipBest button
                if EquipBest then
                    pcall(function()
                        EquipBest.MouseButton1Click:Fire()
                    end)
                end
            end
        end
    end)
end

function AutoFeatures:AutoRebirth()
    spawn(function()
        while wait(Config.RebirthCheckInterval) do
            if Config.AutoRebirth then
                -- Get rebirth info
                local success, info = pcall(function()
                    return GetRebirthInfo:InvokeServer()
                end)
                
                if success and info and info.CanAfford then
                    -- Can afford rebirth - do it
                    pcall(function()
                        Rebirth:FireServer()
                    end)
                    print("[HatchCowsAuto] Rebirth performed!")
                    
                    -- Wait a bit after rebirth for things to reset
                    wait(3)
                    
                    -- Re-equip best if enabled
                    if Config.AutoEquipBest and EquipBest then
                        wait(2)
                        pcall(function()
                            EquipBest.MouseButton1Click:Fire()
                        end)
                    end
                end
            end
        end
    end)
end

function AutoFeatures:TrackData()
    DataUpdate.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            if data.Money then State.Money = data.Money end
            if data.Milk then State.Milk = data.Milk end
            if data.TotalRolls then State.Rolls = data.TotalRolls end
            if data.Inventory then State.Inventory = data.Inventory end
            if data.Equipped then State.Equipped = data.Equipped end
            if data.Settings then State.SkillTreeData = data end
        end
    end)
end

-- Initialize
function Init()
    LoadConfig()
    
    -- Create UI
    local gui, Main, Scroll, ToggleBtn = UI:CreateMainGUI()
    
    -- Add toggles
    UI:CreateToggle(Scroll, "🥚 Auto Hatch", "AutoHatch")
    UI:CreateToggle(Scroll, "💰 Auto Sell Milk", "AutoSell")
    UI:CreateToggle(Scroll, "🛒 Auto Buy Merchant", "AutoMerchant")
    UI:CreateToggle(Scroll, "⬆️ Auto Upgrades", "AutoUpgrades")
    UI:CreateToggle(Scroll, "⭐ Auto Equip Best", "AutoEquipBest")
    UI:CreateToggle(Scroll, "� Auto Rebirth", "AutoRebirth")
    UI:CreateToggle(Scroll, "�️ Anti-AFK", "AntiAFK")
    
    -- Add dropdowns
    UI:CreateDropdown(Scroll, "Sell Threshold:", {"Low", "Average", "Good", "Insane"}, "SellThreshold")
    UI:CreateDropdown(Scroll, "Merchant Item:", {"CheesePack", "TicketPack", "Both"}, "MerchantItem")
    UI:CreateDropdown(Scroll, "Upgrade Mode:", {"Smart", "All"}, "UpgradeMode")
    
    -- Info label
    UI:CreateLabel(Scroll, "Current Milk Price: " .. State.CurrentMilkPrice .. "$/unit")
    
    -- Toggle minimize
    local minimized = false
    ToggleBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Scroll.Visible = not minimized
        ToggleBtn.Text = minimized and "+" or "-"
        Main.Size = minimized and UDim2.new(0, 300, 0, 50) or UDim2.new(0, 300, 0, 420)
    end)
    
    -- Start features
    AutoFeatures:TrackData()
    AutoFeatures:AntiAFK()
    AutoFeatures:AutoHatch()
    AutoFeatures:AutoSell()
    AutoFeatures:UpdatePrice()
    AutoFeatures:AutoMerchant()
    AutoFeatures:AutoUpgrades()
    AutoFeatures:AutoEquipBest()
    AutoFeatures:AutoRebirth()
    
    -- Update price display
    spawn(function()
        while wait(5) do
            local infoLabel = Scroll:FindFirstChildOfClass("TextLabel")
            if infoLabel and infoLabel.Text:find("Milk Price") then
                infoLabel.Text = "Current Milk Price: " .. State.CurrentMilkPrice .. "$/unit"
            end
        end
    end)
    
    print("[HatchCowsAuto] Loaded successfully!")
end

-- Run
pcall(Init)

return Config
