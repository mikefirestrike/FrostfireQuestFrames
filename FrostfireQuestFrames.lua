-- FrostfireQuestFrames.lua
-- v0.2d

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[FQF]|r " .. tostring(msg))
end

local _, _, screenWidth, screenHeight = WorldFrame:GetBoundsRect()

-- ============================================================
--  SAVED VARIABLES & DEFAULTS
-- ============================================================

local DEFAULTS = {
    bgHorde    = "custom:horde",
    bgAlliance = "custom:alliance",
    bgNeutral  = "custom:other",
}

FQFConfig = FQFConfig or {}

local function GetCfg(key)
    if FQFConfig[key] ~= nil then return FQFConfig[key] end
    return DEFAULTS[key]
end

local function SetCfg(key, value)
    FQFConfig[key] = value
end

-- ============================================================
--  TEXTURE REGISTRY
-- ============================================================

local ART = "Interface\\AddOns\\FrostfireQuestFrames\\Art\\"

-- Built-in textures. Add entries here to expose new options
-- without touching the options UI code.
local CUSTOM_TEXTURES = {
    { label = "Horde",    key = "custom:horde",    path = ART .. "horde.tga"    },
    { label = "Alliance", key = "custom:alliance", path = ART .. "alliance.tga" },
    { label = "Neutral",  key = "custom:other",    path = ART .. "other.tga"    },
}

-- Resolve a config key to a texture path
local function ResolveTexture(key)
    if not key then return ART .. "other.tga" end
    for _, t in ipairs(CUSTOM_TEXTURES) do
        if t.key == key then return t.path end
    end
    return ART .. "other.tga"
end

-- ============================================================
--  FACTION BACKGROUND
-- ============================================================

local function GetFactionBG()
    local npcFaction = UnitFactionGroup("target")
    if npcFaction == "Horde" then
        return ResolveTexture(GetCfg("bgHorde"))
    end
    if npcFaction == "Alliance" then
        return ResolveTexture(GetCfg("bgAlliance"))
    end
    if not npcFaction or npcFaction == "Neutral" or npcFaction == "" then
        return ResolveTexture(GetCfg("bgNeutral"))
    end
    local playerFaction = UnitFactionGroup("player")
    if playerFaction == "Horde" then
        return ResolveTexture(GetCfg("bgHorde"))
    end
    if playerFaction == "Alliance" then
        return ResolveTexture(GetCfg("bgAlliance"))
    end
    return ResolveTexture(GetCfg("bgNeutral"))
end

-- ============================================================
--  FRAME BANISHMENT
-- ============================================================

local function BanishFrames()
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint("TOPLEFT", screenWidth, screenHeight)
    QuestFrame:ClearAllPoints()
    QuestFrame:SetPoint("TOPLEFT", screenWidth, screenHeight)
end

local function RestoreFrames()
    GossipFrame:ClearAllPoints()
    GossipFrame:SetPoint("TOPLEFT", 16, -116)
    QuestFrame:ClearAllPoints()
    QuestFrame:SetPoint("TOPLEFT", 16, -116)
end

-- ============================================================
--  SHARED TIMER
-- ============================================================

local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = #timers, 1, -1 do
        timers[i].t = timers[i].t - elapsed
        if timers[i].t <= 0 then
            local fn = timers[i].fn
            table.remove(timers, i)
            fn()
        end
    end
end)

local function DelayCall(func, delay)
    table.insert(timers, {t = delay, fn = func})
end

-- ============================================================
--  ANIMATION SYSTEM
-- ============================================================

local ANIMS = {
    NPC    = { {64, 2.5}, {64, 2.5}, {65, 2.8}, {67, 2.3}, {209, 2.8} },
    PLAYER = { {65, 2.8}, {185, 2.2}, {186, 2.0}, {113, 2.5}, {67, 2.3} },
}

local ANIMS_SAFE = {
    NPC    = { {64, 2.8}, {67, 2.6} },
    PLAYER = { {65, 3.0}, {67, 2.6} },
}

-- Player unit fallback: race/sex denylist for HD backport rigs.
-- sex: 2 = male, 3 = female. Add entries as discovered.
local ANIM_FALLBACK_RACES = {
    ["Blood Elf"] = { [3] = true },
}

local function UnitNeedsAnimFallback(unit)
    local race = UnitRace(unit)
    if not race then return false end
    local sex = UnitSex(unit)
    return ANIM_FALLBACK_RACES[race] and ANIM_FALLBACK_RACES[race][sex] or false
