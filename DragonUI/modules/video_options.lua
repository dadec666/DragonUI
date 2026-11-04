-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addonName, addon = ...
local L = addon.L
local FUI = addon.ForeverUI
local Atlas = addon.ForeverAtlas

local VideoOptionsModule = {
    initialized = false,
    applied = false,
    frame = nil,
    activeTab = "game",
    activeCategory = nil,
    activePanel = nil,
    customPanels = {},
    categoryButtons = {},
    groupHeaders = {},
    collapsedState = {},
}
addon.VideoOptionsModule = VideoOptionsModule

local WINDOW_WIDTH      = 960
local WINDOW_HEIGHT     = 700
local WINDOW_MIN_WIDTH  = 800
local WINDOW_MIN_HEIGHT = 520
local WINDOW_MAX_WIDTH  = 1400
local WINDOW_MAX_HEIGHT = 900

local LIST_WIDTH        = 210
local LIST_GAP          = 14
local LIST_MARGIN_TOP   = 8
local LIST_HEADER_H     = 28
local ROW_HEIGHT        = 24
local GROUP_GAP         = 8

local function GetModuleConfig()
    return addon:GetModuleConfig("video_options")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("video_options")
end

local function SafeGetCVar(cvar, defaultVal)
    local v = GetCVar and GetCVar(cvar)
    if v == nil then return defaultVal end
    return v
end

local function SafeSetCVar(cvar, value)
    if not cvar or value == nil then return end
    if GetCVar(cvar) ~= nil then
        pcall(SetCVar, cvar, tostring(value))
    end
end

local function SafeRestartGx()
    if RestartGx then
        pcall(RestartGx)
    end
end

local function SafeL(key)
    if not L or not key then return nil end
    local val = rawget(L, key)
    if val ~= nil then return val end
    local AceLocale = LibStub and LibStub("AceLocale-3.0-DragonUI", true)
    if AceLocale and AceLocale.apps and AceLocale.apps["DragonUI"] then
        local app = AceLocale.apps["DragonUI"]
        local gameLocale = (GetLocale and GetLocale()) or "enUS"
        local curTbl = rawget(app, gameLocale)
        if curTbl and rawget(curTbl, key) ~= nil then return rawget(curTbl, key) end
        local defTbl = rawget(app, "enUS")
        if defTbl and rawget(defTbl, key) ~= nil then return rawget(defTbl, key) end
    end
    return nil
end

local function Text(globalKey, fallbackText)
    if globalKey and _G[globalKey] and type(_G[globalKey]) == "string" and _G[globalKey] ~= "" then
        return _G[globalKey]
    end
    local loc = SafeL(fallbackText)
    if loc and type(loc) == "string" and loc ~= "" then
        return loc
    end
    return fallbackText or ""
end

-- ============================================================================
-- NATIVE BLIZZARD CONTROLS RESKINNING
-- ============================================================================

local function SkinNativePanel(panel)
    if not panel or panel._dragonUISkinned then return end
    panel._dragonUISkinned = true

    local panelName = panel:GetName()
    if panelName then
        local title = _G[panelName .. "Title"]
        if title then title:Hide() end
        local subText = _G[panelName .. "SubText"]
        if subText then
            subText:ClearAllPoints()
            subText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -4)
            subText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -4)
            subText:SetTextColor(0.8, 0.8, 0.8, 1)
        end
    end

    local function SkinElement(child)
        if not child then return end
        local objType = child.GetObjectType and child:GetObjectType()

        if objType == "CheckButton" then
            if FUI and FUI.SkinCheckButton then
                pcall(FUI.SkinCheckButton, child)
            end
            local text = _G[child:GetName() and (child:GetName() .. "Text")] or child.text
            if text and text.SetTextColor then
                text:SetTextColor(0.9, 0.9, 0.9, 1)
            end
        elseif objType == "Slider" then
            if FUI and FUI.SkinSlider then
                pcall(FUI.SkinSlider, child)
            end
        elseif objType == "ScrollFrame" then
            if FUI and FUI.SkinScrollBar then
                pcall(FUI.SkinScrollBar, child)
            end
        elseif objType == "Frame" and child:GetName() and child:GetName():find("DropDown") then
            local btn = _G[child:GetName() .. "Button"]
            if btn and FUI and FUI.SkinDropdownButton then
                pcall(FUI.SkinDropdownButton, btn)
            end
        end

        local children = { child:GetChildren() }
        for _, sub in ipairs(children) do
            SkinElement(sub)
        end
    end

    local children = { panel:GetChildren() }
    for _, child in ipairs(children) do
        SkinElement(child)
    end
end

-- ============================================================================
-- GRAPHICS PANEL BUILDER
-- ============================================================================

