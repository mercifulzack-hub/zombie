local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local STARTUP_TIMEOUT = 10
local REQUEST_CONFIRM_TIMEOUT
local pendingPlacement
local setRuntimeStatus

local function loadRequiredModule(modulePath)
    local ok, result = pcall(function()
        return require(modulePath)
    end)

    if not ok then
        warn("[AutoPlace] Failed to load module: " .. modulePath:GetFullName() .. " | " .. tostring(result))
        return nil
    end

    return result
end

local function waitForChildSafe(parent, childName, timeout)
    if not parent then
        return nil
    end

    local existing = parent:FindFirstChild(childName)
    if existing then
        return existing
    end

    local found = parent:WaitForChild(childName, timeout)
    if found then
        return found
    end

    warn(string.format("[AutoPlace] Missing %s after %ss under %s", childName, tostring(timeout), parent:GetFullName()))
    return nil
end

local function startsWith(text, prefix)
    if typeof(text) ~= "string" or typeof(prefix) ~= "string" then
        return false
    end

    return string.sub(text, 1, #prefix) == prefix
end

local function countOwnedSpawns(cardName, placeType, mySide)
    if placeType == "Spell" then
        return 0
    end

    local count = 0

    if placeType == "Unit" then
        local registry = Workspace:FindFirstChild("NpcRegistryCamera")
        if not registry then
            return 0
        end

        for _, child in ipairs(registry:GetChildren()) do
            if child:IsA("Folder") then
                for _, model in ipairs(child:GetChildren()) do
                    if model:IsA("Model") then
                        local ownerUserId = model:GetAttribute("OwnerUserId")
                        if ownerUserId == LocalPlayer.UserId and startsWith(model.Name, cardName) then
                            count += 1
                        end
                    end
                end
            elseif child:IsA("Model") then
                local ownerUserId = child:GetAttribute("OwnerUserId")
                if ownerUserId == LocalPlayer.UserId and startsWith(child.Name, cardName) then
                    count += 1
                end
            end
        end

        return count
    end

    local map = Workspace:FindFirstChild("Map")
    local arena = map and map:FindFirstChild("Arena")
    if not arena then
        return 0
    end

    local sideSuffix = mySide and ("_" .. mySide) or nil
    for _, item in ipairs(arena:GetChildren()) do
        if startsWith(item.Name, cardName) then
            if not sideSuffix or string.find(item.Name, sideSuffix, 1, true) then
                count += 1
            end
        end
    end

    return count
end

local function checkPendingPlacement(now, currentEnergy, mySide)
    if not pendingPlacement then
        return
    end

    local expectedEnergyDrop = math.max(0.8, pendingPlacement.expectedCost * 0.55)
    if typeof(currentEnergy) == "number" and typeof(pendingPlacement.energyBefore) == "number" then
        local drop = pendingPlacement.energyBefore - currentEnergy
        if drop >= expectedEnergyDrop then
            setRuntimeStatus("ok", string.format("Confirmed %s (%s)", pendingPlacement.cardName, pendingPlacement.placeType), true)
            pendingPlacement = nil
            return
        end
    end

    if pendingPlacement.placeType ~= "Spell" then
        local currentCount = countOwnedSpawns(pendingPlacement.cardName, pendingPlacement.placeType, mySide)
        if currentCount > pendingPlacement.spawnCountBefore then
            setRuntimeStatus("ok", string.format("Confirmed %s (%s)", pendingPlacement.cardName, pendingPlacement.placeType), true)
            pendingPlacement = nil
            return
        end
    end

    if now - pendingPlacement.sentAt >= REQUEST_CONFIRM_TIMEOUT then
        setRuntimeStatus("warn", string.format("Not confirmed: %s", pendingPlacement.cardName), true)
        pendingPlacement = nil
    end
end

local function findModuleScript(root, moduleName)
    if not root then
        return nil
    end

    local direct = root:FindFirstChild(moduleName)
    if direct and direct:IsA("ModuleScript") then
        return direct
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("ModuleScript") and descendant.Name == moduleName then
            return descendant
        end
    end

    return nil
end

local function requireNamedModule(modulesRoot, moduleName)
    local moduleScript = findModuleScript(modulesRoot, moduleName)
    if not moduleScript then
        local maybeChild = waitForChildSafe(modulesRoot, moduleName, STARTUP_TIMEOUT)
        if maybeChild and maybeChild:IsA("ModuleScript") then
            moduleScript = maybeChild
        end
    end

    if not moduleScript then
        warn("[AutoPlace] Required module not found: " .. moduleName)
        return nil
    end

    return loadRequiredModule(moduleScript)
end

local modulesFolder = waitForChildSafe(ReplicatedStorage, "Modules", STARTUP_TIMEOUT)
local remotesFolder = waitForChildSafe(ReplicatedStorage, "Remotes", STARTUP_TIMEOUT)
local startupWarnings = {}

if not modulesFolder or not remotesFolder then
    warn("[AutoPlace] Startup failed: ReplicatedStorage children missing")
    return
end

local EnergyShared = requireNamedModule(modulesFolder, "EnergyShared")
local CardInfo = requireNamedModule(modulesFolder, "CardInfo")
local PlaceRemote = remotesFolder:FindFirstChild("Place") or remotesFolder:WaitForChild("Place", STARTUP_TIMEOUT)
local assetsFolder = waitForChildSafe(ReplicatedStorage, "Assets", STARTUP_TIMEOUT)
local modelsFolder = assetsFolder and assetsFolder:FindFirstChild("Models")

if not PlaceRemote then
    warn("[AutoPlace] Startup failed: missing Place remote")
    return
end

if type(CardInfo) ~= "table" then
    CardInfo = {}
    table.insert(startupWarnings, "CardInfo unavailable, using UI fallback")
    warn("[AutoPlace] CardInfo unavailable, using UI fallback data")
end

if not EnergyShared then
    table.insert(startupWarnings, "EnergyShared unavailable, using UI fallback")
    warn("[AutoPlace] EnergyShared unavailable, using UI fallback energy")
end

local TileHandler
pcall(function()
    local tileModule = findModuleScript(modulesFolder, "TileHandler")
    if not tileModule then
        local maybeTileChild = waitForChildSafe(modulesFolder, "TileHandler", STARTUP_TIMEOUT)
        if maybeTileChild and maybeTileChild:IsA("ModuleScript") then
            tileModule = maybeTileChild
        end
    end

    if tileModule then
        TileHandler = require(tileModule)
    end
end)

local isAutoPlacing = false
local fallbackDeck = {
    "Swordman",
    "Archer",
    "Tank"
}

local SCAN_INTERVAL = 0.2
local UNIT_FALLBACK_SCAN_INTERVAL = 1.2
local DECK_REFRESH_INTERVAL = 0.2
local PLACE_COOLDOWN = 1.1
REQUEST_CONFIRM_TIMEOUT = 1.8

local lastScanAt = 0
local lastDeckRefreshAt = 0
local lastPlaceAt = 0
local lastFallbackUnitScanAt = 0
local lastHeartbeatStatusAt = 0
local lastStatusText = ""

local cachedScan = nil
local cachedDeck = table.clone(fallbackDeck)
local cachedFallbackEnemyUnits = {}
local uiCardInfoCache = {}
pendingPlacement = nil

local uiRefs = {
    root = nil,
    panel = nil,
    stateLabel = nil,
    statusLabel = nil,
    stateDot = nil,
    toggleTrack = nil,
    toggleKnob = nil
}

local function getStatusColor(level)
    if level == "ok" then
        return Color3.fromRGB(74, 222, 128)
    end
    if level == "warn" then
        return Color3.fromRGB(251, 191, 36)
    end
    if level == "error" then
        return Color3.fromRGB(248, 113, 113)
    end

    return Color3.fromRGB(148, 163, 184)
end

setRuntimeStatus = function(level, text, force)
    local status = tostring(text or "")
    if status == "" then
        return
    end

    if not force and status == lastStatusText then
        return
    end

    lastStatusText = status
    local message = string.format("[AutoPlace][%s] %s", string.upper(level or "info"), status)
    if level == "error" then
        warn(message)
    else
        print(message)
    end

    if uiRefs.statusLabel then
        uiRefs.statusLabel.Text = "Status: " .. status
        uiRefs.statusLabel.TextColor3 = getStatusColor(level)
    end
end

local function getMySide()
    return LocalPlayer:GetAttribute("Side")
end

local function parseFirstNumber(text)
    if typeof(text) == "number" then
        return text
    end

    if typeof(text) ~= "string" then
        return nil
    end

    local value = string.match(text, "[-+]?%d+%.?%d*")
    return value and tonumber(value) or nil
end

local function getCardData(cardName)
    local cardData = CardInfo and CardInfo[cardName]
    if typeof(cardData) == "table" then
        return cardData
    end

    return uiCardInfoCache[cardName]
end

local function inferCardType(cardName)
    local cached = uiCardInfoCache[cardName]
    if cached and cached.CardType and cached.CardType ~= "" then
        return cached.CardType
    end

    local lowerName = string.lower(tostring(cardName or ""))
    if lowerName:find("arrow", 1, true)
        or lowerName:find("fireball", 1, true)
        or lowerName:find("rocket", 1, true)
        or lowerName:find("zap", 1, true)
        or lowerName:find("freeze", 1, true)
        or lowerName:find("poison", 1, true)
        or lowerName:find("rage", 1, true)
        or lowerName:find("lightning", 1, true)
        or lowerName:find("tornado", 1, true)
        or lowerName:find("snowball", 1, true)
        or lowerName:find("spell", 1, true)
    then
        return "Spell"
    end

    if lowerName:find("tower", 1, true)
        or lowerName:find("cannon", 1, true)
        or lowerName:find("barrack", 1, true)
        or lowerName:find("tesla", 1, true)
        or lowerName:find("furnace", 1, true)
        or lowerName:find("hut", 1, true)
        or lowerName:find("building", 1, true)
    then
        return "Building"
    end

    if modelsFolder and cardName and cardName ~= "" then
        local model = modelsFolder:FindFirstChild(cardName)
        if not model then
            return "Spell"
        end
    end

    return "Unit"
end

local function getCardEnergyCost(cardName)
    local cardData = getCardData(cardName)
    if cardData and typeof(cardData.EnergyCost) == "number" then
        return cardData.EnergyCost
    end

    return 4
end

local function captureUICardInfo(cardName, cardInstance)
    if typeof(cardName) ~= "string" or cardName == "" then
        return
    end

    local energyCost = nil
    if cardInstance and cardInstance.FindFirstChild then
        local energyFrame = cardInstance:FindFirstChild("Energy")
        local costLabel = energyFrame and energyFrame:FindFirstChild("Cost")
        energyCost = costLabel and parseFirstNumber(costLabel.Text)
    end

    local existing = uiCardInfoCache[cardName] or {}
    existing.EnergyCost = energyCost or existing.EnergyCost or 4
    existing.CardType = existing.CardType or inferCardType(cardName)
    uiCardInfoCache[cardName] = existing
end

local function getCurrentEnergy()
    if EnergyShared and EnergyShared.GetCurrent then
        local ok, value = pcall(function()
            return EnergyShared.GetCurrent()
        end)
        if ok and typeof(value) == "number" then
            return value
        end
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gameGui = playerGui and playerGui:FindFirstChild("Game")
    local container = gameGui and gameGui:FindFirstChild("Container")
    local main = container and container:FindFirstChild("Main")
    local deckFrame = main and main:FindFirstChild("Deck")
    local inner = deckFrame and deckFrame:FindFirstChild("Inner")
    local energyFrame = inner and inner:FindFirstChild("Energy")
    local costLabel = energyFrame and energyFrame:FindFirstChild("Cost")
    local uiEnergy = costLabel and parseFirstNumber(costLabel.Text)
    if typeof(uiEnergy) == "number" then
        return uiEnergy
    end

    local attrEnergy = parseFirstNumber(LocalPlayer:GetAttribute("Energy"))
    if typeof(attrEnergy) == "number" then
        return attrEnergy
    end

    return nil
end

local function getOppositeSide(side)
    if side == "SideA" then
        return "SideB"
    end
    if side == "SideB" then
        return "SideA"
    end
    return nil
end

local function getInstancePosition(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        if instance.PrimaryPart then
            return instance.PrimaryPart.Position
        end

        local ok, pivot = pcall(function()
            return instance:GetPivot()
        end)

        if ok then
            return pivot.Position
        end
    end

    return nil
end

local function isAlive(instance)
    local health = instance:GetAttribute("Health")
    return health == nil or health > 0
end

local function addEnemyUnitIfValid(unitList, unitModel, mySide)
    if not unitModel:IsA("Model") then
        return
    end

    if not isAlive(unitModel) then
        return
    end

    local ownerUserId = unitModel:GetAttribute("OwnerUserId")
    if ownerUserId ~= nil then
        if ownerUserId ~= LocalPlayer.UserId then
            table.insert(unitList, unitModel)
        end
        return
    end

    local side = unitModel:GetAttribute("Side")
    if side and mySide and side ~= mySide then
        table.insert(unitList, unitModel)
        return
    end

    if unitModel:GetAttribute("UnitName") then
        table.insert(unitList, unitModel)
    end
end

local function updateToggleUI()
    if not uiRefs.root then
        return
    end

    local enabled = isAutoPlacing
    local stateText = enabled and "AUTO PLACE ON" or "AUTO PLACE OFF"
    local stateColor = enabled and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(248, 113, 113)
    local dotColor = enabled and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
    local trackColor = enabled and Color3.fromRGB(30, 136, 104) or Color3.fromRGB(71, 85, 105)
    local knobPosition = enabled and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 18, 0.5, 0)

    if uiRefs.stateLabel then
        uiRefs.stateLabel.Text = stateText
        TweenService:Create(uiRefs.stateLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextColor3 = stateColor
        }):Play()
    end

    if uiRefs.stateDot then
        TweenService:Create(uiRefs.stateDot, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = dotColor
        }):Play()
    end

    if uiRefs.toggleTrack then
        TweenService:Create(uiRefs.toggleTrack, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = trackColor
        }):Play()
    end

    if uiRefs.toggleKnob then
        TweenService:Create(uiRefs.toggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = knobPosition
        }):Play()
    end