end

-- NPC model fallback: UnitRace doesn't work on NPCs so we check the M2 path
-- returned by GetModel() after SetUnit. Add substrings as more bad models found.
local ANIM_FALLBACK_MODEL_SUBSTRINGS = {
    "bloodelf", "belf",
}

local function ModelNeedsAnimFallback(model)
    local path = ""
    pcall(function()
        local m = model:GetModel()
        if type(m) == "string" then path = m end
    end)
    path = path:lower()
    for _, substr in ipairs(ANIM_FALLBACK_MODEL_SUBSTRINGS) do
        if path:find(substr) then return true end
    end
    return false
end

local function playAnim(model, sequence, duration)
    model.animTimer = 0
    model:SetScript("OnUpdate", function(self, elapsed)
        self.animTimer = self.animTimer + elapsed
        if self.animTimer > duration or sequence == 0 then
            self:SetScript("OnUpdate", nil)
        else
            pcall(function()
                self:SetSequenceTime(sequence, self.animTimer * 1000)
            end)
        end
    end)
end

local function playAndStand(model, sequence, duration)
    local token = math.random(1, 1000000)
    model.animToken = token
    playAnim(model, sequence, duration)
    DelayCall(function()
        if model.animToken == token then
            playAnim(model, 0, 0)
        end
    end, duration)
end

local function playAnimSafe(model, sequence)
    pcall(function() model:SetAnimation(sequence) end)
end

-- ============================================================
--  CAMERA PROFILES
-- ============================================================

local CAMERA_PROFILES = {
    humanoid = { camera = 1, scale = 1.0, x = 0, y = 0,    z = 0 },
    large    = { camera = 1, scale = 0.5, x = 0, y = 1.5,  z = 0 },
    small    = { camera = 1, scale = 1.4, x = 0, y = -0.3, z = 0 },
    wide     = { camera = 1, scale = 0.7, x = 0, y = 0.5,  z = 0 },
}

local CREATURE_TYPE_PROFILE = {
    ["Humanoid"]       = "humanoid",
    ["Undead"]         = "humanoid",
    ["Demon"]          = "humanoid",
    ["Giant"]          = "large",
    ["Dragonkin"]      = "large",
    ["Elemental"]      = "wide",
    ["Beast"]          = "small",
    ["Mechanical"]     = "small",
    ["Totem"]          = nil,
    ["Non-combat Pet"] = nil,
}

-- Returns a profile table or nil (nil = object mode, hide NPC model)
local function GetNPCProfile()
    local creatureType = UnitCreatureType("target")
    if creatureType == nil then return nil end
    -- Check explicit nil mappings (Totem, Non-combat Pet) vs missing key
    for k, _ in pairs(CREATURE_TYPE_PROFILE) do
        if k == creatureType then
            local profileName = CREATURE_TYPE_PROFILE[creatureType]
            if profileName then return CAMERA_PROFILES[profileName] end
            return nil
        end
    end
    -- Not in table: fall back to humanoid
    return CAMERA_PROFILES["humanoid"]
end

-- ============================================================
--  NPC MODEL PANEL SHOW/HIDE
-- ============================================================

local npcModelHidden = false

local function ShowNPCModel()
    if npcModelHidden then
        FQFModelNPC:Show()
        FQFModelNPC:ClearAllPoints()
        FQFModelNPC:SetPoint("BOTTOMRIGHT", FQFParchmentFrame, "BOTTOMRIGHT", 120, -100)
        npcModelHidden = false
    end
end

local function HideNPCModel()
    if not npcModelHidden then
        FQFModelNPC:Hide()
        npcModelHidden = true
    end
end

-- ============================================================
--  MODELS
-- ============================================================

local function ApplyProfile(model, profile)
    model:SetCamera(profile.camera)
    model:SetFacing(-.75)
    model:SetScale(profile.scale)
    model:SetPosition(profile.x, profile.y, profile.z)
end