local function BuildGraphicsPanel(parent)
    local scroll = CreateFrame("ScrollFrame", "DragonUI_GraphicsScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scroll:SetAllPoints(parent)
    if FUI and FUI.SkinScrollBar then
        pcall(FUI.SkinScrollBar, scroll)
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(parent:GetWidth() - 40, 1300)
    scroll:SetScrollChild(content)

    local yOffset = 10

    local function AddHeader(title)
        local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        h:SetText("|cffFFD100" .. title .. "|r")
        yOffset = yOffset + 28
    end

    local function AddCheckbox(label, getFunc, setFunc)
        local cb = FUI.CreateCheckbox(content, label, function(self, val)
            setFunc(val)
        end, { width = 400 })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        cb:SetChecked(getFunc())
        yOffset = yOffset + 28
        return cb
    end

    local function AddSlider(label, minVal, maxVal, step, getFunc, setFunc, fmt)
        local sl = FUI.CreateSlider(content, {
            label = label,
            min = minVal,
            max = maxVal,
            step = step,
            width = 380,
            get = getFunc,
            set = setFunc,
            format = fmt,
        })
        sl:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        yOffset = yOffset + 38
        return sl
    end

    local function AddDropdown(label, values, order, getFunc, setFunc)
        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        lbl:SetText(label)
        yOffset = yOffset + 18

        local dd = FUI.CreateDropdown(content, {
            width = 240,
            builder = function(self)
                local items = {}
                local keys = order or {}
                if #keys == 0 then
                    for k in pairs(values) do keys[#keys + 1] = k end
                    table.sort(keys)
                end
                for _, k in ipairs(keys) do
                    local v = values[k]
                    items[#items + 1] = {
                        text = v,
                        value = k,
                        func = function()
                            setFunc(k)
                            self:SetText(v)
                        end,
                    }
                end
                return items
            end,
        })
        dd:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        local curVal = getFunc()
        dd:SetText(values[curVal] or tostring(curVal))
        yOffset = yOffset + 36
        return dd
    end

    -- Display
    AddHeader(Text("DISPLAY_HEADER", "Display"))

    -- Resolution Dropdown
    if GetScreenResolutions and GetCurrentResolution and SetScreenResolution then
        local resValues = {}
        local resOrder = {}
        local numRes = select("#", GetScreenResolutions())
        for i = 1, numRes do
            local res = select(i, GetScreenResolutions())
            resValues[i] = res
            resOrder[#resOrder + 1] = i
        end
        if #resOrder > 0 then
            AddDropdown(Text("RESOLUTION", "Resolution"), resValues, resOrder, function()
                return GetCurrentResolution() or 1
            end, function(val)
                SetScreenResolution(val)
                SafeRestartGx()
            end)
        end
    end

    AddDropdown(Text("DISPLAY_MODE", "Display Mode"), {
        [1] = Text("VIDEO_OPTIONS_FULLSCREEN", "Fullscreen"),
        [2] = Text("VIDEO_OPTIONS_WINDOWED", "Windowed"),
        [3] = Text("VIDEO_OPTIONS_WINDOWED_FULLSCREEN", "Fullscreen (Windowed)"),
    }, { 1, 2, 3 }, function()
        local win = SafeGetCVar("gxWindow", "0") == "1"
        local max = SafeGetCVar("gxMaximize", "0") == "1"
        if win and max then return 3
        elseif win then return 2
        else return 1 end
    end, function(val)
        if val == 3 then
            SafeSetCVar("gxWindow", "1")
            SafeSetCVar("gxMaximize", "1")
        elseif val == 2 then
            SafeSetCVar("gxWindow", "1")
            SafeSetCVar("gxMaximize", "0")
        else
            SafeSetCVar("gxWindow", "0")
            SafeSetCVar("gxMaximize", "0")
        end
        SafeRestartGx()
    end)

    AddCheckbox(Text("VERTICAL_SYNC", "Vertical Sync"), function()
        return SafeGetCVar("gxVSync") == "1"
    end, function(val)
        SafeSetCVar("gxVSync", val and "1" or "0")
        SafeRestartGx()
    end)

    AddCheckbox(Text("TRIPLE_BUFFER", "Triple Buffering"), function()
        return SafeGetCVar("gxTripleBuffer") == "1"
    end, function(val)
        SafeSetCVar("gxTripleBuffer", val and "1" or "0")
        SafeRestartGx()
    end)

    AddCheckbox(Text("HARDWARE_CURSOR", "Hardware Cursor"), function()
        return SafeGetCVar("gxCursor") == "1"
    end, function(val)
        SafeSetCVar("gxCursor", val and "1" or "0")
        SafeRestartGx()
    end)

    AddCheckbox(Text("REDUCE_INPUT_LAG", "Reduce Input Lag"), function()
        return SafeGetCVar("gxFixLag", "1") == "1"
    end, function(val)
        SafeSetCVar("gxFixLag", val and "1" or "0")
        SafeRestartGx()
    end)

    yOffset = yOffset + 10

    -- Quality
    AddHeader(Text("GRAPHICS_QUALITY", "Graphics Quality"))

    -- Texture Resolution
    AddDropdown(Text("TEXTURE_DETAIL", "Texture Resolution"), {
        [0] = Text("VIDEO_OPTIONS_HIGH", "High"),
        [1] = Text("VIDEO_OPTIONS_FAIR", "Fair"),
        [2] = Text("VIDEO_OPTIONS_LOW", "Low"),
    }, { 0, 1, 2 }, function()
        return tonumber(SafeGetCVar("baseMip", "0")) or 0
    end, function(val)
        SafeSetCVar("baseMip", val)
        SafeRestartGx()
    end)

    AddDropdown(Text("MULTISAMPLE", "Anti-Aliasing"), {
        [1] = "1x (" .. Text("VIDEO_OPTIONS_OFF", "Off") .. ")",
        [2] = "2x",
        [4] = "4x",
        [8] = "8x",
    }, { 1, 2, 4, 8 }, function()
        return tonumber(SafeGetCVar("gxMultisample", "1")) or 1
    end, function(val)
        SafeSetCVar("gxMultisample", val)
        SafeRestartGx()
    end)

    local anisoText = Text("ANISOTROPIC", "Texture Filtering")
    AddDropdown(anisoText, {
        [1] = Text("BILINEAR", "Bilinear"),
        [2] = Text("TRILINEAR", "Trilinear"),
        [3] = "2x " .. anisoText,
        [4] = "4x " .. anisoText,
        [5] = "8x " .. anisoText,
        [6] = "16x " .. anisoText,
    }, { 1, 2, 3, 4, 5, 6 }, function()
        return tonumber(SafeGetCVar("textureFilteringMode", "1")) or 1
    end, function(val)
        SafeSetCVar("textureFilteringMode", val)
        SafeRestartGx()
    end)

    AddCheckbox(Text("PROJECTED_TEXTURES", "Projected Textures"), function()
        return SafeGetCVar("projectedTextures", "1") == "1"
    end, function(val)
        SafeSetCVar("projectedTextures", val and "1" or "0")
    end)

    AddDropdown(Text("SHADOW_QUALITY", "Shadow Quality"), {
        [0] = Text("VIDEO_OPTIONS_OFF", "Off"),
        [1] = Text("VIDEO_OPTIONS_LOW", "Low"),
        [2] = Text("VIDEO_OPTIONS_FAIR", "Fair"),
        [3] = Text("VIDEO_OPTIONS_HIGH", "High"),
        [4] = Text("VIDEO_OPTIONS_ULTRA", "Ultra"),
    }, { 0, 1, 2, 3, 4 }, function()
        return tonumber(SafeGetCVar("extShadowQuality", nil)) or tonumber(SafeGetCVar("shadowMode", "0")) or 0
    end, function(val)
        SafeSetCVar("extShadowQuality", val)
        SafeSetCVar("shadowMode", val)
    end)

    AddDropdown(Text("LIQUID_DETAIL", "Liquid Detail"), {
        [0] = Text("VIDEO_OPTIONS_LOW", "Low"),
        [1] = Text("VIDEO_OPTIONS_FAIR", "Fair"),
        [2] = Text("VIDEO_OPTIONS_HIGH", "High"),
        [3] = Text("VIDEO_OPTIONS_ULTRA", "Ultra"),
    }, { 0, 1, 2, 3 }, function()
        return tonumber(SafeGetCVar("waterDetail", "1")) or 1
    end, function(val)
        SafeSetCVar("waterDetail", val)
    end)

    AddDropdown(Text("WEATHER_DETAIL", "Weather Density"), {
        [0] = Text("VIDEO_OPTIONS_OFF", "Off"),
        [1] = Text("VIDEO_OPTIONS_LOW", "Low"),
        [2] = Text("VIDEO_OPTIONS_FAIR", "Medium"),
        [3] = Text("VIDEO_OPTIONS_HIGH", "High"),
    }, { 0, 1, 2, 3 }, function()
        return tonumber(SafeGetCVar("weatherDensity", "2")) or 2
    end, function(val)
        SafeSetCVar("weatherDensity", val)
    end)

    AddSlider(Text("PARTICLE_DENSITY", "Particle Density"), 0.1, 1.0, 0.1, function()
        return tonumber(SafeGetCVar("particleDensity", "1.0")) or 1.0
    end, function(val)
        SafeSetCVar("particleDensity", val)
    end)

    AddCheckbox(Text(nil, "Fullscreen Glow"), function()
        return SafeGetCVar("ffxGlow", "1") == "1"
    end, function(val)
        SafeSetCVar("ffxGlow", val and "1" or "0")
    end)

    AddCheckbox(Text(nil, "Death Effect"), function()
        return SafeGetCVar("ffxDeath", "1") == "1"
    end, function(val)
        SafeSetCVar("ffxDeath", val and "1" or "0")
    end)

    yOffset = yOffset + 10

    -- Advanced Graphics
    AddHeader(Text("ADVANCED_LABEL", "Advanced Graphics"))

    AddSlider(Text("FARCLIP", "View Distance"), 177, 1600, 50, function()
        return tonumber(SafeGetCVar("farclip", "777")) or 777
    end, function(val)
        SafeSetCVar("farclip", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.farclip = val end
    end)

    AddSlider(Text(nil, "Horizon Farclip Scale"), 1.0, 6.0, 0.5, function()
        return tonumber(SafeGetCVar("horizonFarclipScale", "4.0")) or 4.0
    end, function(val)
        SafeSetCVar("horizonFarclipScale", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.horizonFarclipScale = val end
    end)

    AddSlider(Text("ENVIRONMENT_DETAIL", "Environment Detail"), 0.5, 1.5, 0.1, function()
        return tonumber(SafeGetCVar("environmentDetail", "1.0")) or 1.0
    end, function(val)
        SafeSetCVar("environmentDetail", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.environmentDetail = val end
    end)

    AddSlider(Text("GROUND_EFFECT_DIST", "Ground Effect Distance"), 40, 140, 10, function()
        return tonumber(SafeGetCVar("groundEffectDist", "70")) or 70
    end, function(val)
        SafeSetCVar("groundEffectDist", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.groundEffectDist = val end
    end)

    AddSlider(Text("GROUND_CLUTTER", "Ground Effect Density"), 16, 256, 16, function()
        return tonumber(SafeGetCVar("groundEffectDensity", "64")) or 64
    end, function(val)
        SafeSetCVar("groundEffectDensity", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.groundEffectDensity = val end
    end)

    AddSlider(Text(nil, "Max Camera Distance Factor"), 1.0, 4.0, 0.2, function()
        return tonumber(SafeGetCVar("cameraDistanceMaxFactor", "1.0")) or 1.0
    end, function(val)
        SafeSetCVar("cameraDistanceMaxFactor", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.cameraMaxFactor = val end
    end)

    AddSlider(Text(nil, "Max Foreground FPS"), 0, 200, 5, function()
        return tonumber(SafeGetCVar("maxFPS", "0")) or 0
    end, function(val)
        SafeSetCVar("maxFPS", val)
    end)

    AddSlider(Text(nil, "Max Background FPS"), 10, 60, 5, function()
        return tonumber(SafeGetCVar("maxFPSBk", "30")) or 30
    end, function(val)
        SafeSetCVar("maxFPSBk", val)
    end)

    content:SetHeight(math.max(yOffset + 40, 1100))
    return scroll
end

-- ============================================================================
-- AUDIO PANEL BUILDER
-- ============================================================================

local function BuildAudioPanel(parent)
    local scroll = CreateFrame("ScrollFrame", "DragonUI_AudioScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scroll:SetAllPoints(parent)
    if FUI and FUI.SkinScrollBar then
        pcall(FUI.SkinScrollBar, scroll)
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(parent:GetWidth() - 40, 750)
    scroll:SetScrollChild(content)

    local yOffset = 10

    local function AddHeader(title)
        local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        h:SetText("|cffFFD100" .. title .. "|r")
        yOffset = yOffset + 28
    end

    local function AddCheckbox(label, getFunc, setFunc)
        local cb = FUI.CreateCheckbox(content, label, function(self, val)
            setFunc(val)
        end, { width = 400 })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        cb:SetChecked(getFunc())
        yOffset = yOffset + 28
        return cb
    end

    local function AddSlider(label, minVal, maxVal, step, getFunc, setFunc)
        local sl = FUI.CreateSlider(content, {
            label = label,
            min = minVal,
            max = maxVal,
            step = step,
            width = 380,
            get = getFunc,
            set = setFunc,
        })
        sl:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        yOffset = yOffset + 38
        return sl
    end

    AddHeader(Text("VOLUME", "Volume"))

    AddCheckbox(Text("ENABLE_SOUND", "Enable Sound"), function()
        return SafeGetCVar("Sound_EnableAllSound") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableAllSound", val and "1" or "0")
    end)

    AddCheckbox(Text("SOUND_EFFECTS", "Sound Effects"), function()
        return SafeGetCVar("Sound_EnableSFX") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableSFX", val and "1" or "0")
    end)

    AddCheckbox(Text("ENABLE_MUSIC", "Music"), function()
        return SafeGetCVar("Sound_EnableMusic") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableMusic", val and "1" or "0")
    end)

    AddCheckbox(Text("ENABLE_AMBIENCE", "Ambience"), function()
        return SafeGetCVar("Sound_EnableAmbience") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableAmbience", val and "1" or "0")
    end)

    AddCheckbox(Text("ENABLE_BGSOUND", "Sound in Background"), function()
        return (SafeGetCVar("Sound_EnableSoundWhenGameIsInBG", nil) or SafeGetCVar("Sound_EnableSoundWhenBackgrounded", "0")) == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableSoundWhenGameIsInBG", val and "1" or "0")
        SafeSetCVar("Sound_EnableSoundWhenBackgrounded", val and "1" or "0")
    end)

    AddSlider(Text("MASTER_VOLUME", "Master Volume"), 0, 1, 0.05, function()
        return tonumber(SafeGetCVar("Sound_MasterVolume", "1")) or 1.0
    end, function(val)
        SafeSetCVar("Sound_MasterVolume", val)
    end)

    AddSlider(Text("SOUND_VOLUME", "Sound Effects Volume"), 0, 1, 0.05, function()
        return tonumber(SafeGetCVar("Sound_SFXVolume", "0.8")) or 0.8
    end, function(val)
        SafeSetCVar("Sound_SFXVolume", val)
    end)

    AddSlider(Text("MUSIC_VOLUME", "Music Volume"), 0, 1, 0.05, function()
        return tonumber(SafeGetCVar("Sound_MusicVolume", "0.5")) or 0.5
    end, function(val)
        SafeSetCVar("Sound_MusicVolume", val)
    end)

    AddSlider(Text("AMBIENCE_VOLUME", "Ambience Volume"), 0, 1, 0.05, function()
        return tonumber(SafeGetCVar("Sound_AmbienceVolume", "0.6")) or 0.6
    end, function(val)
        SafeSetCVar("Sound_AmbienceVolume", val)
    end)

    yOffset = yOffset + 10
    AddHeader(Text("PLAYBACK", "Playback"))

    AddSlider(Text("SOUND_CHANNELS", "Sound Channels"), 16, 128, 16, function()
        return tonumber(SafeGetCVar("Sound_NumChannels", "32")) or 32
    end, function(val)
        SafeSetCVar("Sound_NumChannels", val)
        local cfg = GetModuleConfig()
        if cfg then cfg.soundChannels = val end
    end)

    AddCheckbox(Text("HARDWARE", "Hardware Acceleration"), function()
        return SafeGetCVar("Sound_EnableHardware") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableHardware", val and "1" or "0")
    end)

    AddCheckbox(Text("SOFTWARE_HRTF", "Software HRTF"), function()
        return SafeGetCVar("Sound_EnableSoftwareHRTF") == "1"
    end, function(val)
        SafeSetCVar("Sound_EnableSoftwareHRTF", val and "1" or "0")
        local cfg = GetModuleConfig()
        if cfg then cfg.enableHRTF = val and true or false end
    end)

    content:SetHeight(math.max(yOffset + 30, 650))
    return scroll
end

-- ============================================================================
-- KEYBINDINGS PANEL BUILDER
-- ============================================================================

local function BuildKeybindingsPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)

    local charCheck = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    charCheck:SetSize(20, 20)
    charCheck:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -4)
    if FUI and FUI.SkinCheckButton then
        pcall(FUI.SkinCheckButton, charCheck)
    end
    local checkText = charCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    checkText:SetPoint("LEFT", charCheck, "RIGHT", 6, 1)
    checkText:SetText(Text("CHARACTER_SPECIFIC_KEYBINDINGS", "Character Specific Keybindings"))
    charCheck:SetChecked(GetCurrentBindingSet and GetCurrentBindingSet() == 2)
    charCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            LoadBindings(2)
            SaveBindings(2)
        else
            LoadBindings(1)
            SaveBindings(1)
        end
        if container.RefreshBindings then
            container.RefreshBindings()
        end
    end)

    local catDropdown = CreateFrame("Frame", "DragonUI_VideoKeybindCatDropdown", container, "UIDropDownMenuTemplate")
    catDropdown:SetPoint("TOPLEFT", charCheck, "BOTTOMLEFT", -16, -6)
    UIDropDownMenu_SetWidth(catDropdown, 220)

    local scroll = CreateFrame("ScrollFrame", "DragonUI_VideoKeybindScroll", container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", catDropdown, "BOTTOMLEFT", 20, -6)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -26, 10)
    if FUI and FUI.SkinScrollBar then
        pcall(FUI.SkinScrollBar, scroll)
    end

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(container:GetWidth() - 60, 500)
    scroll:SetScrollChild(scrollChild)

    local rows = {}
    local selectedCategoryIndex = 1
    local listeningButton = nil

    local function CollectCategories()
        local list = {}
        local current = nil
        local num = GetNumBindings()
        for i = 1, num do
            local command, key1, key2 = GetBinding(i)
            if command then
                if string.sub(command, 1, 6) == "HEADER" then
                    local headerKey = string.sub(command, 8)
                    local headerText = _G["BINDING_HEADER_" .. headerKey] 
                        or _G["BINDING_" .. command] 
                        or _G[command] 
                        or headerKey
                    current = { name = headerText, raw = headerKey, bindings = {} }
                    list[#list + 1] = current
                elseif current then
                    local label = _G["BINDING_NAME_" .. command] or command
                    current.bindings[#current.bindings + 1] = {
                        command = command,
                        label = label,
                        key1 = key1,
                        key2 = key2,
                    }
                end
            end
        end
        return list
    end

    local categoriesData = CollectCategories()

    local keyListener = CreateFrame("Button", nil, container)
    keyListener:SetFrameStrata("DIALOG")
    keyListener:EnableMouse(true)
    keyListener:EnableKeyboard(true)
    keyListener:Hide()

    local function StopListening()
        keyListener:Hide()
        if listeningButton then
            local origText = listeningButton._origText or Text("NOT_BOUND", "Not Bound")
            listeningButton:SetText(origText)
            listeningButton = nil
        end
    end

    keyListener:SetScript("OnKeyDown", function(self, key)
        if not listeningButton then StopListening(); return end
        if key == "ESCAPE" then
            StopListening()
            return
        end
        local cmd = listeningButton.command
        local slot = listeningButton.slot
        if cmd then
            local oldKey1, oldKey2 = GetBindingKey(cmd)
            if slot == 1 then
                if oldKey1 then SetBinding(oldKey1) end
            elseif slot == 2 then
                if oldKey2 then SetBinding(oldKey2) end
            end
            SetBinding(key, cmd)
            SaveBindings(GetCurrentBindingSet())
        end
        StopListening()
        if container.RefreshBindings then
            container.RefreshBindings()
        end
    end)

    keyListener:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            StopListening()
        end
    end)

    local function StartListening(btn, cmd, slot)
        listeningButton = btn
        btn._origText = btn:GetText()
        btn:SetText("|cffffff00" .. Text("PRESS_KEY", "Press a key...") .. "|r")
        keyListener:Show()
    end

    local function UpdateRows()
        local data = categoriesData[selectedCategoryIndex]
        local bindings = data and data.bindings or {}
        local yOffset = 0
        local rowH = 26

        for i, item in ipairs(bindings) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(scrollChild:GetWidth() or 500, rowH)

                local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                lbl:SetJustifyH("LEFT")
                lbl:SetPoint("LEFT", row, "LEFT", 10, 0)
                lbl:SetPoint("RIGHT", row, "LEFT", 280, 0)
                row.label = lbl

                local b1 = FUI.CreateButton(row, "", 120, 22)
                b1:SetPoint("LEFT", row, "LEFT", 290, 0)
                row.btn1 = b1

                local b2 = FUI.CreateButton(row, "", 120, 22)
                b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
                row.btn2 = b2

                local unbind = FUI.CreateButton(row, "X", 24, 22)
                unbind:SetPoint("LEFT", b2, "RIGHT", 6, 0)
                row.unbind = unbind

                rows[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)

            row.label:SetText(item.label)

            local k1, k2 = GetBindingKey(item.command)
            row.btn1:SetText(k1 or ("|cff808080" .. Text("NOT_BOUND", "Not Bound") .. "|r"))
            row.btn1.command = item.command
            row.btn1.slot = 1
            row.btn1:SetScript("OnClick", function(self) StartListening(self, item.command, 1) end)

            row.btn2:SetText(k2 or ("|cff808080" .. Text("NOT_BOUND", "Not Bound") .. "|r"))
            row.btn2.command = item.command
            row.btn2.slot = 2
            row.btn2:SetScript("OnClick", function(self) StartListening(self, item.command, 2) end)

            row.unbind:SetScript("OnClick", function()
                local old1, old2 = GetBindingKey(item.command)
                if old1 then SetBinding(old1) end
                if old2 then SetBinding(old2) end
                SaveBindings(GetCurrentBindingSet())
                if container.RefreshBindings then container.RefreshBindings() end
            end)

            row:Show()
            yOffset = yOffset + rowH + 2
        end

        for j = #bindings + 1, #rows do
            rows[j]:Hide()
        end

        scrollChild:SetHeight(math.max(yOffset + 20, 300))
    end

    container.RefreshBindings = function()
        categoriesData = CollectCategories()
        UpdateRows()
    end

    local function InitDropdown()
        local info = UIDropDownMenu_CreateInfo()
        for idx, cat in ipairs(categoriesData) do
            info.text = cat.name
            info.value = idx
            info.func = function(self)
                selectedCategoryIndex = self.value
                UIDropDownMenu_SetSelectedValue(catDropdown, self.value)
                UIDropDownMenu_SetText(catDropdown, cat.name)
                UpdateRows()
            end
            info.checked = (idx == selectedCategoryIndex)
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(catDropdown, InitDropdown)
    if #categoriesData > 0 then
        UIDropDownMenu_SetSelectedValue(catDropdown, 1)
        UIDropDownMenu_SetText(catDropdown, categoriesData[1].name)
    end

    UpdateRows()
    return container
end

-- ============================================================================
-- GAME CATEGORY RESOLUTION (3.3.5a NATIVE PANELS + CUSTOM)
-- ============================================================================

local function GetGameplayCategories()
    local cats = {}
    local seen = {}

    local nativeList = InterfaceOptionsFrameCategories or {}
    for _, p in ipairs(nativeList) do
        if p and p.name and not seen[p] then
            seen[p] = true
            local displayName = p.name
            if p == InterfaceOptionsDisplayPanel or p:GetName() == "InterfaceOptionsDisplayPanel" then
                displayName = Text("DISPLAY", "Display")
            end
            cats[#cats + 1] = {
                id = p:GetName() or p.name,
                name = displayName,
                panel = p,
                parent = p.parent,
            }
        end
    end

    if #cats == 0 then
        local fallbackList = {
            { id = "InterfaceOptionsControlsPanel",   name = Text("CONTROLS_LABEL", "Controls"), panelName = "InterfaceOptionsControlsPanel" },
            { id = "InterfaceOptionsCombatPanel",     name = Text("COMBAT_LABEL", "Combat"), panelName = "InterfaceOptionsCombatPanel" },
            { id = "InterfaceOptionsDisplayPanel",    name = Text("DISPLAY", "Display"), panelName = "InterfaceOptionsDisplayPanel" },
            { id = "InterfaceOptionsObjectivesPanel", name = Text("OBJECTIVES_LABEL", "Quests"), panelName = "InterfaceOptionsObjectivesPanel" },
            { id = "InterfaceOptionsSocialPanel",     name = Text("SOCIAL_LABEL", "Social"), panelName = "InterfaceOptionsSocialPanel" },
            { id = "InterfaceOptionsActionBarsPanel", name = Text("ACTIONBARS_LABEL", "Action Bars"), panelName = "InterfaceOptionsActionBarsPanel" },
            { id = "InterfaceOptionsNamesPanel",      name = Text("NAMES_LABEL", "Names"), panelName = "InterfaceOptionsNamesPanel" },
            { id = "InterfaceOptionsCombatTextPanel", name = Text("COMBAT_TEXT_LABEL", "Combat Text"), panelName = "InterfaceOptionsCombatTextPanel" },
            { id = "InterfaceOptionsStatusTextPanel", name = Text("STATUS_TEXT_LABEL", "Status Text"), panelName = "InterfaceOptionsStatusTextPanel" },
            { id = "InterfaceOptionsUnitFramePanel",  name = Text("UNITFRAMES_LABEL", "Unit Frames"), panelName = "InterfaceOptionsUnitFramePanel" },
            { id = "InterfaceOptionsBuffsPanel",      name = Text("BUFFS_LABEL", "Buffs & Debuffs"), panelName = "InterfaceOptionsBuffsPanel" },
            { id = "InterfaceOptionsCameraPanel",     name = Text("CAMERA_LABEL", "Camera"), panelName = "InterfaceOptionsCameraPanel" },
            { id = "InterfaceOptionsMousePanel",      name = Text("MOUSE_LABEL", "Mouse"), panelName = "InterfaceOptionsMousePanel" },
            { id = "InterfaceOptionsHelpPanel",       name = Text("HELP_LABEL", "Help"), panelName = "InterfaceOptionsHelpPanel" },
        }
        for _, item in ipairs(fallbackList) do
            if _G[item.panelName] then
                item.panel = _G[item.panelName]
                cats[#cats + 1] = item
            end
        end
    end

    cats[#cats + 1] = {
        id = "keybindings",
        name = Text("KEY_BINDINGS", "Keybindings"),
        custom = "keybindings",
    }

    return cats
end

-- ============================================================================
-- MAIN WINDOW CREATION
-- ============================================================================

local function CreateWindow()
    if VideoOptionsModule.frame then return VideoOptionsModule.frame end

    local f = FUI.CreateWindow("DragonUI_GameMenuOptions", UIParent, {
        width    = WINDOW_WIDTH,
        height   = WINDOW_HEIGHT,
        title    = Text("OPTIONS", "Options"),
        inset    = true,
        strata   = "DIALOG",
        movable  = true,
        escClose = true,
        onClose  = function() VideoOptionsModule:Close() end,
    })
    f:SetPoint("CENTER")
    FUI.SetResizeBounds(f, WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT, WINDOW_MAX_WIDTH, WINDOW_MAX_HEIGHT)
    VideoOptionsModule.frame = f

    -- Top Tabs: [ Game ] [ AddOns ]
    local gameTab = FUI.CreateTab(f)
    gameTab:SetTabText(Text("GAME", "Game"))
    gameTab:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -32)
    gameTab:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        VideoOptionsModule:SelectTab("game")
    end)
    f.gameTab = gameTab

    local addonsTab = FUI.CreateTab(f)
    addonsTab:SetTabText(Text("ADDONS", "AddOns"))
    addonsTab:SetPoint("LEFT", gameTab, "RIGHT", 4, 0)
    addonsTab:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        VideoOptionsModule:SelectTab("addons")
    end)
    f.addonsTab = addonsTab

    -- Top Search Box
    local searchBox = CreateFrame("EditBox", nil, f)
    searchBox:SetSize(190, 22)
    searchBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, -32)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    searchBox:SetTextInsets(22, 20, 0, 0)

    local searchBg = searchBox:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetTexture("Interface\\Common\\Common-Input-Border")

    local hint = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", searchBox, "LEFT", 22, 0)
    hint:SetText(Text("SEARCH", "Search..."))
    searchBox.hint = hint

    searchBox:SetScript("OnTextChanged", function(self)
        local q = self:GetText()
        if q and q ~= "" then
            hint:Hide()
        else
            hint:Show()
        end
        VideoOptionsModule:FilterCategories(q)
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    f.searchBox = searchBox

    local inset = f.Inset

    -- Left Category Sidebar (SCROLLABLE)
    local listScroll = CreateFrame("ScrollFrame", "DragonUI_GameMenuCatScroll", inset, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 2, -LIST_MARGIN_TOP)
    listScroll:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 2, 8)
    listScroll:SetWidth(LIST_WIDTH)
    if FUI and FUI.SkinScrollBar then
        pcall(FUI.SkinScrollBar, listScroll)
    end

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(LIST_WIDTH - 24, 800)
    listScroll:SetScrollChild(listContent)
    f.categoryList = listContent
    f.categoryScroll = listScroll

    -- Right Content Area
    local content = CreateFrame("Frame", nil, inset)
    content:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", LIST_GAP, 0)
    content:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)
    f.content = content

    local headerTitle = content:CreateFontString(nil, "ARTWORK")
    headerTitle:SetFontObject(FUI.Fonts.HighlightHuge)
    headerTitle:SetJustifyH("LEFT")
    headerTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -18)
    headerTitle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -18)
    f.headerTitle = headerTitle

    local divider = FUI.CreateDivider(content)
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -44)
    divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -44)
    divider:SetHeight(1)

    local panelHost = CreateFrame("Frame", nil, content)
    panelHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -46)
    panelHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    f.panelHost = panelHost

    -- Footer Buttons
    local closeBtn = FUI.CreateButton(f, Text("CLOSE", "Close"), 100, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
    closeBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuClose")
        VideoOptionsModule:Close()
    end)
    f.closeBtn = closeBtn

    local okayBtn = FUI.CreateButton(f, Text("OKAY", "Okay"), 100, 22)
    okayBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    okayBtn:SetScript("OnClick", function()
        VideoOptionsModule:SaveAll()
        PlaySound("igMainMenuClose")
        VideoOptionsModule:Close()
    end)
    f.okayBtn = okayBtn

    local defaultBtn = FUI.CreateButton(f, Text("DEFAULTS", "Defaults"), 110, 22)
    defaultBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 14)
    defaultBtn:SetScript("OnClick", function()
        VideoOptionsModule:ResetCurrentDefault()
    end)
    f.defaultBtn = defaultBtn

    FUI.AddResizeGrip(f, function() end)

    return f