end

local function createAutoPlaceUI()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("SmartAutoPlaceUI")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SmartAutoPlaceUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local panelShadow = Instance.new("Frame")
    panelShadow.Name = "Shadow"
    panelShadow.Size = UDim2.fromOffset(252, 124)
    panelShadow.Position = UDim2.new(1, -264, 0, 88)
    panelShadow.BackgroundColor3 = Color3.fromRGB(3, 7, 18)
    panelShadow.BackgroundTransparency = 0.45
    panelShadow.BorderSizePixel = 0
    panelShadow.Parent = screenGui

    local panelShadowCorner = Instance.new("UICorner")
    panelShadowCorner.CornerRadius = UDim.new(0, 18)
    panelShadowCorner.Parent = panelShadow

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromOffset(244, 116)
    panel.Position = UDim2.new(1, -260, 0, 84)
    panel.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    panel.BorderSizePixel = 0
    panel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 16)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(71, 85, 105)
    panelStroke.Thickness = 1.2
    panelStroke.Transparency = 0.2
    panelStroke.Parent = panel

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 41, 59)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 23, 42))
    })
    panelGradient.Rotation = 140
    panelGradient.Parent = panel

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.fromOffset(12, 8)
    title.Font = Enum.Font.GothamBold
    title.Text = "SMART AUTO PLACE"
    title.TextColor3 = Color3.fromRGB(226, 232, 240)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, -20, 0, 18)
    subtitle.Position = UDim2.fromOffset(12, 30)
    subtitle.Font = Enum.Font.Gotham
    subtitle.Text = "One tap battle assistant"
    subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = panel

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, -100, 0, 16)
    statusLabel.Position = UDim2.fromOffset(12, 90)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Status: Ready"
    statusLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusLabel.Parent = panel

    local stateDot = Instance.new("Frame")
    stateDot.Name = "StateDot"
    stateDot.Size = UDim2.fromOffset(9, 9)
    stateDot.Position = UDim2.fromOffset(14, 64)
    stateDot.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    stateDot.BorderSizePixel = 0
    stateDot.Parent = panel

    local stateDotCorner = Instance.new("UICorner")
    stateDotCorner.CornerRadius = UDim.new(1, 0)
    stateDotCorner.Parent = stateDot

    local stateLabel = Instance.new("TextLabel")
    stateLabel.Name = "State"
    stateLabel.BackgroundTransparency = 1
    stateLabel.Size = UDim2.new(1, -115, 0, 22)
    stateLabel.Position = UDim2.fromOffset(28, 58)
    stateLabel.Font = Enum.Font.GothamSemibold
    stateLabel.Text = "AUTO PLACE OFF"
    stateLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
    stateLabel.TextSize = 13
    stateLabel.TextXAlignment = Enum.TextXAlignment.Left
    stateLabel.Parent = panel

    local toggleTrack = Instance.new("TextButton")
    toggleTrack.Name = "Toggle"
    toggleTrack.Size = UDim2.fromOffset(72, 34)
    toggleTrack.Position = UDim2.new(1, -84, 1, -46)
    toggleTrack.BackgroundColor3 = Color3.fromRGB(71, 85, 105)
    toggleTrack.AutoButtonColor = false
    toggleTrack.Text = ""
    toggleTrack.Parent = panel

    local toggleTrackCorner = Instance.new("UICorner")
    toggleTrackCorner.CornerRadius = UDim.new(1, 0)
    toggleTrackCorner.Parent = toggleTrack

    local toggleTrackStroke = Instance.new("UIStroke")
    toggleTrackStroke.Color = Color3.fromRGB(148, 163, 184)
    toggleTrackStroke.Thickness = 1
    toggleTrackStroke.Transparency = 0.35
    toggleTrackStroke.Parent = toggleTrack

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "Knob"
    toggleKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    toggleKnob.Size = UDim2.fromOffset(26, 26)
    toggleKnob.Position = UDim2.new(0, 18, 0.5, 0)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(241, 245, 249)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleTrack

    local toggleKnobCorner = Instance.new("UICorner")
    toggleKnobCorner.CornerRadius = UDim.new(1, 0)
    toggleKnobCorner.Parent = toggleKnob

    local toggleKnobStroke = Instance.new("UIStroke")
    toggleKnobStroke.Color = Color3.fromRGB(148, 163, 184)
    toggleKnobStroke.Thickness = 1
    toggleKnobStroke.Transparency = 0.4
    toggleKnobStroke.Parent = toggleKnob

    uiRefs.root = screenGui
    uiRefs.panel = panel
    uiRefs.stateLabel = stateLabel
    uiRefs.statusLabel = statusLabel
    uiRefs.stateDot = stateDot
    uiRefs.toggleTrack = toggleTrack
    uiRefs.toggleKnob = toggleKnob

    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPanelPos = nil
    local startShadowPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPanelPos.X.Scale,
            startPanelPos.X.Offset + delta.X,
            startPanelPos.Y.Scale,
            startPanelPos.Y.Offset + delta.Y
        )
        panelShadow.Position = UDim2.new(
            startShadowPos.X.Scale,
            startShadowPos.X.Offset + delta.X,
            startShadowPos.Y.Scale,
            startShadowPos.Y.Offset + delta.Y
        )
    end

    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPanelPos = panel.Position
            startShadowPos = panelShadow.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    panel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPanelPos and startShadowPos then
            updateDrag(input)
        end
    end)

    toggleTrack.Activated:Connect(function()
        ToggleAutoPlace()
    end)

    updateToggleUI()
    if #startupWarnings > 0 then
        setRuntimeStatus("warn", startupWarnings[1], true)
    else
        setRuntimeStatus("info", "Loaded. Toggle ON to start.", true)
    end
