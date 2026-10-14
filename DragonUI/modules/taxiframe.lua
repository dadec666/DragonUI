-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local SetPortraitTexture = SetPortraitTexture
local TaxiNodeName = TaxiNodeName

local TaxiFrameModule = {
    initialized = false,
    applied = false,
}

local isRu = (GetLocale and GetLocale() == "ruRU")
if addon.L then
    if rawget(addon.L, "Flight Map") == nil then
        rawset(addon.L, "Flight Map", isRu and "Карта полетов" or "Flight Map")
    end
    if rawget(addon.L, "Retail-style flight master map window") == nil then
        rawset(addon.L, "Retail-style flight master map window",
            isRu and "Окно карты распорядителя полетов в стиле Retail" or "Retail-style flight master map window")
    end
end

if addon.defaults and addon.defaults.profile and addon.defaults.profile.modules then
    if addon.defaults.profile.modules.taxiframe == nil then
        addon.defaults.profile.modules.taxiframe = { enabled = true }
    end
end
if addon.db and addon.db.profile and addon.db.profile.modules then
    if addon.db.profile.modules.taxiframe == nil then
        addon.db.profile.modules.taxiframe = { enabled = true }
    end
end

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("taxiframe", TaxiFrameModule,
        localized("Flight Map"),
        localized("Retail-style flight master map window"),
        { lifecyclePrefix = "TaxiFrame", loadOnce = true })
end

local WIDTH, HEIGHT = 338, 424
local MAP_X, MAP_Y = 11, -64
local MAP_W, MAP_H = 316, 352
local PANEL_X_NUDGE = 6
local REDBUTTON = addon._dir .. "UI\\redbutton2x"

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("taxiframe")
    end
    return true
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice or _G.NineSliceUtils
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if layout and slicer.ApplyLayout then
        slicer.ApplyLayout(host, layout)
    end
end

local function setAtlas(tex, name)
    if not tex then return end
    if tex.SetAtlasTexture then
        tex:SetAtlasTexture(name)
    elseif tex.set_atlas then
        tex:set_atlas(name)
    end
end

local function nudgePanel(window)
    if not window.SetAttribute then return end
    if window:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    window:SetAttribute("UIPanelLayout-xoffset", PANEL_X_NUDGE)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

local function dressCloseButton(cb, owner)
    if not cb or cb._duiModernized then return end
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(cb, owner)
        return
    end
    cb._duiModernized = true
    cb:SetSize(24, 24)
    cb:ClearAllPoints()
    cb:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 1, 0)

    local function dress(getter, l, r, t, b, blend)
        local tex = cb[getter] and cb[getter](cb)
        if not tex then return end
        tex:SetTexture(REDBUTTON)
        tex:SetTexCoord(l, r, t, b)
        if blend then tex:SetBlendMode(blend) end
    end

    dress("GetNormalTexture", 39/256, 75/256, 1/128, 39/128)
    dress("GetPushedTexture", 39/256, 75/256, 81/128, 119/128)
    dress("GetDisabledTexture", 39/256, 75/256, 41/128, 79/128)
    dress("GetHighlightTexture", 115/256, 151/256, 1/128, 39/128, "ADD")
end

local function hideStockRegions(frame)
    local portrait = _G.TaxiPortrait
    local title = _G.TaxiMerchant
    local map = _G.TaxiMap
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= portrait and region ~= title and region ~= map
            and not region._duiOwned and region.GetObjectType
            and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function buildTaxiFrame()
    local frame = _G.TaxiFrame
    if not frame or frame._duiSkinned then return end
    frame._duiSkinned = true

    hideStockRegions(frame)

    frame:SetSize(WIDTH, HEIGHT)
    if frame.SetHitRectInsets then
        frame:SetHitRectInsets(0, 0, 0, 0)
    end
    nudgePanel(frame)

    local rock = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    rock._duiOwned = true
    rock:SetTexture(addon._dir .. "UI\\ui-background-rock", "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame._duiRockBg = rock

    local streaks = frame:CreateTexture(nil, "BORDER")
    streaks._duiOwned = true
    setAtlas(streaks, "_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -21)
    streaks:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2, -64)
    frame._duiStreaks = streaks

    applySlices(frame, "PortraitFrameTemplate")

    local portrait = _G.TaxiPortrait
    if portrait then
        portrait._duiOwned = true
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 4)
        portrait:SetSize(56, 56)
        portrait:SetDrawLayer("ARTWORK")
    end

    local title = _G.TaxiMerchant
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -5)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -5)
        title:SetHeight(16)
        title:SetJustifyH("CENTER")
        title:SetWordWrap(false)
        title:SetTextColor(1, 0.82, 0)
    end

    if _G.TaxiCloseButton then
        dressCloseButton(_G.TaxiCloseButton, frame)
    end

    -- Move TaxiMap and TaxiRouteMap together so flight nodes and route lines stay aligned.
    local taxiMap = _G.TaxiMap
    if taxiMap then
        taxiMap._duiOwned = true
        taxiMap:ClearAllPoints()
        taxiMap:SetPoint("TOPLEFT", frame, "TOPLEFT", MAP_X, MAP_Y)
        taxiMap:SetSize(MAP_W, MAP_H)
    end

    local routeMap = _G.TaxiRouteMap
    if routeMap then
        routeMap:ClearAllPoints()
        if taxiMap then
            routeMap:SetAllPoints(taxiMap)
        else
            routeMap:SetPoint("TOPLEFT", frame, "TOPLEFT", MAP_X, MAP_Y)
            routeMap:SetSize(MAP_W, MAP_H)
        end
    end

    local inset = CreateFrame("Frame", nil, frame)
    inset:EnableMouse(false)
    if taxiMap then
        inset:SetPoint("TOPLEFT", taxiMap, "TOPLEFT", -3, 3)
        inset:SetPoint("BOTTOMRIGHT", taxiMap, "BOTTOMRIGHT", 3, -3)
    else
        inset:SetPoint("TOPLEFT", frame, "TOPLEFT", MAP_X - 3, MAP_Y + 3)
        inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 5)
    end
    inset:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
    applySlices(inset, "InsetFrameTemplate")
    frame._duiInset = inset

    frame:HookScript("OnShow", function()
        if not IsModuleEnabled() then return end
        if portrait and SetPortraitTexture then
            SetPortraitTexture(portrait, "npc")
        end
        if title and (not title:GetText() or title:GetText() == "") then
            title:SetText(UnitName("npc") or localized("Flight Map"))
        end
    end)
end

function addon.ApplyTaxiFrameSystem()
    if not IsModuleEnabled() then return end
    TaxiFrameModule.initialized = true
    TaxiFrameModule.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("taxiframe_apply", buildTaxiFrame)
        return
    end
    buildTaxiFrame()
end

function addon.RestoreTaxiFrameSystem()
    TaxiFrameModule.applied = false
end

function addon.RefreshTaxiFrameSystem()
    if IsModuleEnabled() then
        addon.ApplyTaxiFrameSystem()
    else
        addon.RestoreTaxiFrameSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("TAXIMAP_OPENED")
boot:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplyTaxiFrameSystem()
    elseif event == "TAXIMAP_OPENED" then
        buildTaxiFrame()
    end
end)
