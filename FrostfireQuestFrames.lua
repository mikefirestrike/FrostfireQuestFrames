-- FrostfireQuestFrames.lua
-- v2.1

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[FQF]|r " .. tostring(msg))
end

local _, _, screenWidth, screenHeight = WorldFrame:GetBoundsRect()

-- ============================================================
--  FACTION BACKGROUND
-- ============================================================

local ART = "Interface\\AddOns\\FrostfireQuestFrames\\Art\\"

local function GetFactionBG()
    local npcFaction = UnitFactionGroup("target")
    if npcFaction == "Horde" then return ART .. "horde.tga" end
    if npcFaction == "Alliance" then return ART .. "alliance.tga" end
    if not npcFaction or npcFaction == "Neutral" or npcFaction == "" then
        return ART .. "other.tga"
    end
    local playerFaction = UnitFactionGroup("player")
    if playerFaction == "Horde" then return ART .. "horde.tga" end
    if playerFaction == "Alliance" then return ART .. "alliance.tga" end
    return ART .. "other.tga"
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
--  MODELS
-- ============================================================

-- Animation durations matched to actual animation length
-- so SetSequenceTime stops exactly when the animation ends
local ANIMS = {
    NPC    = { {60, 3.0}, {60, 3.0}, {64, 2.5}, {209, 2.8}, {60, 3.5} },
    PLAYER = { {65, 2.8}, {185, 2.2}, {186, 2.0}, {113, 2.5}, {67, 2.3} },
}

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
            -- sequence 0 immediately exits OnUpdate, letting engine take over
            playAnim(model, 0, 0)
        end
    end, duration)
end

local function SetupModels(targetType)
    FQFModelPlayer:SetLight(1, 0, 0, -1, -1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    FQFModelPlayer:SetCamera(1)
    FQFModelPlayer:SetFacing(.75)
    FQFModelPlayer:SetUnit("player", false)
    FQFModelPlayer:SetPosition(0, 0, 0)
    FQFModelPlayer:SetScale(1.0)

    FQFModelNPC:SetLight(1, 0, 0, 1, 1, 1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    FQFModelNPC:SetCamera(1)
    FQFModelNPC:SetFacing(-.75)
    FQFModelNPC:SetUnit(targetType or "target", false)
    FQFModelNPC:SetPosition(0, 0, 0)
    FQFModelNPC:SetScale(1.0)

    -- schedule conversation - NPC speaks, player responds, repeat
    local t = 0.4
    for i = 1, 5 do
        local npcAnim    = ANIMS.NPC[math.random(#ANIMS.NPC)]
        local playerAnim = ANIMS.PLAYER[math.random(#ANIMS.PLAYER)]
        local nt = t
        local pt = t + npcAnim[2] + 0.2
        DelayCall(function() playAndStand(FQFModelNPC,    npcAnim[1],    npcAnim[2])    end, nt)
        DelayCall(function() playAndStand(FQFModelPlayer, playerAnim[1], playerAnim[2]) end, pt)
        t = pt + playerAnim[2] + 0.2
    end
end

local function ClearModels()
    for i = #timers, 1, -1 do table.remove(timers, i) end
    pcall(function() FQFModelPlayer:ClearModel() end)
    pcall(function() FQFModelNPC:ClearModel() end)
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
                            child:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 70)
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
    MoveBtn("QuestFrameAcceptButton",   "BOTTOMLEFT",  "BOTTOMLEFT",   20, 10)
    MoveBtn("QuestFrameDeclineButton",  "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 10)
    MoveBtn("QuestFrameCompleteButton", "BOTTOMLEFT",  "BOTTOMLEFT",   20, 10)
    MoveBtn("QuestFrameGoodbyeButton",  "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 10)
    MoveBtn("QuestFrameCancelButton",   "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 10)
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

    FQFFrame:Show()
    BanishFrames()
    SetupModels(targetType)
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
        -- force gossip to always show so single-option NPCs don't skip our frame
        ForceGossip = function() return true end
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
        HideFQF(); Print("Hidden.")
    elseif msg == "reset" then
        questSized = false; gossipSized = false; vanillaStripped = false
        Print("Flags cleared.")
    else
        Print("/ffqf hide | reset")
    end
end