end

local function collectEnemyUnits(mySide)
    local enemyUnits = {}
    local registry = Workspace:FindFirstChild("NpcRegistryCamera")

    if registry then
        for _, child in ipairs(registry:GetChildren()) do
            if child:IsA("Folder") then
                for _, model in ipairs(child:GetChildren()) do
                    addEnemyUnitIfValid(enemyUnits, model, mySide)
                end
            else
                addEnemyUnitIfValid(enemyUnits, child, mySide)
            end
        end

        return enemyUnits
    end

    local now = os.clock()
    if now - lastFallbackUnitScanAt >= UNIT_FALLBACK_SCAN_INTERVAL then
        lastFallbackUnitScanAt = now
        table.clear(cachedFallbackEnemyUnits)

        for _, instance in ipairs(Workspace:GetDescendants()) do
            if instance:IsA("Model") and instance:GetAttribute("UnitName") then
                addEnemyUnitIfValid(cachedFallbackEnemyUnits, instance, mySide)
            end
        end
    end

    for _, model in ipairs(cachedFallbackEnemyUnits) do
        table.insert(enemyUnits, model)
    end

    return enemyUnits
end

local function getFriendlyDirectionSign(myTowers, enemyTowers, mySide)
    local defaultSign = (mySide == "SideB") and -1 or 1

    if #myTowers == 0 or #enemyTowers == 0 then
        return defaultSign
    end

    local mySum = 0
    local myCount = 0
    for _, tower in ipairs(myTowers) do
        local pos = getInstancePosition(tower)
        if pos then
            mySum += pos.Z
            myCount += 1
        end
    end

    local enemySum = 0
    local enemyCount = 0
    for _, tower in ipairs(enemyTowers) do
        local pos = getInstancePosition(tower)
        if pos then
            enemySum += pos.Z
            enemyCount += 1
        end
    end

    if myCount == 0 or enemyCount == 0 then
        return defaultSign
    end

    return (mySum / myCount >= enemySum / enemyCount) and 1 or -1
