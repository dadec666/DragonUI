-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local activeSubTab = "graphics"

function addon.SetSystemSubTab(key)
    activeSubTab = key or "graphics"
end

-- Safe localized string resolver:
-- 1. Checks Blizzard GlobalStrings in _G[globalKey]
-- 2. Safely falls back to LO[fallbackKey] via pcall (preventing AceLocale Missing entry errors)
-- 3. Falls back to literal string
local function Text(globalKey, fallbackKey, defaultText)
    if globalKey and _G[globalKey] and type(_G[globalKey]) == "string" and _G[globalKey] ~= "" then
        return _G[globalKey]
    end
    local key = fallbackKey or defaultText
    if key and LO then
        local ok, val = pcall(function() return LO[key] end)
        if ok and type(val) == "string" and val ~= "" then
            return val
        end
    end
    return defaultText or key or ""
end

local subTabs = {
    { key = "graphics", label = Text("GRAPHICS_LABEL", "Graphics", "Graphics") },
    { key = "audio",    label = Text("SOUND_LABEL", "Audio", "Audio") },
}

Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["system"] = function(key) activeSubTab = key or "graphics" end

local function EnsureModuleTable(moduleName)
    return C:EnsureModuleTable(moduleName)
end

local function GetModuleField(moduleName, field)
    local m = addon.db and addon.db.profile and addon.db.profile.modules
    return m and m[moduleName] and m[moduleName][field]
end

local function IsEnabled(moduleName)
    return GetModuleField(moduleName, "enabled") == true
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

-- ============================================================================
-- GRAPHICS SUB-TAB
-- ============================================================================