end

-- ============================================================================
-- CATEGORY LIST RENDERING (TREE + EXPAND/COLLAPSE + SCROLL)
-- ============================================================================

local function BuildTree(items)
    local roots = {}
    local byName = {}

    for _, it in ipairs(items) do
        local key = it.name or (it.panel and it.panel.name) or it.id
        byName[key] = it
        it.children = {}
    end

    for _, it in ipairs(items) do
        local parentKey = it.parent or (it.panel and it.panel.parent)
        if parentKey and byName[parentKey] then
            local parent = byName[parentKey]
            parent.hasChildren = true
            parent.children[#parent.children + 1] = it
            it.parentItem = parent
        else
            roots[#roots + 1] = it
        end
    end

    return roots
end

function VideoOptionsModule:BuildCategoryButtons()
    local f = self.frame
    if not f then return end

    for _, btn in ipairs(self.categoryButtons) do
        btn:Hide()
        if btn.toggleBtn then btn.toggleBtn:Hide() end
    end
    for _, hdr in ipairs(self.groupHeaders) do
        hdr:Hide()
    end

    local btnIndex = 0
    local hdrIndex = 0
    local yOffset = 0

    local function GetButton()
        btnIndex = btnIndex + 1
        local btn = self.categoryButtons[btnIndex]
        if not btn then
            btn = FUI.CreateCategoryButton(f.categoryList)
            local toggle = CreateFrame("Button", nil, btn)
            toggle:SetSize(16, 16)
            toggle:SetPoint("LEFT", btn, "LEFT", 2, 0)
            local tText = toggle:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            tText:SetPoint("CENTER")
            toggle.text = tText
            btn.toggleBtn = toggle
            self.categoryButtons[btnIndex] = btn
        end
        return btn
    end

    local function GetHeader()
        hdrIndex = hdrIndex + 1
        local hdr = self.groupHeaders[hdrIndex]
        if not hdr then
            hdr = FUI.CreateCategoryHeader(f.categoryList)
            self.groupHeaders[hdrIndex] = hdr
        end
        return hdr
    end

    local query = self.frame.searchBox and self.frame.searchBox:GetText()
    query = query and query:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

    local function RenderItem(item, indent)
        local btn = GetButton()
        btn:SetPoint("TOPLEFT", f.categoryList, "TOPLEFT", 4, -yOffset)
        btn:SetText(item.name or "Unknown")
        btn:SetIndent(indent + (item.hasChildren and 16 or 0))
        btn.catData = item
        btn:SetSelected(self.activeCategory and (self.activeCategory.id == item.id or (item.panel and self.activeCategory.panel == item.panel)))

        btn:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            VideoOptionsModule:SelectCategory(item)
        end)

        if item.hasChildren then
            local isCollapsed = (self.collapsedState[item.id or item.name] == true)
            if query ~= "" then isCollapsed = false end
            btn.toggleBtn:SetPoint("LEFT", btn, "LEFT", indent + 2, 0)
            btn.toggleBtn.text:SetText(isCollapsed and "|cffFFD100+|r" or "|cffFFD100-|r")
            btn.toggleBtn:SetScript("OnClick", function()
                VideoOptionsModule.collapsedState[item.id or item.name] = not isCollapsed
                VideoOptionsModule:BuildCategoryButtons()
            end)
            btn.toggleBtn:Show()
        else
            btn.toggleBtn:Hide()
        end

        btn:Show()
        yOffset = yOffset + ROW_HEIGHT + 2

        if item.hasChildren and (self.collapsedState[item.id or item.name] ~= true or query ~= "") then
            for _, child in ipairs(item.children) do
                if query == "" or (child.name and child.name:lower():find(query, 1, true)) or (item.name and item.name:lower():find(query, 1, true)) then
                    RenderItem(child, indent + 16)
                end
            end
        end
    end

    if self.activeTab == "game" then
        local gameplayCats = GetGameplayCategories()
        local tree = BuildTree(gameplayCats)

        local hdr1 = GetHeader()
        hdr1:SetPoint("TOPLEFT", f.categoryList, "TOPLEFT", 0, -yOffset)
        hdr1:SetIndex(1)
        hdr1:SetLabel(Text("GAMEPLAY", "Gameplay"))
        hdr1:Show()
        yOffset = yOffset + LIST_HEADER_H + 4

        for _, root in ipairs(tree) do
            if query == "" or (root.name and root.name:lower():find(query, 1, true)) then
                RenderItem(root, 0)
            end
        end

        yOffset = yOffset + GROUP_GAP

        local hdr2 = GetHeader()
        hdr2:SetPoint("TOPLEFT", f.categoryList, "TOPLEFT", 0, -yOffset)
        hdr2:SetIndex(2)
        hdr2:SetLabel(Text("SYSTEM", "System"))
        hdr2:Show()
        yOffset = yOffset + LIST_HEADER_H + 4

        local systemCats = {
            { id = "graphics", name = Text("GRAPHICS_LABEL", "Graphics"), custom = "graphics" },
            { id = "audio",    name = Text("SOUND_LABEL", "Audio"),       custom = "audio" },
        }
        for _, sysCat in ipairs(systemCats) do
            if query == "" or (sysCat.name and sysCat.name:lower():find(query, 1, true)) then
                RenderItem(sysCat, 0)
            end
        end

    else
        -- AddOns Tab
        local rawAddons = INTERFACEOPTIONS_ADDONCATEGORIES or {}
        local addonItems = {}
        for i, p in ipairs(rawAddons) do
            local name = p.name or (p.GetName and p:GetName()) or ("AddOn " .. i)
            addonItems[#addonItems + 1] = {
                id = "addon_" .. i,
                name = name,
                panel = p,
                parent = p.parent,
            }
        end

        local tree = BuildTree(addonItems)
        local count = 0

        for _, root in ipairs(tree) do
            if query == "" or (root.name and root.name:lower():find(query, 1, true)) then
                count = count + 1
                RenderItem(root, 0)
            end
        end

        if count == 0 then
            local hdr = GetHeader()
            hdr:SetPoint("TOPLEFT", f.categoryList, "TOPLEFT", 0, -yOffset)
            hdr:SetIndex(1)
            hdr:SetLabel(Text("ADDONS", "AddOns"))
            hdr:Show()
            yOffset = yOffset + LIST_HEADER_H + 4

            local btn = GetButton()
            btn:SetPoint("TOPLEFT", f.categoryList, "TOPLEFT", 4, -yOffset)
            btn:SetText("|cff808080" .. Text("NONE", "None") .. "|r")
            btn:SetIndent(0)
            btn.catData = nil
            btn:SetSelected(false)
            btn:SetScript("OnClick", nil)
            btn.toggleBtn:Hide()
            btn:Show()
            yOffset = yOffset + ROW_HEIGHT + 2
        end
    end

    f.categoryList:SetHeight(math.max(yOffset + 20, f.categoryScroll:GetHeight() or 500))
end

function VideoOptionsModule:FilterCategories(query)
    self:BuildCategoryButtons()
end

-- ============================================================================
-- CATEGORY / PANEL SELECTION
-- ============================================================================

function VideoOptionsModule:SelectCategory(cat)
    if not cat then return end
    self.activeCategory = cat

    if self.activePanel then
        self.activePanel:Hide()
        self.activePanel = nil
    end

    self.frame.headerTitle:SetText(cat.name or "")

    for _, btn in ipairs(self.categoryButtons) do
        if btn:IsShown() and btn.catData then
            btn:SetSelected(btn.catData.id == cat.id or (cat.panel and btn.catData.panel == cat.panel))
        end
    end

    local panelHost = self.frame.panelHost

    if cat.custom == "graphics" then
        if not self.customPanels.graphics then
            self.customPanels.graphics = BuildGraphicsPanel(panelHost)
        end
        self.activePanel = self.customPanels.graphics
        self.activePanel:Show()
    elseif cat.custom == "audio" then
        if not self.customPanels.audio then
            self.customPanels.audio = BuildAudioPanel(panelHost)
        end
        self.activePanel = self.customPanels.audio
        self.activePanel:Show()
    elseif cat.custom == "keybindings" then
        if not self.customPanels.keybindings then
            self.customPanels.keybindings = BuildKeybindingsPanel(panelHost)
        end
        self.activePanel = self.customPanels.keybindings
        self.activePanel:Show()
        if self.customPanels.keybindings.RefreshBindings then
            self.customPanels.keybindings.RefreshBindings()
        end
    else
        local p = cat.panel or (cat.panelName and _G[cat.panelName])
        if p then
            p:SetParent(panelHost)
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", panelHost, "TOPLEFT", 8, -6)
            p:SetPoint("BOTTOMRIGHT", panelHost, "BOTTOMRIGHT", -8, 6)
            SkinNativePanel(p)
            if p.refresh then pcall(p.refresh, p) end
            p:Show()
            self.activePanel = p
        end
    end
end

function VideoOptionsModule:SelectTab(tabKey)
    self.activeTab = tabKey or "game"
    local f = self.frame
    if not f then return end

    f.gameTab:SetSelected(self.activeTab == "game")
    f.addonsTab:SetSelected(self.activeTab == "addons")

    self:BuildCategoryButtons()

    if self.activeTab == "game" then
        local gameplayCats = GetGameplayCategories()
        if gameplayCats[1] then
            self:SelectCategory(gameplayCats[1])
        end
    else
        local rawAddons = INTERFACEOPTIONS_ADDONCATEGORIES or {}
        if rawAddons[1] then
            self:SelectCategory({ id = "addon_1", name = rawAddons[1].name, panel = rawAddons[1] })
        else
            f.headerTitle:SetText(Text("ADDONS", "AddOns"))
            if self.activePanel then self.activePanel:Hide(); self.activePanel = nil end
        end
    end
end

function VideoOptionsModule:ResetCurrentDefault()
    if self.activePanel and self.activePanel.default then
        pcall(self.activePanel.default, self.activePanel)
    elseif self.activeCategory and self.activeCategory.custom == "graphics" then
        if VideoOptionsFrame_SetDefaults then pcall(VideoOptionsFrame_SetDefaults) end
        self:SelectCategory(self.activeCategory)
    elseif self.activeCategory and self.activeCategory.custom == "audio" then
        if AudioOptionsFrame_SetDefaults then pcall(AudioOptionsFrame_SetDefaults) end
        self:SelectCategory(self.activeCategory)
    elseif self.activeCategory and self.activeCategory.custom == "keybindings" then
        DefaultBindings()
        SaveBindings(GetCurrentBindingSet())
        if self.customPanels.keybindings and self.customPanels.keybindings.RefreshBindings then
            self.customPanels.keybindings.RefreshBindings()
        end
    end
end

function VideoOptionsModule:SaveAll()
    local addons = INTERFACEOPTIONS_ADDONCATEGORIES or {}
    for _, p in ipairs(addons) do
        if p.okay then pcall(p.okay, p) end
    end
    local nativeList = InterfaceOptionsFrameCategories or {}
    for _, p in ipairs(nativeList) do
        if p.okay then pcall(p.okay, p) end
    end
    if SaveBindings and GetCurrentBindingSet then
        pcall(SaveBindings, GetCurrentBindingSet())
    end
end

function VideoOptionsModule:Open(tabOrCat, specificCat)
    local f = CreateWindow()
    f:Show()

    if tabOrCat == "addons" then
        self:SelectTab("addons")
        if specificCat then
            local addons = INTERFACEOPTIONS_ADDONCATEGORIES or {}
            for i, p in ipairs(addons) do
                if (p.name and p.name == specificCat) or p == specificCat then
                    self:SelectCategory({ id = "addon_" .. i, name = p.name, panel = p })
                    break
                end
            end
        end
    else
        self:SelectTab("game")
        local target = specificCat or tabOrCat or "controls"
        local gameplayCats = GetGameplayCategories()
        for _, cat in ipairs(gameplayCats) do
            if cat.id == target or (cat.panel and cat.panel:GetName() == target) then
                self:SelectCategory(cat)
                return
            end
        end
        if target == "graphics" then
            self:SelectCategory({ id = "graphics", name = Text("GRAPHICS_LABEL", "Graphics"), custom = "graphics" })
        elseif target == "audio" then
            self:SelectCategory({ id = "audio", name = Text("SOUND_LABEL", "Audio"), custom = "audio" })
        elseif target == "keybindings" then
            self:SelectCategory({ id = "keybindings", name = Text("KEY_BINDINGS", "Keybindings"), custom = "keybindings" })
        end
    end
end

function VideoOptionsModule:Close()
    if self.frame then
        self.frame:Hide()
    end
end

function VideoOptionsModule:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Close()
    else
        self:Open()
    end
end

-- ============================================================================
-- HOOKS & LIFECYCLE
-- ============================================================================

local function HookOptionFrames()
    if VideoOptionsFrame and not VideoOptionsFrame._dragonUIHooked then
        VideoOptionsFrame._dragonUIHooked = true
        VideoOptionsFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then HideUIPanel(self) else self:Hide() end
            VideoOptionsModule:Open("game", "graphics")
        end)
    end

    if AudioOptionsFrame and not AudioOptionsFrame._dragonUIHooked then
        AudioOptionsFrame._dragonUIHooked = true
        AudioOptionsFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then HideUIPanel(self) else self:Hide() end
            VideoOptionsModule:Open("game", "audio")
        end)
    end

    if InterfaceOptionsFrame and not InterfaceOptionsFrame._dragonUIHooked then
        InterfaceOptionsFrame._dragonUIHooked = true
        InterfaceOptionsFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then HideUIPanel(self) else self:Hide() end
            VideoOptionsModule:Open("game", "controls")
        end)
    end

    if KeyBindingFrame and not KeyBindingFrame._dragonUIHooked then
        KeyBindingFrame._dragonUIHooked = true
        KeyBindingFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then HideUIPanel(self) else self:Hide() end
            VideoOptionsModule:Open("game", "keybindings")
        end)
    end

    if GameMenuFrame and not GameMenuFrame._dragonUIHooked then
        GameMenuFrame._dragonUIHooked = true
        if GameMenuButtonOptions then
            GameMenuButtonOptions:HookScript("OnClick", function()
                if not IsModuleEnabled() then return end
                VideoOptionsModule:Open("game", "graphics")
            end)
        end
        if GameMenuButtonUIOptions then
            GameMenuButtonUIOptions:HookScript("OnClick", function()
                if not IsModuleEnabled() then return end
                VideoOptionsModule:Open("game", "controls")
            end)
        end
        if GameMenuButtonKeybindings then
            GameMenuButtonKeybindings:HookScript("OnClick", function()
                if not IsModuleEnabled() then return end
                VideoOptionsModule:Open("game", "keybindings")
            end)
        end
    end

    if InterfaceOptionsFrame_OpenToCategory and not addon._origOpenToCategory then
        addon._origOpenToCategory = InterfaceOptionsFrame_OpenToCategory
        InterfaceOptionsFrame_OpenToCategory = function(panel)
            if IsModuleEnabled() then
                VideoOptionsModule:Open("addons", type(panel) == "table" and panel.name or panel)
            else
                return addon._origOpenToCategory(panel)
            end
        end
    end