end

local function scanBattlefield()
    local now = os.clock()
    if cachedScan and now - lastScanAt < SCAN_INTERVAL then
        return cachedScan.mySide, cachedScan.friendlySign, cachedScan.enemyTowers, cachedScan.enemyUnits
    end

    local mySide = getMySide()
    if not mySide then
        cachedScan = nil
        return nil, nil, nil, nil
    end

    local oppositeSide = getOppositeSide(mySide)
    local myTowers = {}
    local enemyTowers = {}

    for _, tower in ipairs(CollectionService:GetTagged("Tower")) do
        local isMine = false
        local side = tower:GetAttribute("Side")

        if side then
            isMine = side == mySide
        else
            if tower:HasTag(mySide) then
                isMine = true
            elseif oppositeSide and tower:HasTag(oppositeSide) then
                isMine = false
            end
        end

        if isMine then
            table.insert(myTowers, tower)
        else
            table.insert(enemyTowers, tower)
        end
    end

    local enemyUnits = collectEnemyUnits(mySide)
    local friendlySign = getFriendlyDirectionSign(myTowers, enemyTowers, mySide)

    cachedScan = {
        mySide = mySide,
        friendlySign = friendlySign,
        enemyTowers = enemyTowers,
        enemyUnits = enemyUnits
    }
    lastScanAt = now

    return mySide, friendlySign, enemyTowers, enemyUnits
