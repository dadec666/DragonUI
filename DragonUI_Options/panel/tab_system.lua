-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

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

local function SafeSetCVar(cvar, value)
    if not cvar or value == nil then return end
    if GetCVar(cvar) ~= nil then
        pcall(SetCVar, cvar, tostring(value))
    end
end

local function BuildSystemTab(container)
    C:AddLabel(container, "|cffFFD700" .. (LO["System"] or "System") .. "|r", { color = C.Theme.textGold })
    C:AddDescription(container, LO["Configure display, unlocked graphics CVars, and sound engine settings."] or "Configure display, unlocked graphics CVars, and sound engine settings.")
    C:AddSpacer(container)

    C:AddModuleToggle(container, {
        label = LO["Enable Video & Audio Options"] or "Enable Video & Audio Options",
        desc = LO["Enable modern video and audio options module with unlocked CVars."] or "Enable modern video and audio options module with unlocked CVars.",
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
    C:AddSpacer(container)

    local displaySection = C:AddSection(container, LO["Display"] or "Display")

    C:AddDropdown(displaySection, {
        label = LO["Display Mode"] or "Display Mode",
        desc = LO["Switch between Fullscreen and Windowed display mode."] or "Switch between Fullscreen and Windowed display mode.",
        values = {
            [0] = LO["Fullscreen"] or "Fullscreen",
            [1] = LO["Windowed"] or "Windowed",
        },
        getFunc = function()
            return tonumber(GetCVar("gxWindow")) or 0
        end,
        setFunc = function(val)
            SafeSetCVar("gxWindow", val)
            if RestartGx then
                pcall(RestartGx)
            end
        end,
        width = 200,
    })

    C:AddToggle(displaySection, {
        label = LO["Vertical Sync (VSync)"] or "Vertical Sync (VSync)",
        desc = LO["Synchronize frame rate with monitor refresh rate to prevent screen tearing."] or "Synchronize frame rate with monitor refresh rate to prevent screen tearing.",
        getFunc = function()
            return GetCVar("gxVSync") == "1"
        end,
        setFunc = function(val)
            SafeSetCVar("gxVSync", val and "1" or "0")
            if RestartGx then
                pcall(RestartGx)
            end
        end,
    })

    local gfxSection = C:AddSection(container, LO["Advanced Graphics"] or "Advanced Graphics")

    C:AddSlider(gfxSection, {
        label = LO["Farclip (View Distance)"] or "Farclip (View Distance)",
        desc = LO["World view distance in game units (unlocked past Blizzard default)."] or "World view distance in game units (unlocked past Blizzard default).",
        min = 177,
        max = 1600,
        step = 50,
        default = 777,
        dbPath = "modules.video_options.farclip",
        getFunc = function()
            return GetModuleField("video_options", "farclip") or 777
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").farclip = val
            SafeSetCVar("farclip", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(gfxSection, {
        label = LO["Horizon Farclip"] or "Horizon Farclip",
        desc = LO["Horizon view distance (unlocked past Blizzard default)."] or "Horizon view distance (unlocked past Blizzard default).",
        min = 500,
        max = 2112,
        step = 100,
        default = 1300,
        dbPath = "modules.video_options.horizonFarclip",
        getFunc = function()
            return GetModuleField("video_options", "horizonFarclip") or 1300
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").horizonFarclip = val
            SafeSetCVar("horizonFarclip", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(gfxSection, {
        label = LO["Ground Effect Distance"] or "Ground Effect Distance",
        desc = LO["Render distance for foliage, grass, and ground clutter."] or "Render distance for foliage, grass, and ground clutter.",
        min = 40,
        max = 140,
        step = 10,
        default = 70,
        dbPath = "modules.video_options.groundEffectDist",
        getFunc = function()
            return GetModuleField("video_options", "groundEffectDist") or 70
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").groundEffectDist = val
            SafeSetCVar("groundEffectDist", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(gfxSection, {
        label = LO["Ground Effect Density"] or "Ground Effect Density",
        desc = LO["Density of ground vegetation and clutter."] or "Density of ground vegetation and clutter.",
        min = 16,
        max = 256,
        step = 16,
        default = 64,
        dbPath = "modules.video_options.groundEffectDensity",
        getFunc = function()
            return GetModuleField("video_options", "groundEffectDensity") or 64
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").groundEffectDensity = val
            SafeSetCVar("groundEffectDensity", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddSlider(gfxSection, {
        label = LO["Max Camera Distance Factor"] or "Max Camera Distance Factor",
        desc = LO["Maximum camera distance zoom factor (unlocked up to 4.0)."] or "Maximum camera distance zoom factor (unlocked up to 4.0).",
        min = 1.0,
        max = 4.0,
        step = 0.2,
        default = 1.0,
        dbPath = "modules.video_options.cameraMaxFactor",
        getFunc = function()
            return GetModuleField("video_options", "cameraMaxFactor") or 1.0
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").cameraMaxFactor = val
            SafeSetCVar("cameraDistanceMaxFactor", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    local soundSection = C:AddSection(container, LO["Sound Engine"] or "Sound Engine")

    C:AddSlider(soundSection, {
        label = LO["Sound Channels"] or "Sound Channels",
        desc = LO["Number of simultaneous sound channels allocated for audio playback."] or "Number of simultaneous sound channels allocated for audio playback.",
        min = 16,
        max = 128,
        step = 16,
        default = 32,
        dbPath = "modules.video_options.soundChannels",
        getFunc = function()
            return GetModuleField("video_options", "soundChannels") or 32
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").soundChannels = val
            SafeSetCVar("Sound_NumChannels", val)
        end,
        disabled = function() return not IsEnabled("video_options") end,
        width = 240,
    })

    C:AddToggle(soundSection, {
        label = LO["Hardware Acceleration"] or "Hardware Acceleration",
        desc = LO["Enable hardware audio mixing if supported by your audio driver."] or "Enable hardware audio mixing if supported by your audio driver.",
        getFunc = function()
            return GetCVar("Sound_EnableHardware") == "1"
        end,
        setFunc = function(val)
            SafeSetCVar("Sound_EnableHardware", val and "1" or "0")
        end,
        disabled = function() return not IsEnabled("video_options") end,
    })

    C:AddToggle(soundSection, {
        label = LO["Software HRTF"] or "Software HRTF",
        desc = LO["Enable software Head-Related Transfer Function for 3D positional audio."] or "Enable software Head-Related Transfer Function for 3D positional audio.",
        dbPath = "modules.video_options.enableHRTF",
        getFunc = function()
            return GetModuleField("video_options", "enableHRTF") == true
        end,
        setFunc = function(val)
            EnsureModuleTable("video_options").enableHRTF = val
            SafeSetCVar("Sound_EnableSoftwareHRTF", val and "1" or "0")
        end,
        disabled = function() return not IsEnabled("video_options") end,
    })
end

Panel:RegisterTab("system", LO["System"] or "System", BuildSystemTab, 15)