-- Schedule back-and-forth conversation animations between player and NPC.
-- useSafeNPC/useSafePlayer route to SetAnimation instead of SetSequenceTime
-- for models with broken HD backport rigs.
local function ScheduleConversation(useSafeNPC, useSafePlayer)
    local npcAnimSet    = useSafeNPC    and ANIMS_SAFE.NPC    or ANIMS.NPC
    local playerAnimSet = useSafePlayer and ANIMS_SAFE.PLAYER or ANIMS.PLAYER
    local t = 0.4
    for i = 1, 5 do
        local npcAnim    = npcAnimSet[math.random(#npcAnimSet)]
        local playerAnim = playerAnimSet[math.random(#playerAnimSet)]
        local nt = t
        local pt = t + npcAnim[2] + 0.2

        if useSafeNPC then
            local seq = npcAnim[1]
            DelayCall(function() playAnimSafe(FQFModelNPC, seq) end, nt)
        else
            local seq, dur = npcAnim[1], npcAnim[2]
            DelayCall(function() playAndStand(FQFModelNPC, seq, dur) end, nt)
        end

        if useSafePlayer then
            local seq = playerAnim[1]
            DelayCall(function() playAnimSafe(FQFModelPlayer, seq) end, pt)
        else
            local seq, dur = playerAnim[1], playerAnim[2]
            DelayCall(function() playAndStand(FQFModelPlayer, seq, dur) end, pt)
        end

        t = pt + playerAnim[2] + 0.2
    end
end

local function SchedulePlayerAnims(useSafe)
    local animSet = useSafe and ANIMS_SAFE.PLAYER or ANIMS.PLAYER
    local t = 0.4
    for i = 1, 3 do
        local anim = animSet[math.random(#animSet)]
        local nt = t
        if useSafe then
            local seq = anim[1]
            DelayCall(function() playAnimSafe(FQFModelPlayer, seq) end, nt)
        else
            local seq, dur = anim[1], anim[2]
            DelayCall(function() playAndStand(FQFModelPlayer, seq, dur) end, nt)
        end
        t = nt + anim[2] + 0.3
    end
end

local function SetupModels(targetType)
    FQFModelPlayer:SetLight(1, 0, 0, -1, -1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    FQFModelPlayer:SetCamera(1)
    FQFModelPlayer:SetFacing(.75)
    FQFModelPlayer:SetUnit("player", false)
    FQFModelPlayer:SetPosition(0, 0, 0)
    FQFModelPlayer:SetScale(1.0)

    local profile = GetNPCProfile()

    if profile == nil then
        -- Object/totem: no NPC model, player animates solo
        HideNPCModel()
        SchedulePlayerAnims(UnitNeedsAnimFallback("player"))
        return
    end

    ShowNPCModel()
    FQFModelNPC:SetLight(1, 0, 0, 1, 1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    -- Apply profile BEFORE SetUnit so facing/scale are set as part of the
    -- model load, matching original behavior that worked correctly.
    ApplyProfile(FQFModelNPC, profile)
    FQFModelNPC:SetUnit("target", false)

    -- GetModel() isn't populated until SetUnit's model load completes, so
    -- delay the fallback check and conversation scheduling by one short tick.
    -- ApplyProfile stays before SetUnit so facing is unaffected.
    local useSafePlayer = UnitNeedsAnimFallback("player")
    DelayCall(function()
        local useSafeNPC = ModelNeedsAnimFallback(FQFModelNPC)
        ScheduleConversation(useSafeNPC, useSafePlayer)
    end, 0.1)
end

local function ClearModels()
    for i = #timers, 1, -1 do table.remove(timers, i) end
    pcall(function() FQFModelPlayer:ClearModel() end)
    pcall(function() FQFModelNPC:ClearModel() end)
    ShowNPCModel()
end

-- ============================================================
--  SIZING
-- ============================================================

local QUEST_W = 384
local QUEST_H = 500
local INNER_W = 560
local INNER_H = 560

-- ============================================================
--  STRIP VANILLA CHROME
-- ============================================================

local vanillaStripped = false

local function StripVanillaChrome()
    if vanillaStripped then return end
    vanillaStripped = true

    local function ZeroTextures(frame)
        local ok, n = pcall(function() return frame:GetNumRegions() end)
        if not ok or not n then return end
        for i = 1, n do
            local r = select(i, frame:GetRegions())
            if r and r:GetObjectType() == "Texture" then
                r:SetAlpha(0)
            end
        end
    end

    ZeroTextures(QuestFrame)
    ZeroTextures(GossipFrame)

    for _, name in ipairs({"QuestFramePortrait", "GossipFramePortrait"}) do
        local f = _G[name]
        if f then f:SetAlpha(0) end
    end

    for _, name in ipairs({
        "GossipFrameGreetingPanelMaterialTopLeft",
        "GossipFrameGreetingPanelMaterialTopRight",
        "GossipFrameGreetingPanelMaterialBotLeft",
        "GossipFrameGreetingPanelMaterialBotRight",
    }) do
        local t = _G[name]
        if t then t:SetAlpha(0) end
    end

    if GossipFrameGreetingPanel then ZeroTextures(GossipFrameGreetingPanel) end

    if QuestNpcNameFrame then
        pcall(function() QuestNpcNameFrame:SetBackdrop(nil) end)
        pcall(function() QuestNpcNameFrame:SetBackdropColor(0,0,0,0) end)
        ZeroTextures(QuestNpcNameFrame)
    end

    for _, panelName in ipairs({
        "QuestFrameDetailPanel", "QuestFrameRewardPanel",
        "QuestFrameProgressPanel", "QuestFrameGreetingPanel",
    }) do
        local p = _G[panelName]
        if p then
            ZeroTextures(p)
            local ok, n = pcall(function() return p:GetNumChildren() end)
            if ok and n then
                for i = 1, n do
                    local child = select(i, p:GetChildren())
                    if child and child:GetObjectType() ~= "Button" then
                        ZeroTextures(child)
                        local ok2, n2 = pcall(function() return child:GetNumChildren() end)
                        if ok2 and n2 then
                            for j = 1, n2 do
                                local grand = select(j, child:GetChildren())
                                if grand and grand:GetObjectType() ~= "Button" then
                                    ZeroTextures(grand)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
--  POSITION VANILLA FRAME
-- ============================================================

local function PositionVanillaFrame(frame)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", FQFInnerFrame, "CENTER", 0, 0)
    frame:SetWidth(QUEST_W)
    frame:SetHeight(QUEST_H)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(50)
end

-- ============================================================
--  QUEST INTERNALS
-- ============================================================

local questSized = false

local function ResizeQuestInternals()
    if questSized then return end
    questSized = true

    for _, panelName in ipairs({
        "QuestFrameDetailPanel", "QuestFrameRewardPanel",
        "QuestFrameProgressPanel", "QuestFrameGreetingPanel",
    }) do
        local panel = _G[panelName]
        if panel then
            panel:SetWidth(QUEST_W)
            panel:SetHeight(QUEST_H)
            panel:SetFrameLevel(51)
            local ok, n = pcall(function() return panel:GetNumChildren() end)
            if ok and n then
                for i = 1, n do
                    local child = select(i, panel:GetChildren())
                    if child then
                        local name = child:GetName() or ""
                        if name:find("Scroll") and not name:find("Bar") then
                            child:ClearAllPoints()
                            child:SetPoint("TOPLEFT",     panel, "TOPLEFT",     10, -70)
                            -- Bottom boundary raised to +90 so reward items
                            -- don't bleed into the button zone
                            child:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 90)
                        end
                    end
                end
            end
        end
    end

    local function MoveBtn(name, point, relPoint, x, y)
        local b = _G[name]
        if b then
            b:ClearAllPoints()
            b:SetPoint(point, QuestFrame, relPoint, x, y)
        end
    end
    MoveBtn("QuestFrameAcceptButton",   "BOTTOMLEFT",  "BOTTOMLEFT",   20,  10)
    MoveBtn("QuestFrameDeclineButton",  "BOTTOMRIGHT", "BOTTOMRIGHT", -20,  10)
    -- Nudged down to -5 to clear reward item overlap
    MoveBtn("QuestFrameCompleteButton", "BOTTOMLEFT",  "BOTTOMLEFT",   20,  -5)
    MoveBtn("QuestFrameGoodbyeButton",  "BOTTOMRIGHT", "BOTTOMRIGHT", -20,  10)
    MoveBtn("QuestFrameCancelButton",   "BOTTOMRIGHT", "BOTTOMRIGHT", -20,  10)
end

-- ============================================================
--  GOSSIP INTERNALS
-- ============================================================

local gossipSized = false

local function ResizeGossipInternals()
    if gossipSized then return end
    gossipSized = true

    if GossipFrameGreetingPanel then
        GossipFrameGreetingPanel:SetWidth(QUEST_W)
        GossipFrameGreetingPanel:SetHeight(QUEST_H)
        GossipFrameGreetingPanel:SetFrameLevel(51)
        local ok, n = pcall(function() return GossipFrameGreetingPanel:GetNumChildren() end)
        if ok and n then
            for i = 1, n do
                local child = select(i, GossipFrameGreetingPanel:GetChildren())
                if child then
                    local name = child:GetName() or ""
                    if name:find("Goodbye") then
                        child:ClearAllPoints()
                        child:SetPoint("BOTTOMRIGHT", GossipFrame, "BOTTOMRIGHT", -20, 10)
                    end
                end
            end
        end
    end

    if GossipGreetingScrollFrame then
        GossipGreetingScrollFrame:ClearAllPoints()
        GossipGreetingScrollFrame:SetPoint("TOPLEFT",     GossipFrame, "TOPLEFT",     10, -70)
        GossipGreetingScrollFrame:SetPoint("BOTTOMRIGHT", GossipFrame, "BOTTOMRIGHT", -26, 70)
    end
end

-- ============================================================
--  SHOW / HIDE
-- ============================================================

local outerTex
local innerTex

local function ShowFQF(vanillaFrame, targetType, isGossip)
    -- Flush any in-flight animation timers before potentially re-running
    -- SetupModels. Gossip option clicks re-fire GOSSIP_SHOW on the same NPC,
    -- which would stack new timers on top of old ones and cause animation chaos.
    for i = #timers, 1, -1 do table.remove(timers, i) end

    FQFInnerFrame:SetSize(INNER_W, INNER_H)

    if not outerTex then
        outerTex = FQFParchmentFrame:CreateTexture(nil, "BACKGROUND")
        outerTex:SetAllPoints(FQFParchmentFrame)
    end
    outerTex:SetTexture(GetFactionBG())

    if not innerTex then
        innerTex = FQFInnerFrame:CreateTexture(nil, "BACKGROUND")
        innerTex:SetAllPoints(FQFInnerFrame)
        innerTex:SetTexture(ART .. "ParchmentBG.tga")
    end

    -- Only set up models on a fresh open. If the frame is already visible the
    -- player is clicking through gossip options with the same NPC — no need to
    -- reload models or restart the conversation loop.
    local alreadyVisible = FQFFrame:IsShown()

    FQFFrame:Show()
    BanishFrames()

    if not alreadyVisible then
        SetupModels(targetType)
    end

    StripVanillaChrome()
    PositionVanillaFrame(vanillaFrame)

    if isGossip then
        ResizeGossipInternals()
    else
        ResizeQuestInternals()
    end
end

local function HideFQF()
    FQFFrame:Hide()
    ClearModels()
    RestoreFrames()
end

-- ============================================================
--  OPTIONS PANEL
-- ============================================================

-- Pending values held while the panel is open; committed only on Okay
local pending = {}
local optPanel = nil

-- Builds a row of selection buttons and preview box for one background slot.
local function CreateBGSlot(parent, yOffset, labelText, configKey)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    lbl:SetText(labelText)

    -- Preview box
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(128, 64)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 390, yOffset - 4)
    box:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0, 0, 0, 1)
    local prevTex = box:CreateTexture(nil, "ARTWORK")
    prevTex:SetPoint("TOPLEFT",     box, "TOPLEFT",     2, -2)
    prevTex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2,  2)

    local buttons = {}

    local function UpdateButtons()
        local currentKey = pending[configKey] or GetCfg(configKey)
        for _, btn in ipairs(buttons) do
            if btn.texKey == currentKey then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
        prevTex:SetTexture(ResolveTexture(currentKey))
    end

    for i, t in ipairs(CUSTOM_TEXTURES) do
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(110, 22)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * 118, yOffset - 22)
        btn:SetText(t.label)
        btn.texKey = t.key
        btn:SetScript("OnClick", function()
            pending[configKey] = t.key
            UpdateButtons()
        end)
        table.insert(buttons, btn)
    end

    local slot = {}
    slot.Refresh = UpdateButtons
    UpdateButtons()
    return slot
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "FQFOptionsPanel", UIParent)
    panel.name  = "Frostfire Quest Frames"

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("Frostfire Quest Frames")

    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    ver:SetText("v0.2d  |  by MikeFirestrike")
    ver:SetTextColor(.6, .6, .6)

    -- Divider line (SetColorTexture doesn't exist in 3.3.5a; use client separator)
    local div = panel:CreateTexture(nil, "ARTWORK")
    div:SetHeight(16)
    div:SetPoint("TOPLEFT",  ver, "BOTTOMLEFT",  0, -6)
    div:SetPoint("TOPRIGHT", panel, "TOPRIGHT",  -16, 0)
    div:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")

    -- Section header
    local secHdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secHdr:SetPoint("TOPLEFT", div, "BOTTOMLEFT", 0, -12)
    secHdr:SetText("Faction Backgrounds")
    secHdr:SetTextColor(1, .82, 0)

    local secDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secDesc:SetPoint("TOPLEFT", secHdr, "BOTTOMLEFT", 0, -4)
    secDesc:SetText("Choose the background texture shown for each faction. Changes take effect on the next NPC interaction.")
    secDesc:SetTextColor(.75, .75, .75)

    -- Three background slots
    local ddH = CreateBGSlot(panel, -130, "Horde",            "bgHorde")
    local ddA = CreateBGSlot(panel, -200, "Alliance",         "bgAlliance")
    local ddN = CreateBGSlot(panel, -270, "Neutral / Unknown","bgNeutral")

    -- Blizzard panel callbacks.
    -- Clear pending in-place (not by replacing the table) so dropdown
    -- closures that captured the original reference stay in sync.
    local function ClearPending()
        for k in pairs(pending) do pending[k] = nil end
    end

    panel.okay = function()
        for k, v in pairs(pending) do
            SetCfg(k, v)
        end
        ClearPending()
        -- outerTex:SetTexture is called fresh every ShowFQF so no reset needed
    end

    panel.cancel = function()
        ClearPending()
        ddH:Refresh()
        ddA:Refresh()
        ddN:Refresh()
    end

    panel.refresh = function()
        ClearPending()
        ddH:Refresh()
        ddA:Refresh()
        ddN:Refresh()
    end

    InterfaceOptions_AddCategory(panel)
    optPanel = panel
end

-- ============================================================
--  EVENTS
-- ============================================================

local listener = CreateFrame("Frame")
listener:RegisterEvent("GOSSIP_SHOW")
listener:RegisterEvent("GOSSIP_CLOSED")
listener:RegisterEvent("QUEST_GREETING")
listener:RegisterEvent("QUEST_DETAIL")
listener:RegisterEvent("QUEST_PROGRESS")
listener:RegisterEvent("QUEST_COMPLETE")
listener:RegisterEvent("QUEST_FINISHED")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")

listener:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        ForceGossip = function() return true end
        -- Fill any missing keys with defaults
        for k, v in pairs(DEFAULTS) do
            if FQFConfig[k] == nil then FQFConfig[k] = v end
        end
        if not optPanel then CreateOptionsPanel() end
    elseif event == "GOSSIP_SHOW" then
        ShowFQF(GossipFrame, "npc", true)
    elseif event == "GOSSIP_CLOSED" then
        HideFQF()
    elseif event == "QUEST_GREETING" or event == "QUEST_DETAIL"
        or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        ShowFQF(QuestFrame, "npc", false)
    elseif event == "QUEST_FINISHED" then
        HideFQF()
    end
end)

-- ============================================================
--  SLASH
-- ============================================================

SLASH_FROSTFIREQF1 = "/ffqf"
SlashCmdList["FROSTFIREQF"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "hide" then
        HideFQF()
        Print("Hidden.")
    elseif msg == "config" then
        InterfaceOptionsFrame_OpenToCategory(optPanel)
    elseif msg == "reset" then
        questSized = false; gossipSized = false; vanillaStripped = false
        Print("Flags cleared.")
    elseif msg == "animdebug" then
        local pRace = UnitRace("player") or "?"
        local pSex  = UnitSex("player") or "?"
        local tType = UnitCreatureType("target") or "?"
        local npcModelRaw = FQFModelNPC:GetModel()
        local npcModel = (type(npcModelRaw) == "string") and npcModelRaw or "?"
        Print(string.format("Player: %s sex=%s fallback=%s",
            pRace, pSex, tostring(UnitNeedsAnimFallback("player"))))
        Print(string.format("Target: type=%s model=%s", tType, npcModel))
        Print(string.format("NPC safe fallback: %s", tostring(ModelNeedsAnimFallback(FQFModelNPC))))
        local profile = GetNPCProfile()
        if profile then
            Print(string.format("Profile: scale=%.2f y=%.2f", profile.scale, profile.y))
        else
            Print("Profile: nil (object mode — NPC model hidden)")
        end
    else
        Print("/ffqf hide | config | reset | animdebug")
    end
end