end

local function readDeckFromUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    local gameGui = playerGui:FindFirstChild("Game")
    local container = gameGui and gameGui:FindFirstChild("Container")
    local main = container and container:FindFirstChild("Main")
    local deckFrame = main and main:FindFirstChild("Deck")
    local inner = deckFrame and deckFrame:FindFirstChild("Inner")
    local cardsHolder = inner and inner:FindFirstChild("Cards")

    if not cardsHolder then
        return nil
    end

    local detected = {}
    local seen = {}

    for _, slot in ipairs(cardsHolder:GetChildren()) do
        if slot:IsA("Frame") then
            for _, child in ipairs(slot:GetChildren()) do
                local isKnownCard = CardInfo[child.Name] ~= nil
                local looksLikeCardFrame = child:IsA("Frame") and child:FindFirstChild("Energy") ~= nil

                if (isKnownCard or looksLikeCardFrame) and not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(detected, child.Name)
                    captureUICardInfo(child.Name, child)
                end
            end
        end
    end

    if #detected == 0 then
        return nil
    end

    return detected
end

local function getCurrentDeck()
    local now = os.clock()
    if now - lastDeckRefreshAt < DECK_REFRESH_INTERVAL then
        return cachedDeck
    end

    lastDeckRefreshAt = now
    local detected = readDeckFromUI()
    if detected then
        cachedDeck = detected
    end

    return cachedDeck