end

function VideoOptionsModule:ApplySettings()
    local cfg = GetModuleConfig()
    if not cfg then return end

    if cfg.farclip then
        SafeSetCVar("farclip", cfg.farclip)
    end
    if cfg.horizonFarclipScale then
        SafeSetCVar("horizonFarclipScale", cfg.horizonFarclipScale)
    elseif cfg.horizonFarclip then
        local scale = (type(cfg.horizonFarclip) == "number" and cfg.horizonFarclip > 10) and 4.0 or cfg.horizonFarclip
        SafeSetCVar("horizonFarclipScale", scale)
    end
    if cfg.groundEffectDist then
        SafeSetCVar("groundEffectDist", cfg.groundEffectDist)
    end
    if cfg.groundEffectDensity then
        SafeSetCVar("groundEffectDensity", cfg.groundEffectDensity)
    end
    if cfg.environmentDetail then
        SafeSetCVar("environmentDetail", cfg.environmentDetail)
    end
    if cfg.cameraMaxFactor then
        SafeSetCVar("cameraDistanceMaxFactor", cfg.cameraMaxFactor)
    end
    if cfg.soundChannels then
        SafeSetCVar("Sound_NumChannels", cfg.soundChannels)
    end
    if cfg.enableHRTF ~= nil then
        SafeSetCVar("Sound_EnableSoftwareHRTF", cfg.enableHRTF and "1" or "0")
    end
end

function VideoOptionsModule:OnInit()
    if self.initialized then return end
    self.initialized = true
    HookOptionFrames()
    if IsModuleEnabled() then
        self.applied = true
        self:ApplySettings()
    end
end

function VideoOptionsModule:OnEnable()
    self.applied = true
    HookOptionFrames()
    self:ApplySettings()
end

function VideoOptionsModule:OnDisable()
    self.applied = false
    self:Close()
end

VideoOptionsModule.Apply = VideoOptionsModule.OnEnable
VideoOptionsModule.Refresh = VideoOptionsModule.ApplySettings
VideoOptionsModule.Restore = VideoOptionsModule.OnDisable

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        VideoOptionsModule:OnInit()
    end
end)

if addon.RegisterModule then
    addon:RegisterModule("video_options", VideoOptionsModule,
        L["Video & Audio Options"] or "Video & Audio Options",
        L["Modern video and audio settings panel with unlocked graphics CVars."] or "Modern video and audio settings panel with unlocked graphics CVars.", {
        lifecyclePrefix = "VideoOptions",
        loadOnce = false,
    })
end
