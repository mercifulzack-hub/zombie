local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer    = Players.LocalPlayer

-- ─── Filesystem stubs ─────────────────────────────────────────────────────────
if not isfolder  then isfolder  = function() return false end end
if not makefolder then makefolder = function() end end
if not isfile    then isfile    = function() return false end end
if not readfile  then readfile  = function() return "" end end
if not writefile then writefile = function() end end
if not delfile   then delfile   = function() end end

-- ─── Load Rayfield ────────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua",
    true
))()

-- ─── Remote Setup ─────────────────────────────────────────────────────────────
local RE  = ReplicatedStorage:WaitForChild("_RemoteEvents")
local RF  = ReplicatedStorage:WaitForChild("_RemoteFunctions")

local RequestCardSpin       = RE:WaitForChild("RequestCardSpin")
local SetAutoRollState      = RE:WaitForChild("SetAutoRollState")
local UpdateSettings        = RE:WaitForChild("UpdateSettings")
local CardSpinResult        = RE:WaitForChild("CardSpinResult")
local BattleEnd             = RE:WaitForChild("BattleEnd")
local BattleVersus          = RE:WaitForChild("BattleVersus")
local DebugStartBattle      = RE:WaitForChild("DebugStartBattle")
local ClaimQuestReward      = RE:WaitForChild("ClaimQuestReward")
local ClaimAllQuestsReward  = RE:WaitForChild("ClaimAllQuestsReward")
local RequestEquipCard      = RE:WaitForChild("RequestEquipCard")
local RequestUnequipCard    = RE:WaitForChild("RequestUnequipCard")
local InventoryUpdated      = RE:WaitForChild("InventoryUpdated")
local RequestEquipRelic     = RE:WaitForChild("RequestEquipRelic")
local RequestEquipTalisman  = RE:WaitForChild("RequestEquipTalisman")
local UseItemSecure         = RE:WaitForChild("UseItemSecure")
local RaidPartyCreate       = RE:FindFirstChild("RaidPartyCreate") or RE:WaitForChild("RaidPartyCreate", 5)
local RaidPartyReady        = RE:FindFirstChild("RaidPartyReady") or RE:WaitForChild("RaidPartyReady", 5)
local RaidPartyUpdate       = RE:FindFirstChild("RaidPartyUpdate") or RE:WaitForChild("RaidPartyUpdate", 5)
local RaidPartyStarted      = RE:FindFirstChild("RaidPartyStarted") or RE:WaitForChild("RaidPartyStarted", 5)

local RequestPlayerCards    = RF:WaitForChild("RequestPlayerCards")
local RequestPartyData      = RF:WaitForChild("RequestPartyData")
local RequestBossBattle     = RF:FindFirstChild("RequestBossBattle") or RF:WaitForChild("RequestBossBattle", 5)
local GetPlayerSettings     = RF:FindFirstChild("GetPlayerSettings") or RF:WaitForChild("GetPlayerSettings", 5)
local TeleportEvent         = ReplicatedStorage:FindFirstChild("TeleportEvent")

-- ─── Card Data (inlined from CardData.lua) ────────────────────────────────────
-- Maps cardId -> {Damage=n, HP=n, RarityNumber=n, Name=string}
local CARD_DATA = {
    slime               = {Name="Skeleton",            Damage=6,    HP=12,    RarityNumber=1},
    zumbi               = {Name="Zombie",              Damage=7,    HP=14,    RarityNumber=2},
    bandido             = {Name="Bandit",              Damage=8,    HP=16,    RarityNumber=3},
    hollow              = {Name="Hollow",              Damage=9,    HP=18,    RarityNumber=5},
    nailmaster          = {Name="Nail Master",         Damage=11,   HP=22,    RarityNumber=10},
    wild_prodigy        = {Name="Wild Prodigy",        Damage=15,   HP=30,    RarityNumber=25},
    stone_scientist     = {Name="Stone Scientist",     Damage=20,   HP=40,    RarityNumber=50},
    shadow_summoner     = {Name="Shadow Summoner",     Damage=26,   HP=52,    RarityNumber=75},
    frost_witch         = {Name="Frost Witch",         Damage=37,   HP=75,    RarityNumber=100},
    explosive_artist    = {Name="Explosive Artist",    Damage=43,   HP=86,    RarityNumber=125},
    thorfinn            = {Name="Vengeful Viking",     Damage=46,   HP=92,    RarityNumber=150},
    copy_ninja          = {Name="Copy Ninja",          Damage=65,   HP=130,   RarityNumber=350},
    rift_demon          = {Name="Rift Demon",          Damage=50,   HP=101,   RarityNumber=200},
    rimuru_sage         = {Name="Great Sage",          Damage=56,   HP=113,   RarityNumber=250},
    illusory_monarch    = {Name="Illusory Monarch",    Damage=94,   HP=188,   RarityNumber=750},
    luffy               = {Name="Straw Hat",           Damage=70,   HP=140,   RarityNumber=400},
    naruto              = {Name="Nine-Tails Jinchuriki",Damage=80,  HP=160,   RarityNumber=500},
    final_commander     = {Name="Final Commander",     Damage=80,   HP=160,   RarityNumber=500},
    goku                = {Name="Saiyan Warrior",      Damage=100,  HP=200,   RarityNumber=900},
    king_of_heroes      = {Name="King of Heroes",      Damage=125,  HP=251,   RarityNumber=1500},
    tanjiro             = {Name="Demon Slayer",        Damage=135,  HP=270,   RarityNumber=1500},
    hollowed_champion   = {Name="Hollowed Champion",   Damage=135,  HP=270,   RarityNumber=2000},
    natsu               = {Name="Fire Dragon Slayer",  Damage=175,  HP=350,   RarityNumber=2500},
    killua              = {Name="Lightning Assassin",  Damage=190,  HP=380,   RarityNumber=3000},
    boulder_guy         = {Name="Boulder Guy",         Damage=205,  HP=410,   RarityNumber=3500},
    arthur_leywin       = {Name="Ascendant King",      Damage=140,  HP=280,   RarityNumber=1800},
    shadow_weaver       = {Name="Shadow Weaver",       Damage=210,  HP=420,   RarityNumber=5000},
    gojo                = {Name="The Honored One",     Damage=190,  HP=380,   RarityNumber=4500},
    sukuna              = {Name="King of Curses",      Damage=220,  HP=440,   RarityNumber=6000},
    swift_ackerman      = {Name="Swift Ackerman",      Damage=235,  HP=470,   RarityNumber=5500},
    sleepy_swordsman    = {Name="Sleepy Swordsman",    Damage=250,  HP=500,   RarityNumber=6500},
    egotistic_saiyan    = {Name="Egotistic Saiyan",    Damage=265,  HP=530,   RarityNumber=7000},
    genius_detective    = {Name="Genius Detective",    Damage=330,  HP=660,   RarityNumber=9000},
    tokito              = {Name="Mist Hashira",        Damage=350,  HP=700,   RarityNumber=10000},
    denji               = {Name="Chainsaw Man",        Damage=430,  HP=860,   RarityNumber=15000},
    saitama             = {Name="Caped Baldy",         Damage=500,  HP=1000,  RarityNumber=20000},
    sakura              = {Name="Kunoichi Healer",     Damage=550,  HP=1100,  RarityNumber=25000},
    guido_mista         = {Name="Sixfold Gunner",      Damage=560,  HP=1120,  RarityNumber=30000},
    isagi_ego_striker   = {Name="Ego Striker",         Damage=610,  HP=1220,  RarityNumber=35000},
    thorkell_ruthless   = {Name="Ruthless Fighter",    Damage=700,  HP=1400,  RarityNumber=40000},
    ace_flame_fist      = {Name="Flame Fist",          Damage=980,  HP=1960,  RarityNumber=60000},
    inoue_orihime       = {Name="Radiant Protector",   Damage=1100, HP=2200,  RarityNumber=70000},
    sinbad_king_conquest= {Name="King of Conquest",    Damage=1500, HP=3000,  RarityNumber=100000},
    hidan_jashin_vessel = {Name="Jashin's Vessel",     Damage=830,  HP=1660,  RarityNumber=50000},
    hakari_dice_king    = {Name="Dice King",           Damage=1650, HP=3300,  RarityNumber=125000},
    chiikawa_ravaging_beast={Name="Ravaging Beast",    Damage=1850, HP=3700,  RarityNumber=175000},
    beast_titan_primal  = {Name="Primal Commander",    Damage=2000, HP=4000,  RarityNumber=200000},
    eren_freedom_shifter= {Name="Freedom Shifter",     Damage=2200, HP=4400,  RarityNumber=250000},
    escanor_prideful_sin= {Name="Prideful Sin",        Damage=2350, HP=4700,  RarityNumber=300000},
    jojo_kira           = {Name="Silent Killer",       Damage=2050, HP=4100,  RarityNumber=320000},
    jojo_valentine      = {Name="Dimensional President",Damage=2250,HP=4500,  RarityNumber=410000},
    jojo_weather_report = {Name="Storm Caller",        Damage=2450, HP=4900,  RarityNumber=520000},
    jojo_diavolo        = {Name="Crimson Fate",        Damage=2650, HP=5300,  RarityNumber=680000},
    jojo_tooru          = {Name="Calamity Incarnate",  Damage=2900, HP=5800,  RarityNumber=900000},
    adam_humanity_hope  = {Name="Humanity's Hope",     Damage=3050, HP=6100,  RarityNumber=1150000},
    alladin_magic_prodigy={Name="Magic Prodigy",       Damage=3400, HP=6800,  RarityNumber=750000},
    megumin_crimson_mage= {Name="Crimson Mage",        Damage=2750, HP=5500,  RarityNumber=500000},
    saber_sword_empress = {Name="Sword Empress",       Damage=2050, HP=4100,  RarityNumber=250000},
}