end

local function getPlaceType(cardName)
    local cardData = getCardData(cardName)
    local cardType = cardData and cardData.CardType

    if not cardType or cardType == "" then
        cardType = inferCardType(cardName)
    end

    if cardType == "Building" or cardType == "Tower" then
        return "Building"
    end
    if cardType == "Spell" then
        return "Spell"
    end

    return "Unit"
end

local function getPlacementCFrame(tilePosition, placeType, mySide)
    local base = tilePosition
    if typeof(base) ~= "Vector3" then
        base = Vector3.new(0, 0, 0)
    end

    local sideRotation = (mySide == "SideB") and CFrame.Angles(0, math.pi, 0) or CFrame.new()
    local rotation = placeType == "Building" and sideRotation or sideRotation
    return CFrame.new(base + Vector3.new(0, 2, 0)) * rotation
end

local function getStrategicPlacementPosition(enemyTowers, enemyUnits, friendlySign, cardToPlay, mySide)
    local cardData = getCardData(cardToPlay)
    local resolvedCardType = (cardData and cardData.CardType) or inferCardType(cardToPlay)
    local isBuilding = resolvedCardType == "Building"
    local isSpell = resolvedCardType == "Spell"

    if isBuilding then
        local buildingPos = Vector3.new(0, 0, 15 * friendlySign)
        if TileHandler and mySide and TileHandler.GetClosestValidTile then
            local buildingTile = TileHandler:GetClosestValidTile(mySide, buildingPos)
            if buildingTile and buildingTile.Position then
                return buildingTile.Position
            end
        end

        return buildingPos
    end

    local friendlyZMin = 5
    local friendlyZMax = 35

    local leftTowerAlive = false
    local rightTowerAlive = false
    for _, tower in ipairs(enemyTowers) do
        if isAlive(tower) then
            local pos = getInstancePosition(tower)
            if pos then
                if pos.X < 0 then
                    leftTowerAlive = true
                else
                    rightTowerAlive = true
                end
            end
        end
    end

    local pushingEnemy = nil
    local minEnemyRelativeZ = math.huge
    for _, unit in ipairs(enemyUnits) do
        local pos = getInstancePosition(unit)
        if pos then
            local relativeZ = pos.Z * friendlySign
            if relativeZ > 0 and relativeZ < friendlyZMax and relativeZ < minEnemyRelativeZ then
                minEnemyRelativeZ = relativeZ
                pushingEnemy = pos
            end
        end
    end

    local targetPos
    if pushingEnemy then
        targetPos = Vector3.new(pushingEnemy.X, 2, (minEnemyRelativeZ + 5) * friendlySign)
    else
        local laneX
        local targetRelativeZ = friendlyZMin

        if not leftTowerAlive and rightTowerAlive then
            laneX = -15
            targetRelativeZ = -15
        elseif not rightTowerAlive and leftTowerAlive then
            laneX = 15
            targetRelativeZ = -15
        else
            laneX = (math.random() > 0.5) and 15 or -15
            if not leftTowerAlive and not rightTowerAlive then
                targetRelativeZ = -15
            end
        end

        laneX += math.random(-3, 3)
        targetRelativeZ += math.random(-2, 5)
        targetPos = Vector3.new(laneX, 2, targetRelativeZ * friendlySign)
    end

    if TileHandler then
        local closestTile = nil

        if isSpell and TileHandler.GetClosestTile then
            closestTile = TileHandler:GetClosestTile(targetPos)
        elseif mySide and TileHandler.GetClosestValidTile then
            closestTile = TileHandler:GetClosestValidTile(mySide, targetPos)
        end

        if closestTile and closestTile.Position then
            targetPos = Vector3.new(closestTile.Position.X, closestTile.Position.Y, closestTile.Position.Z)
        end
    end

    return targetPos