local function BuildGraphicsSubTab(scroll)
    local btnRow = C:AddRow(scroll)
    C:AddButton(btnRow, {
        label = Text("DEFAULTS", "Defaults", "Defaults"),
        desc = Text("OPTION_TOOLTIP_RESET_TO_DEFAULT", "Reset all graphics options to Blizzard defaults.", "Reset all graphics options to Blizzard defaults."),
        width = 120,
        callback = function()
            if VideoOptionsFrame_SetDefaults then
                pcall(VideoOptionsFrame_SetDefaults)
            end
            Panel:SelectTab("system")
        end,
    })

    -- Display Section
    local displaySection = C:AddSection(scroll, Text("DISPLAY_HEADER", "Display", "Display"))

    C:AddDropdown(displaySection, {
        label = Text("DISPLAY_MODE", "Display Mode", "Display Mode"),
        desc = Text("OPTION_TOOLTIP_DISPLAY_MODE", "Switch between Fullscreen, Windowed, and Fullscreen (Windowed) mode.", "Switch between Fullscreen, Windowed, and Fullscreen (Windowed) mode."),
        values = {
            [1] = Text("FULLSCREEN", "Fullscreen", "Fullscreen"),
            [2] = Text("VIDEO_OPTIONS_WINDOWED", "Windowed", "Windowed"),
            [3] = Text("WINDOWED_FULLSCREEN", "Fullscreen (Windowed)", "Fullscreen (Windowed)"),
        },
        getFunc = function()
            local win = SafeGetCVar("gxWindow", "0") == "1"
            local max = SafeGetCVar("gxMaximize", "0") == "1"
            if win and max then return 3
            elseif win then return 2
            else return 1 end
        end,
        setFunc = function(val)
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
        end,
        width = 220,
    })

    local resolutions = { GetScreenResolutions() }
    if #resolutions > 0 then
        local resValues = {}
        for i, res in ipairs(resolutions) do
            resValues[i] = res
        end
        C:AddDropdown(displaySection, {
            label = Text("RESOLUTION", "Resolution", "Resolution"),
            desc = Text("OPTION_TOOLTIP_RESOLUTION", "Screen resolution for fullscreen mode.", "Screen resolution for fullscreen mode."),
            values = resValues,
            getFunc = function()
                if GetCurrentResolution then
                    local cur = GetCurrentResolution()
                    if cur and cur > 0 then return cur end
                end
                local curRes = SafeGetCVar("gxResolution", "")
                for i, r in ipairs(resolutions) do
                    if r == curRes then return i end
                end
                return 1
            end,
            setFunc = function(val)
                if SetScreenResolution then
                    SetScreenResolution(val)
                elseif resValues[val] then
                    SafeSetCVar("gxResolution", resValues[val])
                end
                SafeRestartGx()
            end,
            width = 220,
        })
    end

    C:AddToggle(displaySection, {
        label = Text("VERTICAL_SYNC", "Vertical Sync (VSync)", "Vertical Sync (VSync)"),
        desc = Text("OPTION_TOOLTIP_VERTICAL_SYNC", "Synchronize frame rate with monitor refresh rate to prevent screen tearing.", "Synchronize frame rate with monitor refresh rate to prevent screen tearing."),
        getFunc = function() return SafeGetCVar("gxVSync") == "1" end,
        setFunc = function(val)
            SafeSetCVar("gxVSync", val and "1" or "0")
            SafeRestartGx()
        end,
    })

    C:AddToggle(displaySection, {
        label = Text("TRIPLE_BUFFER", "Triple Buffering", "Triple Buffering"),
        desc = Text("OPTION_TOOLTIP_TRIPLE_BUFFER", "Reduces frame rate stutter when VSync is enabled.", "Reduces frame rate stutter when VSync is enabled."),
        getFunc = function() return SafeGetCVar("gxTripleBuffer") == "1" end,
        setFunc = function(val)
            SafeSetCVar("gxTripleBuffer", val and "1" or "0")
            SafeRestartGx()
        end,
    })

    C:AddToggle(displaySection, {
        label = Text("REDUCE_INPUT_LAG", "Reduce Input Lag", "Reduce Input Lag"),
        desc = Text("OPTION_TOOLTIP_REDUCE_INPUT_LAG", "Reduces mouse latency at the expense of slight frame rate jitter.", "Reduces mouse latency at the expense of slight frame rate jitter."),
        getFunc = function() return SafeGetCVar("timingTestError") == "0" end,
        setFunc = function(val)
            SafeSetCVar("timingTestError", val and "0" or "1")
        end,
    })

    C:AddToggle(displaySection, {
        label = Text("HARDWARE_CURSOR", "Hardware Cursor", "Hardware Cursor"),
        desc = Text("OPTION_TOOLTIP_HARDWARE_CURSOR", "Use hardware cursor rendering to prevent mouse pointer stutter.", "Use hardware cursor rendering to prevent mouse pointer stutter."),
        getFunc = function() return SafeGetCVar("gxCursor") == "1" end,
        setFunc = function(val)
            SafeSetCVar("gxCursor", val and "1" or "0")
            SafeRestartGx()
        end,
    })

    C:AddToggle(displaySection, {
        label = Text("USE_UISCALE", "Use UI Scale", "Use UI Scale"),
        desc = Text("OPTION_TOOLTIP_USE_UISCALE", "Enable custom user interface scaling.", "Enable custom user interface scaling."),
        getFunc = function() return SafeGetCVar("useUiScale") == "1" end,
        setFunc = function(val)
            SafeSetCVar("useUiScale", val and "1" or "0")
            Panel:SelectTab("system")
        end,
    })

    C:AddSlider(displaySection, {
        label = Text("UI_SCALE", "UI Scale", "UI Scale"),
        desc = Text("OPTION_TOOLTIP_UI_SCALE", "Custom size of the user interface.", "Custom size of the user interface."),
        min = 0.64,
        max = 1.0,
        step = 0.01,
        default = 1.0,
        getFunc = function() return tonumber(SafeGetCVar("uiscale", "1")) or 1.0 end,
        setFunc = function(val) SafeSetCVar("uiscale", val) end,
        disabled = function() return SafeGetCVar("useUiScale") ~= "1" end,
        width = 220,
    })

    -- Quality & Textures Section
    local qualitySection = C:AddSection(scroll, Text("GRAPHICS_QUALITY", "Graphics Quality", "Graphics Quality"))

    local msFormats = { GetMultisampleFormats() }
    if #msFormats > 0 then
        local msValues = {}
        for i, fmt in ipairs(msFormats) do
            msValues[i] = tostring(fmt) .. "x"
        end
        C:AddDropdown(qualitySection, {
            label = Text("MULTISAMPLE", "Anti-Aliasing", "Anti-Aliasing"),
            desc = Text("OPTION_TOOLTIP_MULTISAMPLE", "Smooth jagged edges on polygons.", "Smooth jagged edges on polygons."),
            values = msValues,
            getFunc = function()
                if GetCurrentMultisampleFormat then
                    local cur = GetCurrentMultisampleFormat()
                    if cur and cur > 0 then return cur end
                end
                return 1
            end,
            setFunc = function(val)
                if SetMultisampleFormat then
                    SetMultisampleFormat(val)
                end
                SafeRestartGx()
            end,
            width = 220,
        })
    end

    C:AddDropdown(qualitySection, {
        label = Text("TEXTURE_DETAIL", "Texture Resolution", "Texture Resolution"),
        desc = Text("OPTION_TOOLTIP_TEXTURE_DETAIL", "Detail level of world and character surface textures.", "Detail level of world and character surface textures."),
        values = {
            [0] = Text("VIDEO_OPTIONS_HIGH", "High", "High"),
            [1] = Text("VIDEO_OPTIONS_FAIR", "Fair", "Fair"),
            [2] = Text("VIDEO_OPTIONS_LOW", "Low", "Low"),
        },
        getFunc = function() return tonumber(SafeGetCVar("baseMip", "0")) or 0 end,
        setFunc = function(val) SafeSetCVar("baseMip", val) end,
        width = 220,
    })

    local anisoText = Text("ANISOTROPIC", "Texture Filtering", "Texture Filtering")
    C:AddDropdown(qualitySection, {
        label = anisoText,
        desc = Text("OPTION_TOOLTIP_ANISOTROPIC", "Filtering quality applied to textures viewed at sharp angles.", "Filtering quality applied to textures viewed at sharp angles."),
        values = {
            [1] = Text("BILINEAR", "Bilinear", "Bilinear"),
            [2] = Text("TRILINEAR", "Trilinear", "Trilinear"),
            [3] = "2x " .. anisoText,
            [4] = "4x " .. anisoText,
            [5] = "8x " .. anisoText,
            [6] = "16x " .. anisoText,
        },
        getFunc = function() return tonumber(SafeGetCVar("textureFilteringMode", "1")) or 1 end,
        setFunc = function(val) SafeSetCVar("textureFilteringMode", val) end,
        width = 220,
    })

    C:AddToggle(qualitySection, {
        label = Text("PROJECTED_TEXTURES", "Projected Textures", "Projected Textures"),
        desc = Text("OPTION_TOOLTIP_PROJECTED_TEXTURES", "Enable ground visual spell effects and impact marks (highly recommended).", "Enable ground visual spell effects and impact marks (highly recommended)."),
        getFunc = function() return SafeGetCVar("projectedTextures") == "1" end,
        setFunc = function(val) SafeSetCVar("projectedTextures", val and "1" or "0") end,
    })

    C:AddDropdown(qualitySection, {
        label = Text("SHADOW_QUALITY", "Shadow Quality", "Shadow Quality"),
        desc = Text("OPTION_TOOLTIP_SHADOW_QUALITY", "Resolution and realism of dynamic character and world shadows.", "Resolution and realism of dynamic character and world shadows."),
        values = {
            [0] = Text("VIDEO_OPTIONS_OFF", "Off", "Off"),
            [1] = Text("VIDEO_OPTIONS_LOW", "Low", "Low"),
            [2] = Text("VIDEO_OPTIONS_FAIR", "Fair", "Fair"),
            [3] = Text("VIDEO_OPTIONS_HIGH", "High", "High"),
            [4] = Text("VIDEO_OPTIONS_ULTRA", "Ultra", "Ultra"),
        },
        getFunc = function() return tonumber(SafeGetCVar("shadowMode", "0")) or 0 end,
        setFunc = function(val) SafeSetCVar("shadowMode", val) end,
        width = 220,
    })

    C:AddSlider(qualitySection, {
        label = Text("PARTICLE_DENSITY", "Particle Density", "Particle Density"),
        desc = Text("OPTION_TOOLTIP_PARTICLE_DENSITY", "Number of particles in spell effects, fires, and explosions.", "Number of particles in spell effects, fires, and explosions."),
        min = 10,
        max = 100,
        step = 10,
        default = 70,
        getFunc = function() return tonumber(SafeGetCVar("particleDensity", "70")) or 70 end,
        setFunc = function(val) SafeSetCVar("particleDensity", val) end,
        width = 220,
    })

    C:AddSlider(qualitySection, {
        label = Text("ENVIRONMENT_DETAIL", "Environment Detail", "Environment Detail"),
        desc = Text("OPTION_TOOLTIP_ENVIRONMENT_DETAIL", "Density and quality of environmental models and structures.", "Density and quality of environmental models and structures."),
        min = 0.5,
        max = 1.5,
        step = 0.1,
        default = 1.0,
        getFunc = function() return tonumber(SafeGetCVar("environmentDetail", "1")) or 1.0 end,
        setFunc = function(val) SafeSetCVar("environmentDetail", val) end,
        width = 220,
    })

    C:AddDropdown(qualitySection, {
        label = Text("WEATHER_DETAIL", "Weather Density", "Weather Density"),
        desc = Text("OPTION_TOOLTIP_WEATHER_DETAIL", "Intensity of rain, snow, sandstorms, and fog effects.", "Intensity of rain, snow, sandstorms, and fog effects."),
        values = {
            [0] = Text("VIDEO_OPTIONS_OFF", "Off", "Off"),
            [1] = Text("VIDEO_OPTIONS_LOW", "Low", "Low"),
            [2] = Text("VIDEO_OPTIONS_FAIR", "Medium", "Medium"),
            [3] = Text("VIDEO_OPTIONS_HIGH", "High", "High"),
        },
        getFunc = function() return tonumber(SafeGetCVar("weatherDensity", "2")) or 2 end,
        setFunc = function(val) SafeSetCVar("weatherDensity", val) end,
        width = 220,
    })

    -- Advanced Graphics / Over-capped CVars Section
    local advSection = C:AddSection(scroll, Text(nil, "Advanced Graphics", "Advanced Graphics"))

    local viewDistText = Text("FARCLIP", "Farclip (View Distance)", "View Distance")
    C:AddSlider(advSection, {
        label = viewDistText .. " (farclip)",
        desc = Text("OPTION_TOOLTIP_FARCLIP", "World view distance in game units (unlocked past Blizzard default).", "World view distance in game units (unlocked past Blizzard default)."),
        min = 177,
        max = 1600,
        step = 50,
        default = 777,
        dbPath = "modules.video_options.farclip",
        getFunc = function() return GetModuleField("video_options", "farclip") or 777 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").farclip = val
            SafeSetCVar("farclip", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text(nil, "Horizon Farclip", "Horizon Farclip") .. " (horizonFarclip)",
        desc = Text(nil, "Horizon view distance (unlocked past Blizzard default).", "Horizon view distance (unlocked past Blizzard default)."),
        min = 500,
        max = 2112,
        step = 100,
        default = 1300,
        dbPath = "modules.video_options.horizonFarclip",
        getFunc = function() return GetModuleField("video_options", "horizonFarclip") or 1300 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").horizonFarclip = val
            SafeSetCVar("horizonFarclip", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text("GROUND_EFFECT_DIST", "Ground Effect Distance", "Ground Effect Distance"),
        desc = Text("OPTION_TOOLTIP_GROUND_EFFECT_DIST", "Render distance for foliage, grass, and ground clutter.", "Render distance for foliage, grass, and ground clutter."),
        min = 40,
        max = 140,
        step = 10,
        default = 70,
        dbPath = "modules.video_options.groundEffectDist",
        getFunc = function() return GetModuleField("video_options", "groundEffectDist") or 70 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").groundEffectDist = val
            SafeSetCVar("groundEffectDist", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text("GROUND_CLUTTER", "Ground Effect Density", "Ground Effect Density"),
        desc = Text("OPTION_TOOLTIP_GROUND_EFFECT_DENSITY", "Density of ground vegetation and clutter.", "Density of ground vegetation and clutter."),
        min = 16,
        max = 256,
        step = 16,
        default = 64,
        dbPath = "modules.video_options.groundEffectDensity",
        getFunc = function() return GetModuleField("video_options", "groundEffectDensity") or 64 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").groundEffectDensity = val
            SafeSetCVar("groundEffectDensity", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text(nil, "Ground Effect Alpha", "Ground Effect Alpha"),
        desc = Text(nil, "Opacity of foliage and ground clutter details.", "Opacity of foliage and ground clutter details."),
        min = 0,
        max = 100,
        step = 10,
        default = 100,
        dbPath = "modules.video_options.detailDoodadAlpha",
        getFunc = function() return GetModuleField("video_options", "detailDoodadAlpha") or 100 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").detailDoodadAlpha = val
            SafeSetCVar("detailDoodadAlpha", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text(nil, "Max Camera Distance Factor", "Max Camera Distance Factor"),
        desc = Text(nil, "Maximum camera distance zoom factor (unlocked up to 4.0).", "Maximum camera distance zoom factor (unlocked up to 4.0)."),
        min = 1.0,
        max = 4.0,
        step = 0.2,
        default = 1.0,
        dbPath = "modules.video_options.cameraMaxFactor",
        getFunc = function() return GetModuleField("video_options", "cameraMaxFactor") or 1.0 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").cameraMaxFactor = val
            SafeSetCVar("cameraDistanceMaxFactor", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text(nil, "Max Foreground FPS", "Max Foreground FPS"),
        desc = Text(nil, "Maximum framerate while World of Warcraft is active (0 = unlimited).", "Maximum framerate while World of Warcraft is active (0 = unlimited)."),
        min = 0,
        max = 200,
        step = 5,
        default = 0,
        getFunc = function() return tonumber(SafeGetCVar("maxFPS", "0")) or 0 end,
        setFunc = function(val) SafeSetCVar("maxFPS", val) end,
        width = 240,
    })

    C:AddSlider(advSection, {
        label = Text(nil, "Max Background FPS", "Max Background FPS"),
        desc = Text(nil, "Maximum framerate while World of Warcraft is in the background.", "Maximum framerate while World of Warcraft is in the background."),
        min = 10,
        max = 60,
        step = 5,
        default = 30,
        getFunc = function() return tonumber(SafeGetCVar("maxFPSBk", "30")) or 30 end,
        setFunc = function(val) SafeSetCVar("maxFPSBk", val) end,
        width = 240,
    })
end

-- ============================================================================
-- AUDIO SUB-TAB
-- ============================================================================

local function BuildAudioSubTab(scroll)
    local btnRow = C:AddRow(scroll)
    C:AddButton(btnRow, {
        label = Text("DEFAULTS", "Defaults", "Defaults"),
        desc = Text("OPTION_TOOLTIP_RESET_TO_DEFAULT", "Reset all audio options to Blizzard defaults.", "Reset all audio options to Blizzard defaults."),
        width = 120,
        callback = function()
            if AudioOptionsFrame_SetDefaults then
                pcall(AudioOptionsFrame_SetDefaults)
            end
            Panel:SelectTab("system")
        end,
    })

    -- Volume Section
    local volSection = C:AddSection(scroll, Text("VOLUME", "Volume", "Volume"))

    C:AddToggle(volSection, {
        label = Text("ENABLE_SOUND", "Enable Sound", "Enable Sound"),
        desc = Text("OPTION_TOOLTIP_ENABLE_ALL_SOUND", "Master switch to enable or mute all audio output.", "Master switch to enable or mute all audio output."),
        getFunc = function() return SafeGetCVar("Sound_EnableAllSound") == "1" end,
        setFunc = function(val)
            SafeSetCVar("Sound_EnableAllSound", val and "1" or "0")
            Panel:SelectTab("system")
        end,
    })

    C:AddToggle(volSection, {
        label = Text("SOUND_EFFECTS", "Sound Effects", "Sound Effects"),
        desc = Text("OPTION_TOOLTIP_ENABLE_SFX", "Spell sounds, combat effects, clicks, and UI interactions.", "Spell sounds, combat effects, clicks, and UI interactions."),
        getFunc = function() return SafeGetCVar("Sound_EnableSFX") == "1" end,
        setFunc = function(val) SafeSetCVar("Sound_EnableSFX", val and "1" or "0") end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" end,
    })

    C:AddToggle(volSection, {
        label = Text("ENABLE_MUSIC", "Music", "Music"),
        desc = Text("OPTION_TOOLTIP_ENABLE_MUSIC", "Zone soundtracks, ambient music, and cinematic audio.", "Zone soundtracks, ambient music, and cinematic audio."),
        getFunc = function() return SafeGetCVar("Sound_EnableMusic") == "1" end,
        setFunc = function(val) SafeSetCVar("Sound_EnableMusic", val and "1" or "0") end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" end,
    })

    C:AddToggle(volSection, {
        label = Text("ENABLE_AMBIENCE", "Ambience", "Ambience"),
        desc = Text("OPTION_TOOLTIP_ENABLE_AMBIENCE", "Environmental background sounds like wind, fire, and water.", "Environmental background sounds like wind, fire, and water."),
        getFunc = function() return SafeGetCVar("Sound_EnableAmbience") == "1" end,
        setFunc = function(val) SafeSetCVar("Sound_EnableAmbience", val and "1" or "0") end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" end,
    })

    C:AddToggle(volSection, {
        label = Text("ENABLE_BGSOUND", "Sound in Background", "Sound in Background"),
        desc = Text("OPTION_TOOLTIP_ENABLE_BGSOUND", "Keep game audio playing when World of Warcraft is minimized or loses focus.", "Keep game audio playing when World of Warcraft is minimized or loses focus."),
        getFunc = function() return SafeGetCVar("Sound_EnableSoundWhenBackgrounded") == "1" end,
        setFunc = function(val) SafeSetCVar("Sound_EnableSoundWhenBackgrounded", val and "1" or "0") end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" end,
    })

    C:AddSlider(volSection, {
        label = Text("MASTER_VOLUME", "Master Volume", "Master Volume"),
        desc = Text("OPTION_TOOLTIP_MASTER_VOLUME", "Overall volume level for all game sounds.", "Overall volume level for all game sounds."),
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        default = 1.0,
        getFunc = function() return tonumber(SafeGetCVar("Sound_MasterVolume", "1")) or 1.0 end,
        setFunc = function(val) SafeSetCVar("Sound_MasterVolume", val) end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" end,
        width = 240,
    })

    C:AddSlider(volSection, {
        label = Text("SOUND_VOLUME", "Sound Effects Volume", "Sound Effects Volume"),
        desc = Text("OPTION_TOOLTIP_SOUND_VOLUME", "Volume of combat, spells, and UI sound effects.", "Volume of combat, spells, and UI sound effects."),
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        default = 0.8,
        getFunc = function() return tonumber(SafeGetCVar("Sound_SFXVolume", "0.8")) or 0.8 end,
        setFunc = function(val) SafeSetCVar("Sound_SFXVolume", val) end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" or SafeGetCVar("Sound_EnableSFX") ~= "1" end,
        width = 240,
    })

    C:AddSlider(volSection, {
        label = Text("MUSIC_VOLUME", "Music Volume", "Music Volume"),
        desc = Text("OPTION_TOOLTIP_MUSIC_VOLUME", "Volume level of zone music and soundtracks.", "Volume level of zone music and soundtracks."),
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        default = 0.5,
        getFunc = function() return tonumber(SafeGetCVar("Sound_MusicVolume", "0.5")) or 0.5 end,
        setFunc = function(val) SafeSetCVar("Sound_MusicVolume", val) end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" or SafeGetCVar("Sound_EnableMusic") ~= "1" end,
        width = 240,
    })

    C:AddSlider(volSection, {
        label = Text("AMBIENCE_VOLUME", "Ambience Volume", "Ambience Volume"),
        desc = Text("OPTION_TOOLTIP_AMBIENCE_VOLUME", "Volume level of ambient environmental sounds.", "Volume level of ambient environmental sounds."),
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        default = 0.6,
        getFunc = function() return tonumber(SafeGetCVar("Sound_AmbienceVolume", "0.6")) or 0.6 end,
        setFunc = function(val) SafeSetCVar("Sound_AmbienceVolume", val) end,
        disabled = function() return SafeGetCVar("Sound_EnableAllSound") ~= "1" or SafeGetCVar("Sound_EnableAmbience") ~= "1" end,
        width = 240,
    })

    -- Sound Engine Section
    local engSection = C:AddSection(scroll, Text(nil, "Sound Engine", "Sound Engine"))

    C:AddDropdown(engSection, {
        label = Text("SOUND_QUALITY", "Sound Quality", "Sound Quality"),
        desc = Text("OPTION_TOOLTIP_SOUND_QUALITY", "Sample playback rate for game audio.", "Sample playback rate for game audio."),
        values = {
            [0] = Text("VIDEO_OPTIONS_LOW", "Low", "Low") .. " (22 kHz)",
            [1] = Text("VIDEO_OPTIONS_HIGH", "High", "High") .. " (44 kHz)",
        },
        getFunc = function() return tonumber(SafeGetCVar("Sound_OutputQuality", "1")) or 1 end,
        setFunc = function(val) SafeSetCVar("Sound_OutputQuality", val) end,
        width = 220,
    })

    C:AddSlider(engSection, {
        label = Text("SOUND_CHANNELS", "Sound Channels", "Sound Channels"),
        desc = Text("OPTION_TOOLTIP_SOUND_CHANNELS", "Number of simultaneous sound channels allocated for audio playback.", "Number of simultaneous sound channels allocated for audio playback."),
        min = 16,
        max = 128,
        step = 16,
        default = 32,
        dbPath = "modules.video_options.soundChannels",
        getFunc = function() return GetModuleField("video_options", "soundChannels") or 32 end,
        setFunc = function(val)
            EnsureModuleTable("video_options").soundChannels = val
            SafeSetCVar("Sound_NumChannels", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddToggle(engSection, {
        label = Text("ENABLE_HARDWARE", "Hardware Acceleration", "Hardware Acceleration"),
        desc = Text("OPTION_TOOLTIP_HARDWARE", "Enable hardware audio mixing if supported by your audio driver.", "Enable hardware audio mixing if supported by your audio driver."),
        getFunc = function() return SafeGetCVar("Sound_EnableHardware") == "1" end,
        setFunc = function(val) SafeSetCVar("Sound_EnableHardware", val and "1" or "0") end,
        disabled = function() return not IsEnabled("video_options") end,
    })

    C:AddToggle(engSection, {
        label = Text("ENABLE_SOFTWARE_HRTF", "Software HRTF", "Software HRTF"),
        desc = Text("OPTION_TOOLTIP_SOFTWARE_HRTF", "Enable software Head-Related Transfer Function for 3D positional audio.", "Enable software Head-Related Transfer Function for 3D positional audio."),
        dbPath = "modules.video_options.enableHRTF",
        getFunc = function() return GetModuleField("video_options", "enableHRTF") == true end,
        setFunc = function(val)
            EnsureModuleTable("video_options").enableHRTF = val
            SafeSetCVar("Sound_EnableSoftwareHRTF", val and "1" or "0")
        end,
        disabled = function() return not IsEnabled("video_options") end,
    })
end

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local subTabBuilders = {
    graphics = BuildGraphicsSubTab,
    audio    = BuildAudioSubTab,
}

local function BuildSystemTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. Text(nil, "System", "System") .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, Text(nil, "Configure display, graphics quality, unlocked CVars, and audio settings.", "Configure display, graphics quality, unlocked CVars, and audio settings."))
    C:AddSpacer(scroll)

    C:AddModuleToggle(scroll, {
        label = Text(nil, "Enable Video & Audio Options", "Enable Video & Audio Options"),
        desc = Text(nil, "Enable modern video and audio options module with unlocked CVars.", "Enable modern video and audio options module with unlocked CVars."),
        moduleName = "video_options",
        callback = function(val)
            if addon.VideoOptionsModule then
                if val then
                    addon.VideoOptionsModule:OnEnable()
                else
                    addon.VideoOptionsModule:OnDisable()
                end
            end
        end,
        after = function()
            Panel:SelectTab("system")
        end,
    })
    C:AddSpacer(scroll)

    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("system")
    end, subTabBuilders)

    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then
            builder(scroll)
        end
    end
end

Panel:RegisterTab("system", Text(nil, "System", "System"), BuildSystemTab, 15)