local BORDER_MULT = {Normal = 1, Gold = 4, Rainbow = 16, Mythical = 64}
do
    local okCard, cardModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("_Modules"):WaitForChild("CardData"))
    end)
    if okCard and type(cardModule) == "table" and type(cardModule.Cards) == "table" then
        CARD_DATA = cardModule.Cards
    end

    local okBorder, borderModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("_Modules"):WaitForChild("BorderData"))
    end)
    if okBorder and type(borderModule) == "table" and type(borderModule.Borders) == "table" then
        for border, info in pairs(borderModule.Borders) do
            BORDER_MULT[border] = tonumber(info.Multiplier) or BORDER_MULT[border] or 1
        end
    end
end

-- ─── State ────────────────────────────────────────────────────────────────────
local Cfg = {
    AutoRoll        = false,
    FastRoll        = false,
    AutoBattle      = false,
    SmartBattle     = true,
    SmartSafety     = 0.85,
    AutoBoss        = false,
    BossId          = "panther_espada",
    AutoRaid        = false,
    RaidBossId      = "Divine General",
    RaidDifficulty  = "Easy",
    TeleportFallback = true,
    TeleportBeforeBattle = true,
    BossStartDistance = 35,
    AutoWorldBosses = false,
    AutoClaimQuests = false,
    AutoEquipBest   = false,
    EquipMode       = "ATK",      -- "ATK", "HP", "BALANCED"
    BattleCardId    = "slime",    -- enemy card ID for auto battle
    BattleEnemyCount = 1,
}