end

local function getBestCardToPlay(currentEnergy, needDefense, deckCards)
    local bestCard = nil
    local selectedCost = needDefense and math.huge or -1

    for _, cardName in ipairs(deckCards) do
        local cardCost = getCardEnergyCost(cardName)
        if cardCost <= currentEnergy then
            if needDefense then
                if cardCost < selectedCost then
                    selectedCost = cardCost
                    bestCard = cardName
                end
            elseif cardCost > selectedCost then
                selectedCost = cardCost
                bestCard = cardName
            end
        end
    end

    if not bestCard then
        return nil, nil
    end

    return bestCard, selectedCost
end

local function processAutoPlaceTick()
    local currentEnergy = getCurrentEnergy()
    if typeof(currentEnergy) ~= "number" then
        setRuntimeStatus("warn", "Energy unavailable - waiting")
        return 0.3
    end

    local mySide, friendlySign, enemyTowers, enemyUnits = scanBattlefield()
    if not mySide then
        setRuntimeStatus("warn", "Waiting for side assignment")
        return 0.3
    end

    local underAttack = false
    for _, unit in ipairs(enemyUnits) do
        local pos = getInstancePosition(unit)
        if pos and pos.Z * friendlySign > 0 then
            underAttack = true
            break
        end
    end

    local now = os.clock()
    checkPendingPlacement(now, currentEnergy, mySide)

    if now - lastHeartbeatStatusAt >= 2 then
        lastHeartbeatStatusAt = now
        setRuntimeStatus("ok", string.format("Running | Energy %.1f", currentEnergy))
    end

    local energyThreshold = underAttack and 2 or 9
    local canPlaceByCooldown = (now - lastPlaceAt) >= PLACE_COOLDOWN and pendingPlacement == nil
    if currentEnergy >= energyThreshold and canPlaceByCooldown then
        local currentDeck = getCurrentDeck()
        local cardToPlay = getBestCardToPlay(currentEnergy, underAttack, currentDeck)

        if cardToPlay then
            local placeType = getPlaceType(cardToPlay)
            local placementPosition = getStrategicPlacementPosition(enemyTowers, enemyUnits, friendlySign, cardToPlay, mySide)
            local placementCFrame = getPlacementCFrame(placementPosition, placeType, mySide)
            local ok, placeErr = pcall(function()
                PlaceRemote:FireServer(placeType, cardToPlay, placementCFrame)
            end)

            if ok then
                lastPlaceAt = now
                pendingPlacement = {
                    cardName = cardToPlay,
                    placeType = placeType,
                    sentAt = now,
                    expectedCost = getCardEnergyCost(cardToPlay),
                    energyBefore = currentEnergy,
                    spawnCountBefore = countOwnedSpawns(cardToPlay, placeType, mySide)
                }
                setRuntimeStatus("info", string.format("Sent %s (%s)", cardToPlay, placeType), true)
            else
                setRuntimeStatus("error", "Place remote call failed", true)
                warn("[AutoPlace] PlaceRemote error: " .. tostring(placeErr))
                return 0.5
            end
        end
    end

    return underAttack and 0.15 or 0.3
end

local function autoPlaceLoop()
    setRuntimeStatus("ok", "AutoPlace active", true)
    while isAutoPlacing do
        local ok, result = xpcall(processAutoPlaceTick, debug.traceback)
        if not ok then
            setRuntimeStatus("error", "Runtime error - check console", true)
            warn("[AutoPlace] Loop error:\n" .. tostring(result))
            task.wait(0.5)
        else
            task.wait(result)
        end
    end

    setRuntimeStatus("info", "AutoPlace paused", true)
end

function SetAutoPlaceDeck(deckList)
    if typeof(deckList) ~= "table" then
        warn("[AutoPlace] SetAutoPlaceDeck expects a table of card names")
        setRuntimeStatus("warn", "Invalid deck input")
        return false
    end

    local sanitized = {}
    for _, cardName in ipairs(deckList) do
        if typeof(cardName) == "string" and cardName ~= "" then
            table.insert(sanitized, cardName)
            captureUICardInfo(cardName)
        end
    end

    if #sanitized == 0 then
        warn("[AutoPlace] No valid cards found in custom deck")
        setRuntimeStatus("warn", "No valid cards in deck")
        return false
    end

    fallbackDeck = sanitized
    cachedDeck = table.clone(sanitized)
    print("[AutoPlace] Fallback deck updated: " .. table.concat(sanitized, ", "))
    setRuntimeStatus("ok", "Fallback deck updated", true)
    return true
end

function GetAutoPlaceDeck()
    return table.clone(getCurrentDeck())
end

function ToggleAutoPlace()
    isAutoPlacing = not isAutoPlacing
    if isAutoPlacing then
        print("Smart Auto-Place Enabled!")
        setRuntimeStatus("ok", "Enabled", true)
        task.spawn(autoPlaceLoop)
    else
        print("Smart Auto-Place Disabled!")
        setRuntimeStatus("info", "Disabled", true)
    end

    updateToggleUI()
end

createAutoPlaceUI()