local State = {
    InBattle        = false,
    InRaidParty     = false,
    OwnedCards      = {},         -- {cardId = {Total=n, Borders={Normal=n}, BestBorder=string}}
    LastBattleTime  = 0,
    LastBossTime    = 0,
    LastRaidTime    = 0,
    ActiveBossId    = nil,
    ActiveWorldStage = nil,
    LastBossResult  = nil,
    LastBossDefeated = nil,
    LastWorldStageResult = nil,
    WorldBossIndex  = 1,
    WorldEnemyCleared = {},
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local _logThrottle = {}
local function logEvery(key, msg, interval)
    local now = tick()
    if not _logThrottle[key] or now - _logThrottle[key] >= interval then
        _logThrottle[key] = now
        print("[AnimeCardAuto] " .. msg)
    end
end

local function syncOwnedCards()
    local ok, data = pcall(function() return RequestPlayerCards:InvokeServer() end)
    if ok and type(data) == "table" then
        State.OwnedCards = {}
        for _, entry in ipairs(data) do
            if type(entry) == "table" and entry.CardId then
                State.OwnedCards[entry.CardId] = true
            elseif type(entry) == "string" then
                State.OwnedCards[entry] = true
            end
        end
        return true
    end
    return false
end

-- ─── Best Deck Builder ────────────────────────────────────────────────────────
-- Picks top 4 owned cards by mode: ATK = highest Damage, HP = highest HP, BALANCED = highest Damage+HP
local function getBestDeck(mode)
    local owned = {}
    for id, data in pairs(CARD_DATA) do
        if State.OwnedCards[id] then
            table.insert(owned, {id = id, data = data})
        end
    end
    table.sort(owned, function(a, b)
        if mode == "ATK" then
            return a.data.Damage > b.data.Damage
        elseif mode == "HP" then
            return a.data.HP > b.data.HP
        else -- BALANCED
            return (a.data.Damage + a.data.HP) > (b.data.Damage + b.data.HP)
        end
    end)
    local deck = {}
    for i = 1, math.min(4, #owned) do
        table.insert(deck, owned[i].id)
    end
    return deck
end

local function equipBestDeck()
    syncOwnedCards()
    local deck = getBestDeck(Cfg.EquipMode)
    if #deck == 0 then
        print("[AnimeCardAuto] Auto Equip Best: no owned cards found in CardData yet")
        return
    end
    local ok2, party = pcall(function() return RequestPartyData:InvokeServer() end)
    local currentSlots = {}
    if ok2 and type(party) == "table" then
        for slot, id in pairs(party) do
            currentSlots[slot] = id
        end
    end
    for slot = 1, 4 do
        local current = currentSlots[slot]
        local desired = deck[slot]
        if desired and current ~= desired then
            if current then
                pcall(function() RequestUnequipCard:FireServer(slot) end)
                task.wait(0.2)
            end
            pcall(function() RequestEquipCard:FireServer(desired, slot) end)
            task.wait(0.2)
            print(string.format("[AnimeCardAuto] Equipped slot %d: %s (%s mode)", slot, CARD_DATA[desired] and CARD_DATA[desired].Name or desired, Cfg.EquipMode))
        end
    end
end

-- Runtime-aware collection/deck helpers. These shadow the first draft above and
-- match the server response shape: "cardId:Border" -> {Amount = n}.
local function splitCardKey(key)
    local cardId, border = tostring(key):match("^([^:]+):(.+)$")
    if cardId then
        return string.lower(cardId), tostring(border)
    end
    return string.lower(tostring(key)), "Normal"
end

local function addOwnedCard(cardId, border, amount)
    cardId = string.lower(tostring(cardId or ""))
    if cardId == "" then return end
    border = tostring(border or "Normal")
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local entry = State.OwnedCards[cardId] or {Total = 0, Borders = {}, BestBorder = "Normal"}
    entry.Total = entry.Total + amount
    entry.Borders[border] = (entry.Borders[border] or 0) + amount
    if (BORDER_MULT[border] or 1) > (BORDER_MULT[entry.BestBorder] or 1) then
        entry.BestBorder = border
    end
    State.OwnedCards[cardId] = entry
end

local function syncOwnedCards()
    local ok, data = pcall(function() return RequestPlayerCards:InvokeServer() end)
    if ok and type(data) == "table" then
        State.OwnedCards = {}
        for key, entry in pairs(data) do
            if type(key) == "string" then
                local cardId, border = splitCardKey(key)
                local amount = type(entry) == "table" and entry.Amount or entry
                addOwnedCard(cardId, border, amount)
            elseif type(entry) == "table" and entry.CardId then
                addOwnedCard(entry.CardId, entry.Border or "Normal", entry.Amount or 1)
            elseif type(entry) == "string" then
                addOwnedCard(entry, "Normal", 1)
            end
        end
        return true
    end
    return false
end

local function cardScore(cardId, mode, border)
    local data = CARD_DATA[string.lower(tostring(cardId or ""))]
    if not data then return 0 end
    local mult = BORDER_MULT[border or "Normal"] or 1
    local dmg = tonumber(data.Damage) or 0
    local hp = tonumber(data.HP) or 0
    if dmg <= 0 and hp <= 0 then
        local rarity = tonumber(data.RarityNumber) or 0
        dmg = rarity / 1000
        hp = rarity / 500
    end
    if mode == "ATK" then
        return dmg * mult
    elseif mode == "HP" then
        return hp * mult
    end
    return (dmg + hp) * mult
end

local function getPartySlots()
    local ok, party = pcall(function() return RequestPartyData:InvokeServer() end)
    local slots = {}
    if ok and type(party) == "table" then
        for i, entry in pairs(party) do
            if type(entry) == "table" then
                local slot = math.floor(tonumber(entry.SlotIndex) or tonumber(i) or 0)
                if slot >= 1 and slot <= 4 then
                    slots[slot] = {
                        id = string.lower(tostring(entry.CardId or "")),
                        border = tostring(entry.Border or "Normal")
                    }
                end
            elseif type(entry) == "string" then
                local slot = math.floor(tonumber(i) or 0)
                if slot >= 1 and slot <= 4 then
                    slots[slot] = {id = string.lower(entry), border = "Normal"}
                end
            end
        end
    end
    return slots
end

local function getBestDeck(mode)
    local owned = {}
    for id, ownedEntry in pairs(State.OwnedCards) do
        if CARD_DATA[id] and ownedEntry.Total and ownedEntry.Total > 0 then
            local border = ownedEntry.BestBorder or "Normal"
            table.insert(owned, {
                id = id,
                border = border,
                score = cardScore(id, mode, border)
            })
        end
    end
    table.sort(owned, function(a, b) return a.score > b.score end)
    local deck = {}
    for i = 1, math.min(4, #owned) do
        table.insert(deck, owned[i])
    end
    return deck
end

local function getPartyPower()
    local total = 0
    for _, entry in pairs(getPartySlots()) do
        total = total + cardScore(entry.id, "BALANCED", entry.border)
    end
    if total > 0 then return total end
    syncOwnedCards()
    for _, entry in ipairs(getBestDeck("BALANCED")) do
        total = total + entry.score
    end
    return total
end

local function equipBestDeck()
    syncOwnedCards()
    local deck = getBestDeck(Cfg.EquipMode)
    if #deck == 0 then
        print("[AnimeCardAuto] Auto Equip Best: no owned cards found in CardData yet")
        return
    end
    local currentSlots = getPartySlots()
    for slot = 1, 4 do
        local current = currentSlots[slot]
        local desired = deck[slot]
        if desired and (not current or current.id ~= desired.id or current.border ~= desired.border) then
            if current then
                pcall(function() RequestUnequipCard:FireServer(slot) end)
                task.wait(0.2)
            end
            pcall(function() RequestEquipCard:FireServer(desired.id, desired.border, slot) end)
            task.wait(0.2)
            local name = CARD_DATA[desired.id] and CARD_DATA[desired.id].Name or desired.id
            print(string.format("[AnimeCardAuto] Equipped slot %d: %s [%s] (%s mode)", slot, name, desired.border, Cfg.EquipMode))
        end
    end
end

-- ─── Auto Roll ────────────────────────────────────────────────────────────────
-- SetAutoRollState:FireServer(true) mirrors clicking the Auto toggle in-game
task.spawn(function()
    while task.wait(1) do
        if not Cfg.AutoRoll then continue end
        local ok, err = pcall(function()
            SetAutoRollState:FireServer(true)
        end)
        if not ok then
            logEvery("autoroll_err", "SetAutoRollState error: " .. tostring(err), 10)
        end
    end
end)

-- ─── Auto Roll OFF when toggled off ──────────────────────────────────────────
-- We track previous state to turn server-side auto-roll off cleanly
local _prevAutoRoll = false
task.spawn(function()
    while task.wait(0.5) do
        if _prevAutoRoll and not Cfg.AutoRoll then
            pcall(function() SetAutoRollState:FireServer(false) end)
        end
        _prevAutoRoll = Cfg.AutoRoll
    end
end)

-- ─── Fast Roll toggle ────────────────────────────────────────────────────────
local _prevFastRoll = false
task.spawn(function()
    while task.wait(0.5) do
        if Cfg.FastRoll ~= _prevFastRoll then
            pcall(function() UpdateSettings:FireServer("SkipRollAnimation", Cfg.FastRoll) end)
            _prevFastRoll = Cfg.FastRoll
        end
    end
end)

-- ─── Auto Battle ─────────────────────────────────────────────────────────────
-- DebugStartBattle:FireServer({cardIds}) confirmed in EnemyTeam/Frame/LocalScript.client.lua:119
-- BattleEnd.OnClientEvent fires when battle ends - we restart after checking result.
local teleportToBattleTarget
BattleEnd.OnClientEvent:Connect(function(result)
    State.InBattle = false
    State.LastBattleTime = tick()
    State.LastBattleResult = tostring(result or "Unknown")
    local completedBossId = State.ActiveBossId
    local completedStage = State.ActiveWorldStage
    State.ActiveBossId = nil
    State.ActiveWorldStage = nil
    if completedStage and completedStage.Kind == "enemy" then
        local won = State.LastBattleResult ~= "Defeat"
        State.LastWorldStageResult = State.LastBattleResult
        if won then
            State.WorldEnemyCleared[completedStage.Key] = true
        end
        logEvery("world_enemy_end", "World enemy ended: " .. tostring(completedStage.Key) .. " result=" .. State.LastBattleResult .. " cleared=" .. tostring(won), 1)
    end
    if completedBossId then
        task.spawn(function()
            task.wait(1)
            local defeated = false
            local ok, settings = pcall(function()
                return GetPlayerSettings and GetPlayerSettings:InvokeServer() or nil
            end)
            if ok and type(settings) == "table" and type(settings.DefeatedBosses) == "table" then
                defeated = settings.DefeatedBosses[completedBossId] == true
                    or (completedBossId == "ulmiorra" and settings.DefeatedBosses.ulquiorra == true)
            end
            State.LastBossResult = State.LastBattleResult
            State.LastBossDefeated = defeated
            logEvery("boss_end", "Boss ended: " .. completedBossId .. " result=" .. State.LastBattleResult .. " defeated=" .. tostring(defeated), 1)
        end)
    end
    logEvery("battle_end", "Battle ended: " .. State.LastBattleResult, 1)
end)

BattleVersus.OnClientEvent:Connect(function()
    State.InBattle = true
    logEvery("battle_start", "Battle started", 1)
end)

local function chooseSmartEnemy(count)
    if not Cfg.SmartBattle then
        return Cfg.BattleCardId
    end
    local power = getPartyPower()
    if power <= 0 then
        return Cfg.BattleCardId
    end
    local limit = power * math.clamp(tonumber(Cfg.SmartSafety) or 0.85, 0.1, 2)
    local bestId, bestScore = Cfg.BattleCardId, 0
    for id, data in pairs(CARD_DATA) do
        if type(id) == "string" and type(data) == "table" then
            local hasStats = (tonumber(data.Damage) or 0) > 0 or (tonumber(data.HP) or 0) > 0
            local score = cardScore(id, "BALANCED", "Normal") * count
            if hasStats and score > bestScore and score <= limit then
                bestId = id
                bestScore = score
            end
        end
    end
    if bestId ~= Cfg.BattleCardId then
        logEvery("smart_enemy", "Smart enemy selected " .. bestId .. " for party power " .. math.floor(power), 5)
    end
    return bestId
end

task.spawn(function()
    while task.wait(2) do
        if not Cfg.AutoBattle then continue end
        if State.InBattle then
            logEvery("battle_waiting", "In battle, waiting...", 10)
            continue
        end
        local gap = tick() - State.LastBattleTime
        if gap < 1.5 then task.wait(1.5 - gap) end
        local count = math.clamp(Cfg.BattleEnemyCount, 1, 4)
        local enemies = {}
        local enemyId = chooseSmartEnemy(count)
        for i = 1, count do
            enemies[i] = enemyId
        end
        local tpOk, tpMsg = teleportToBattleTarget(enemyId, false)
        if not tpOk then
            logEvery("enemy_tp_missing", "Could not find live enemy model for " .. tostring(enemyId) .. "; starting anyway (" .. tostring(tpMsg) .. ")", 8)
        end
        local ok, err = pcall(function()
            DebugStartBattle:FireServer(enemies)
        end)
        if ok then
            State.InBattle = true
            logEvery("battle_fired", "Auto Battle started vs " .. count .. "x " .. enemyId, 2)
        else
            logEvery("battle_err", "DebugStartBattle error: " .. tostring(err), 5)
        end
    end
end)

local BOSS_MAP = {
    panther_espada = "Hueco",
    ulmiorra = "Hueco",
    itadori_yuji = "Shibuya",
    mahito = "Shibuya",
    toji_fushiguro = "Shibuya",
    jogo = "Shibuya",
    sasuke_ms = "Naruto",
    itachi_akatsuki = "Naruto",
    madara_edo = "Naruto",
    bio_android_incomplete = "Cell",
    whitebeard_worldbreaker = "Marine",
    aokiji_frost_admiral = "Marine",
    kizaru_light_admiral = "Marine",
    akainu_infernal_judgement = "Marine",
}

local BOSS_MODEL_NAMES = {
    panther_espada = {"Grimmjow", "Panther Espada"},
    ulmiorra = {"Ulmiorra", "Ulquiorra", "Grimmjow"},
    itadori_yuji = {"Cursed Vessel"},
    mahito = {"Patchwork Curse"},
    toji_fushiguro = {"Sorcerer Killer"},
    jogo = {"Volcanic Curse"},
    sasuke_ms = {"Sasuke", "Avenging Shinobi"},
    itachi_akatsuki = {"itachi", "Akatsuki Phantom"},
    madara_edo = {"madara", "Reanimated Legend"},
    bio_android_incomplete = {"bio_android_incomplete", "Incomplete Bio-Android"},
    cyborg_17 = {"cyborg 17", "Cyborg 17"},
    cyborg_18 = {"cyborg 18", "Cyborg 18"},
    hidden_prodigy = {"hidden prodigy", "Half-Blood Prodigy"},
    whitebeard_worldbreaker = {"Worldbreaker"},
    aokiji_frost_admiral = {"Frost Admiral"},
    kizaru_light_admiral = {"Light Admiral"},
    akainu_infernal_judgement = {"Infernal Judgement"},
}

local WORLD_BOSS_ORDER = {
    "panther_espada",
    "ulmiorra",
    "itadori_yuji",
    "mahito",
    "toji_fushiguro",
    "jogo",
    "sasuke_ms",
    "itachi_akatsuki",
    "madara_edo",
    "bio_android_incomplete",
    "whitebeard_worldbreaker",
    "aokiji_frost_admiral",
    "kizaru_light_admiral",
    "akainu_infernal_judgement",
}

local WORLD_STAGES = {
    {World = "Hueco", Kind = "boss", BossId = "panther_espada", Label = "Panther Espada"},
    {World = "Hueco", Kind = "boss", BossId = "ulmiorra", Label = "Ulmiorra"},

    {World = "Shibuya", Kind = "boss", BossId = "itadori_yuji", Label = "Cursed Vessel"},
    {World = "Shibuya", Kind = "boss", BossId = "mahito", Label = "Patchwork Curse"},
    {World = "Shibuya", Kind = "boss", BossId = "toji_fushiguro", Label = "Sorcerer Killer"},
    {World = "Shibuya", Kind = "boss", BossId = "jogo", Label = "Volcanic Curse"},

    {World = "Naruto", Kind = "boss", BossId = "sasuke_ms", Label = "Avenging Shinobi"},
    {World = "Naruto", Kind = "boss", BossId = "itachi_akatsuki", Label = "Akatsuki Phantom"},
    {World = "Naruto", Kind = "boss", BossId = "madara_edo", Label = "Reanimated Legend"},

    {World = "Cell", Kind = "boss", BossId = "cyborg_17", Label = "Cyborg 17"},
    {World = "Cell", Kind = "boss", BossId = "cyborg_18", Label = "Cyborg 18"},
    {World = "Cell", Kind = "boss", BossId = "hidden_prodigy", Label = "Half-Blood Prodigy"},
    {World = "Cell", Kind = "enemy", Key = "cell_bio_spawn", EnemyIds = {"bio_spawn", "bio_spawn"}, Label = "Bio-Spawn", SkipIfBossDefeated = "bio_android_incomplete"},
    {World = "Cell", Kind = "boss", BossId = "bio_android_incomplete", Label = "Incomplete Bio-Android"},

    {World = "Marine", Kind = "boss", BossId = "whitebeard_worldbreaker", Label = "Worldbreaker"},
    {World = "Marine", Kind = "boss", BossId = "aokiji_frost_admiral", Label = "Frost Admiral"},
    {World = "Marine", Kind = "boss", BossId = "kizaru_light_admiral", Label = "Light Admiral"},
    {World = "Marine", Kind = "boss", BossId = "akainu_infernal_judgement", Label = "Infernal Judgement"},
}

local BOSS_DEFEAT_ALIASES = {
    ulmiorra = {"ulmiorra", "ulquiorra"},
    panther_espada = {"panther_espada"},
    cyborg_17 = {"cyborg_17"},
    cyborg_18 = {"cyborg_18"},
    hidden_prodigy = {"hidden_prodigy"},
}

local function requestTeleport(destination)
    if Cfg.TeleportFallback and TeleportEvent and type(destination) == "string" and destination ~= "" then
        pcall(function() TeleportEvent:FireServer(destination) end)
        task.wait(0.75)
    end
end

local function normalizeName(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function getRootPart()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function getInstanceCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.CFrame
    end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function()
            return inst:GetPivot()
        end)
        if ok and pivot then
            return pivot
        end
    end
    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

local function findTargetByNames(names)
    if type(names) ~= "table" then
        names = {names}
    end
    local zones = {}
    local bosses = workspace:FindFirstChild("Bosses")
    if bosses then table.insert(zones, bosses) end
    table.insert(zones, workspace)

    for _, zone in ipairs(zones) do
        for _, name in ipairs(names) do
            local direct = zone:FindFirstChild(tostring(name))
            if direct then
                local cf = getInstanceCFrame(direct)
                if cf then return direct, cf end
            end
        end
    end

    local wanted = {}
    for _, name in ipairs(names) do
        wanted[normalizeName(name)] = true
    end
    for _, zone in ipairs(zones) do
        for _, inst in ipairs(zone:GetDescendants()) do
            local n = normalizeName(inst.Name)
            if wanted[n] then
                local cf = getInstanceCFrame(inst)
                if cf then return inst, cf end
            end
        end
    end
    return nil, nil
end

local function getBattleTargetNames(cardId)
    local names = {cardId}
    local data = CARD_DATA[string.lower(tostring(cardId or ""))]
    if data and data.Name then
        table.insert(names, data.Name)
    end
    local bossNames = BOSS_MODEL_NAMES[string.lower(tostring(cardId or ""))]
    if bossNames then
        for _, name in ipairs(bossNames) do
            table.insert(names, name)
        end
    end
    return names
end

local function teleportToCFrameIfNeeded(cf, label)
    local root = getRootPart()
    if not root or not cf then
        return false, "missing root or target"
    end
    local distance = (root.Position - cf.Position).Magnitude
    if distance <= (tonumber(Cfg.BossStartDistance) or 35) then
        logEvery("tp_close_" .. tostring(label), "Already close to " .. tostring(label) .. " (" .. math.floor(distance) .. " studs)", 3)
        return true, "close"
    end
    local targetPos = cf.Position
    local offsetPos = targetPos + Vector3.new(0, 4, 10)
    root.CFrame = CFrame.lookAt(offsetPos, targetPos)
    task.wait(0.35)
    return true, "teleported"
end

function teleportToBattleTarget(cardId, isBoss)
    if not Cfg.TeleportBeforeBattle then
        return true, "disabled"
    end
    cardId = string.lower(tostring(cardId or ""))
    local names = getBattleTargetNames(cardId)
    local target, cf = findTargetByNames(names)
    if not target and isBoss then
        requestTeleport(BOSS_MAP[cardId])
        task.wait(1.25)
        target, cf = findTargetByNames(names)
    end
    if not cf then
        return false, "target not found"
    end
    return teleportToCFrameIfNeeded(cf, cardId)
end

local function getDefeatedBosses()
    local ok, settings = pcall(function()
        return GetPlayerSettings and GetPlayerSettings:InvokeServer() or nil
    end)
    if ok and type(settings) == "table" and type(settings.DefeatedBosses) == "table" then
        return settings.DefeatedBosses
    end
    return {}
end

local function isBossDefeated(defeatedBosses, bossId)
    bossId = string.lower(tostring(bossId or ""))
    local aliases = BOSS_DEFEAT_ALIASES[bossId] or {bossId}
    for _, id in ipairs(aliases) do
        if defeatedBosses[id] == true then
            return true
        end
    end
    return false
end

local function getNextWorldBoss()
    local defeated = getDefeatedBosses()
    for i, bossId in ipairs(WORLD_BOSS_ORDER) do
        if not isBossDefeated(defeated, bossId) then
            State.WorldBossIndex = i
            return bossId
        end
    end
    return nil
end

local function getNextWorldStage()
    local defeated = getDefeatedBosses()
    for i, stage in ipairs(WORLD_STAGES) do
        if stage.Kind == "boss" then
            if not isBossDefeated(defeated, stage.BossId) then
                State.WorldBossIndex = i
                return stage
            end
        elseif stage.Kind == "enemy" then
            local skipBecauseBossDone = stage.SkipIfBossDefeated and isBossDefeated(defeated, stage.SkipIfBossDefeated)
            if not skipBecauseBossDone and not State.WorldEnemyCleared[stage.Key] then
                State.WorldBossIndex = i
                return stage
            end
        end
    end
    return nil
end

local function startBossBattle(bossId)
    if not RequestBossBattle then
        return false, "RequestBossBattle remote missing"
    end
    bossId = string.lower(tostring(bossId or Cfg.BossId))
    local tpOk, tpMsg = teleportToBattleTarget(bossId, true)
    if not tpOk then
        logEvery("boss_tp_missing", "Could not find live boss model for " .. bossId .. "; requesting anyway (" .. tostring(tpMsg) .. ")", 8)
    end
    local ok, result = pcall(function()
        return RequestBossBattle:InvokeServer(bossId)
    end)
    if ok and type(result) == "table" and result.success then
        State.InBattle = true
        State.ActiveBossId = bossId
        State.LastBossTime = tick()
        return true, "started"
    end
    local msg = type(result) == "table" and tostring(result.message or "Unavailable") or tostring(result)
    return false, msg
end

local function startWorldStage(stage)
    if type(stage) ~= "table" then
        return false, "No world stage"
    end
    if stage.Kind == "boss" then
        local ok, msg = startBossBattle(stage.BossId)
        if ok then
            State.ActiveWorldStage = stage
        end
        return ok, msg
    elseif stage.Kind == "enemy" then
        local enemies = stage.EnemyIds
        if type(enemies) ~= "table" or #enemies == 0 then
            return false, "World enemy stage has no enemies"
        end
        requestTeleport(stage.World)
        local tpOk, tpMsg = teleportToBattleTarget(enemies[1], false)
        if not tpOk then
            logEvery("world_enemy_tp_missing", "Could not find world enemy " .. tostring(enemies[1]) .. "; starting anyway (" .. tostring(tpMsg) .. ")", 8)
        end
        local ok, err = pcall(function()
            DebugStartBattle:FireServer(enemies)
        end)
        if ok then
            State.InBattle = true
            State.ActiveWorldStage = stage
            State.LastBossTime = tick()
            return true, "started enemy"
        end
        return false, tostring(err)
    end
    return false, "Unknown world stage kind"
end

task.spawn(function()
    while task.wait(3) do
        if not Cfg.AutoBoss or Cfg.AutoWorldBosses then continue end
        if State.InBattle or LocalPlayer:GetAttribute("InBattle") == true or LocalPlayer:GetAttribute("InRaid") == true then
            logEvery("boss_waiting", "Already in battle/raid, waiting...", 10)
            continue
        end
        if tick() - State.LastBossTime < 8 then continue end
        local ok, msg = startBossBattle(Cfg.BossId)
        if ok then
            logEvery("boss_started", "Boss battle requested: " .. tostring(Cfg.BossId), 2)
        else
            logEvery("boss_err", "Boss unavailable: " .. tostring(msg), 10)
            State.LastBossTime = tick()
        end
    end
end)

task.spawn(function()
    while task.wait(4) do
        if not Cfg.AutoWorldBosses then continue end
        if State.InBattle or LocalPlayer:GetAttribute("InBattle") == true or LocalPlayer:GetAttribute("InRaid") == true then
            logEvery("world_waiting", "World boss progression waiting for current battle/raid...", 10)
            continue
        end
        if tick() - State.LastBossTime < 8 then continue end
        local stage = getNextWorldStage()
        if not stage then
            logEvery("world_done", "All known world stages are cleared/defeated", 30)
            continue
        end
        if stage.BossId then
            Cfg.BossId = stage.BossId
        end
        local ok, msg = startWorldStage(stage)
        if ok then
            logEvery("world_started", "World progression started " .. tostring(stage.Kind) .. ": " .. tostring(stage.Label or stage.BossId or stage.Key), 2)
        else
            logEvery("world_err", "World stage unavailable/failed to start: " .. tostring(stage.Label or stage.BossId or stage.Key) .. " -> " .. tostring(msg), 10)
            State.LastBossTime = tick()
        end
    end
end)

if RaidPartyUpdate then
    RaidPartyUpdate.OnClientEvent:Connect(function(update)
        if type(update) ~= "table" then return end
        if update.Action == "Sync" or update.Action == "PlayerJoined" or update.Action == "PlayerReady" then
            State.InRaidParty = true
        elseif update.Action == "PartyDisbanded" or update.Action == "LeftParty" or update.Action == "KickedFromParty" then
            State.InRaidParty = false
        elseif update.Action == "RaidStarting" then
            State.InRaidParty = false
        end
    end)
end

if RaidPartyStarted then
    RaidPartyStarted.OnClientEvent:Connect(function()
        State.InRaidParty = false
        State.InBattle = true
    end)
end

local function createRaid()
    if not RaidPartyCreate or not RaidPartyReady then
        return false, "Raid remotes missing"
    end
    if Cfg.TeleportFallback then
        requestTeleport("Raid")
    end
    RaidPartyCreate:FireServer({
        IsPrivate = false,
        BossId = Cfg.RaidBossId,
        Difficulty = Cfg.RaidDifficulty,
    })
    task.wait(0.8)
    RaidPartyReady:FireServer(true)
    State.LastRaidTime = tick()
    return true, "created"
end

task.spawn(function()
    while task.wait(4) do
        if not Cfg.AutoRaid then continue end
        if State.InBattle or LocalPlayer:GetAttribute("InBattle") == true or LocalPlayer:GetAttribute("InRaid") == true then
            logEvery("raid_waiting", "Already in battle/raid, waiting...", 10)
            continue
        end
        if State.InRaidParty then
            if tick() - State.LastRaidTime > 60 then
                State.InRaidParty = false
                logEvery("raid_watchdog", "Raid party did not start; retrying create path", 10)
                continue
            end
            pcall(function() RaidPartyReady:FireServer(true) end)
            continue
        end
        if tick() - State.LastRaidTime < 12 then continue end
        local ok, msg = createRaid()
        if ok then
            logEvery("raid_created", "Raid party created: " .. tostring(Cfg.RaidDifficulty), 3)
        else
            logEvery("raid_err", "Raid unavailable: " .. tostring(msg), 10)
            State.LastRaidTime = tick()
        end
    end
end)

-- ─── Auto Claim Quests ────────────────────────────────────────────────────────
-- ClaimAllQuestsReward:FireServer() confirmed in QuestController.client.lua:1057
task.spawn(function()
    while task.wait(15) do
        if not Cfg.AutoClaimQuests then continue end
        local ok, err = pcall(function()
            ClaimAllQuestsReward:FireServer()
        end)
        if ok then
            logEvery("quest_claim", "Auto Claim Quests fired", 15)
        else
            logEvery("quest_claim_err", "ClaimAllQuestsReward error: " .. tostring(err), 10)
        end
    end
end)

-- ─── Auto Equip Best Deck ─────────────────────────────────────────────────────
-- RequestEquipCard / RequestUnequipCard confirmed in DeckFrameController.client.lua:80-99
task.spawn(function()
    while task.wait(8) do
        if not Cfg.AutoEquipBest then continue end
        equipBestDeck()
    end
end)

-- ─── Rayfield UI ─────────────────────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name            = "Anime Card Crusade Auto",
    LoadingTitle    = "Anime Card Auto",
    LoadingSubtitle = "Loading verified remotes...",
    ConfigurationSaving = { Enabled = false },
    Discord         = false,
    KeySystem       = false,
})

-- ══ Tab: Roll ═══════════════════════════════════════════════════════════════
local RollTab = Window:CreateTab("Roll")

RollTab:CreateSection("Auto Roll", false)

RollTab:CreateToggle({
    Name         = "Auto Roll",
    Info         = "Fires SetAutoRollState:FireServer(true) every second, mirrors the in-game Auto button.",
    CurrentValue = false,
    Flag         = "AutoRoll",
    Callback     = function(v) Cfg.AutoRoll = v end,
})

RollTab:CreateToggle({
    Name         = "Fast Roll (Skip Animation)",
    Info         = "Fires UpdateSettings SkipRollAnimation=true. Rolls will skip the card reveal animation.",
    CurrentValue = false,
    Flag         = "FastRoll",
    Callback     = function(v) Cfg.FastRoll = v end,
})

RollTab:CreateSection("Manual Roll", false)

RollTab:CreateButton({
    Name     = "Roll Once",
    Info     = "Fires RequestCardSpin:FireServer() for one immediate roll.",
    Interact = "Roll",
    Callback = function()
        local ok, err = pcall(function() RequestCardSpin:FireServer() end)
        if ok then print("[AnimeCardAuto] Manual roll fired") else warn("[AnimeCardAuto] Roll error: " .. tostring(err)) end
    end,
})

RollTab:CreateButton({
    Name     = "Roll x10",
    Info     = "Fires RequestCardSpin 10 times with 0.15s delay.",
    Interact = "Spam",
    Callback = function()
        for i = 1, 10 do
            pcall(function() RequestCardSpin:FireServer() end)
            task.wait(0.15)
        end
        print("[AnimeCardAuto] Rolled x10")
    end,
})

-- ══ Tab: Battle ══════════════════════════════════════════════════════════════
local BattleTab = Window:CreateTab("Battle")

BattleTab:CreateSection("Auto Battle", false)

BattleTab:CreateToggle({
    Name         = "Auto Battle",
    Info         = "Fires DebugStartBattle when not in battle. Restarts when BattleEnd fires.",
    CurrentValue = false,
    Flag         = "AutoBattle",
    Callback     = function(v) Cfg.AutoBattle = v end,
})

-- Sorted card list for enemy picker (by RarityNumber ascending for readability)
local ENEMY_OPTIONS = {}
do
    local sorted = {}
    for id, data in pairs(CARD_DATA) do
        table.insert(sorted, {id = id, name = data.Name or id, rarity = tonumber(data.RarityNumber) or 0})
    end
    table.sort(sorted, function(a, b) return a.rarity < b.rarity end)
    for _, v in ipairs(sorted) do
        table.insert(ENEMY_OPTIONS, v.id .. " (" .. v.name .. ")")
    end
end

BattleTab:CreateDropdown({
    Name           = "Enemy Card",
    Info           = "Pick which card to fight. Uses DebugStartBattle remote.",
    Options        = ENEMY_OPTIONS,
    CurrentOption  = "slime (Skeleton)",
    MultiSelection = false,
    Flag           = "BattleCardId",
    Callback       = function(opt)
        local choice = type(opt) == "table" and opt[1] or opt
        if choice then
            Cfg.BattleCardId = string.match(choice, "^([^%s%(]+)")
        end
    end,
})

BattleTab:CreateSlider({
    Name     = "Enemy Count (1-4)",
    Info     = "Number of enemy cards to face per battle.",
    Range    = {1, 4},
    Increment = 1,
    CurrentValue = 1,
    Flag     = "BattleEnemyCount",
    Callback = function(v) Cfg.BattleEnemyCount = v end,
})

BattleTab:CreateToggle({
    Name         = "Smart Enemy",
    Info         = "Chooses the strongest enemy your current deck should handle. Disable to force the dropdown enemy.",
    CurrentValue = true,
    Flag         = "SmartBattle",
    Callback     = function(v) Cfg.SmartBattle = v end,
})

BattleTab:CreateSlider({
    Name     = "Smart Safety",
    Info     = "Lower is safer. 0.85 means enemy power must stay below 85% of your deck estimate.",
    Range    = {0.25, 1.5},
    Increment = 0.05,
    CurrentValue = 0.85,
    Flag     = "SmartSafety",
    Callback = function(v) Cfg.SmartSafety = tonumber(v) or 0.85 end,
})

BattleTab:CreateSection("Manual Battle", false)

BattleTab:CreateButton({
    Name     = "Start Battle Now",
    Info     = "Immediately starts a battle with selected enemy.",
    Interact = "Fight",
    Callback = function()
        local count = math.clamp(Cfg.BattleEnemyCount, 1, 4)
        local enemies = {}
        for i = 1, count do enemies[i] = Cfg.BattleCardId end
        local tpOk, tpMsg = teleportToBattleTarget(Cfg.BattleCardId, false)
        if not tpOk then
            warn("[AnimeCardAuto] Enemy TP skipped: " .. tostring(tpMsg))
        end
        local ok, err = pcall(function() DebugStartBattle:FireServer(enemies) end)
        if ok then print("[AnimeCardAuto] Battle started") else warn("[AnimeCardAuto] Battle error: " .. tostring(err)) end
    end,
})

-- Boss and raid automation use the same direct remotes as the game's UI.
local BOSS_IDS = {
    "panther_espada",
    "ulmiorra",
    "itadori_yuji",
    "mahito",
    "toji_fushiguro",
    "jogo",
    "sasuke_ms",
    "itachi_akatsuki",
    "madara_edo",
    "bio_android_incomplete",
    "whitebeard_worldbreaker",
    "aokiji_frost_admiral",
    "kizaru_light_admiral",
    "akainu_infernal_judgement",
}

local BOSS_OPTIONS = {}
for _, id in ipairs(BOSS_IDS) do
    local data = CARD_DATA[id]
    table.insert(BOSS_OPTIONS, id .. " (" .. (data and data.Name or id) .. ")")
end

local BossTab = Window:CreateTab("Boss")

BossTab:CreateSection("Boss Battles", false)

BossTab:CreateDropdown({
    Name           = "Boss",
    Info           = "Uses RequestBossBattle directly. Locked bosses or cooldowns still fail server-side.",
    Options        = BOSS_OPTIONS,
    CurrentOption  = "panther_espada (Panther Espada)",
    MultiSelection = false,
    Flag           = "BossId",
    Callback       = function(opt)
        local choice = type(opt) == "table" and opt[1] or opt
        if choice then
            Cfg.BossId = string.match(choice, "^([^%s%(]+)")
        end
    end,
})

BossTab:CreateToggle({
    Name         = "Auto Boss",
    Info         = "Teleports to the selected boss unless close, then requests the fight.",
    CurrentValue = false,
    Flag         = "AutoBoss",
    Callback     = function(v) Cfg.AutoBoss = v end,
})

BossTab:CreateToggle({
    Name         = "Auto Worlds",
    Info         = "Runs world lead-up enemies first, then bosses. Advances only after victory or DefeatedBosses confirmation.",
    CurrentValue = false,
    Flag         = "AutoWorldBosses",
    Callback     = function(v) Cfg.AutoWorldBosses = v end,
})

BossTab:CreateToggle({
    Name         = "TP Before Battle",
    Info         = "Moves your character near the boss/enemy model first. If already close, it starts without moving.",
    CurrentValue = true,
    Flag         = "TeleportBeforeBattle",
    Callback     = function(v) Cfg.TeleportBeforeBattle = v end,
})

BossTab:CreateToggle({
    Name         = "World TP Fallback",
    Info         = "If the boss model is not loaded, uses the game's TeleportEvent to go to that world before starting.",
    CurrentValue = true,
    Flag         = "TeleportFallback",
    Callback     = function(v) Cfg.TeleportFallback = v end,
})

BossTab:CreateSlider({
    Name     = "Close Distance",
    Info     = "If you are within this many studs from the boss/enemy, the script will not move you.",
    Range    = {10, 120},
    Increment = 5,
    CurrentValue = 35,
    Flag     = "BossStartDistance",
    Callback = function(v) Cfg.BossStartDistance = tonumber(v) or 35 end,
})

BossTab:CreateButton({
    Name     = "Start Boss Now",
    Info     = "Teleports to the selected boss unless close, then invokes RequestBossBattle.",
    Interact = "Fight",
    Callback = function()
        local ok, msg = startBossBattle(Cfg.BossId)
        if ok then print("[AnimeCardAuto] Boss requested: " .. tostring(Cfg.BossId)) else warn("[AnimeCardAuto] Boss failed: " .. tostring(msg)) end
    end,
})

BossTab:CreateButton({
    Name     = "Start Next World Stage",
    Info     = "Finds the first uncleared world stage: lead-up enemies first, then boss.",
    Interact = "Next",
    Callback = function()
        local stage = getNextWorldStage()
        if not stage then
            print("[AnimeCardAuto] All known world stages are already cleared.")
            return
        end
        if stage.BossId then
            Cfg.BossId = stage.BossId
        end
        local ok, msg = startWorldStage(stage)
        if ok then print("[AnimeCardAuto] World stage requested: " .. tostring(stage.Label or stage.BossId or stage.Key)) else warn("[AnimeCardAuto] World stage failed: " .. tostring(msg)) end
    end,
})

local RaidTab = Window:CreateTab("Raid")

RaidTab:CreateSection("Raid Party", false)

RaidTab:CreateDropdown({
    Name           = "Difficulty",
    Info           = "Creates a Divine General raid party at this difficulty, then readies up.",
    Options        = {"Easy", "Medium", "Hard", "Nightmare", "Impossible"},
    CurrentOption  = "Easy",
    MultiSelection = false,
    Flag           = "RaidDifficulty",
    Callback       = function(opt)
        local choice = type(opt) == "table" and opt[1] or opt
        if choice then Cfg.RaidDifficulty = choice end
    end,
})

RaidTab:CreateToggle({
    Name         = "Auto Raid",
    Info         = "Creates and readies a raid party when you are not in battle. Server rules still control start timing.",
    CurrentValue = false,
    Flag         = "AutoRaid",
    Callback     = function(v) Cfg.AutoRaid = v end,
})

RaidTab:CreateButton({
    Name     = "Create Raid Now",
    Info     = "Fires RaidPartyCreate, then RaidPartyReady(true).",
    Interact = "Create",
    Callback = function()
        local ok, msg = createRaid()
        if ok then print("[AnimeCardAuto] Raid created") else warn("[AnimeCardAuto] Raid failed: " .. tostring(msg)) end
    end,
})

-- ══ Tab: Deck ════════════════════════════════════════════════════════════════
local DeckTab = Window:CreateTab("Deck")

DeckTab:CreateSection("Auto Equip Best Deck", false)

DeckTab:CreateParagraph({
    Title   = "How it works",
    Content = "Syncs your owned cards via RequestPlayerCards, sorts by your chosen mode, then equips the top 4 via RequestEquipCard. Only equips cards present in CardData. Updates every 8 seconds while enabled.",
})

DeckTab:CreateToggle({
    Name         = "Auto Equip Best Deck",
    Info         = "Automatically equips your top 4 owned cards every 8s.",
    CurrentValue = false,
    Flag         = "AutoEquipBest",
    Callback     = function(v) Cfg.AutoEquipBest = v end,
})

DeckTab:CreateDropdown({
    Name           = "Deck Mode",
    Info           = "ATK = highest Damage. HP = highest HP. BALANCED = highest Damage+HP combined.",
    Options        = {"ATK", "HP", "BALANCED"},
    CurrentOption  = "ATK",
    MultiSelection = false,
    Flag           = "EquipMode",
    Callback       = function(opt)
        local choice = type(opt) == "table" and opt[1] or opt
        if choice then Cfg.EquipMode = choice end
    end,
})

DeckTab:CreateButton({
    Name     = "Equip Best Deck Now",
    Info     = "Immediately equips best deck based on your selected mode.",
    Interact = "Equip",
    Callback = function()
        task.spawn(equipBestDeck)
    end,
})

DeckTab:CreateSection("Manual Card Equip", false)

DeckTab:CreateButton({
    Name     = "Sync Owned Cards",
    Info     = "Fetches your card collection from RequestPlayerCards. Required before deck building.",
    Interact = "Sync",
    Callback = function()
        local ok = syncOwnedCards()
        local count = 0
        for _ in pairs(State.OwnedCards) do count = count + 1 end
        if ok then
            print("[AnimeCardAuto] Synced " .. count .. " owned cards")
        else
            warn("[AnimeCardAuto] Failed to sync owned cards")
        end
    end,
})

-- ══ Tab: Quests ══════════════════════════════════════════════════════════════
local QuestTab = Window:CreateTab("Quests")

QuestTab:CreateSection("Auto Claim", false)

QuestTab:CreateToggle({
    Name         = "Auto Claim Quests",
    Info         = "Fires ClaimAllQuestsReward every 15 seconds.",
    CurrentValue = false,
    Flag         = "AutoClaimQuests",
    Callback     = function(v) Cfg.AutoClaimQuests = v end,
})

QuestTab:CreateButton({
    Name     = "Claim All Quests Now",
    Info     = "Immediately fires ClaimAllQuestsReward:FireServer().",
    Interact = "Claim",
    Callback = function()
        local ok, err = pcall(function() ClaimAllQuestsReward:FireServer() end)
        if ok then print("[AnimeCardAuto] Claimed all quests") else warn("[AnimeCardAuto] Quest claim error: " .. tostring(err)) end
    end,
})

-- ══ Tab: Inventory ═══════════════════════════════════════════════════════════
local InvTab = Window:CreateTab("Inventory")

InvTab:CreateSection("Items", false)

InvTab:CreateButton({
    Name     = "Use Item (1x)",
    Info     = "Fires UseItemSecure. Edit the item ID in output first by checking your inventory.",
    Interact = "Use",
    Callback = function()
        print("[AnimeCardAuto] To use an item, call UseItemSecure:FireServer(itemId, 1) with your item's server ID.")
    end,
})

InvTab:CreateSection("Relics & Talismans", false)

InvTab:CreateButton({
    Name     = "Equip Relic (by ID)",
    Info     = "Fires RequestEquipRelic with the relic ID from your inventory.",
    Interact = "Equip",
    Callback = function()
        print("[AnimeCardAuto] To equip a relic, call RequestEquipRelic:FireServer(relicId) with the server relic ID from your inventory data.")
    end,
})

InvTab:CreateButton({
    Name     = "Equip Talisman (by ID)",
    Info     = "Fires RequestEquipTalisman with talisman ID.",
    Interact = "Equip",
    Callback = function()
        print("[AnimeCardAuto] To equip a talisman, call RequestEquipTalisman:FireServer(talismanId) with the server ID.")
    end,
})

-- ══ Tab: Settings ═════════════════════════════════════════════════════════════
local SetTab = Window:CreateTab("Settings")

SetTab:CreateSection("Status", false)

SetTab:CreateButton({
    Name     = "Print Status",
    Info     = "Prints current feature states and owned card count to output.",
    Interact = "Print",
    Callback = function()
        local owned = 0
        for _ in pairs(State.OwnedCards) do owned = owned + 1 end
        print("===== AnimeCardAuto Status =====")
        print("AutoRoll:        " .. tostring(Cfg.AutoRoll))
        print("FastRoll:        " .. tostring(Cfg.FastRoll))
        print("AutoBattle:      " .. tostring(Cfg.AutoBattle))
        print("SmartBattle:     " .. tostring(Cfg.SmartBattle) .. " safety=" .. tostring(Cfg.SmartSafety))
        print("  BattleCard:    " .. tostring(Cfg.BattleCardId))
        print("  EnemyCount:    " .. tostring(Cfg.BattleEnemyCount))
        print("AutoBoss:        " .. tostring(Cfg.AutoBoss) .. " boss=" .. tostring(Cfg.BossId))
        print("AutoWorldBosses: " .. tostring(Cfg.AutoWorldBosses))
        print("AutoRaid:        " .. tostring(Cfg.AutoRaid) .. " difficulty=" .. tostring(Cfg.RaidDifficulty))
        print("TPBeforeBattle:  " .. tostring(Cfg.TeleportBeforeBattle) .. " close=" .. tostring(Cfg.BossStartDistance))
        print("TeleportFallback:" .. tostring(Cfg.TeleportFallback))
        print("AutoClaimQuests: " .. tostring(Cfg.AutoClaimQuests))
        print("AutoEquipBest:   " .. tostring(Cfg.AutoEquipBest))
        print("  DeckMode:      " .. tostring(Cfg.EquipMode))
        print("InBattle:        " .. tostring(State.InBattle))
        print("InRaidParty:     " .. tostring(State.InRaidParty))
        print("LastBossResult:  " .. tostring(State.LastBossResult) .. " defeated=" .. tostring(State.LastBossDefeated))
        print("LastWorldStage:  " .. tostring(State.LastWorldStageResult))
        print("OwnedCards:      " .. owned .. " known")
        print("================================")
    end,
})

-- Initial sync on load
task.spawn(function()
    task.wait(3)
    syncOwnedCards()
    local count = 0
    for _ in pairs(State.OwnedCards) do count = count + 1 end
    print("[AnimeCardAuto] Loaded. Synced " .. count .. " owned cards from server.")
end)

print("[AnimeCardAuto] Script loaded successfully.")
