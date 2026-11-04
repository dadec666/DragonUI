-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addonName, addon = ...
local L = addon.L

local VideoOptionsModule = {
    initialized = false,
    applied = false,
}

local function GetModuleConfig()
    return addon:GetModuleConfig("video_options")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("video_options")
end

local function SafeSetCVar(cvar, value)
    if not cvar or value == nil then return end
    if GetCVar(cvar) ~= nil then
        pcall(SetCVar, cvar, tostring(value))
    end
end

local function OpenSystemTab(subTab)
    if not addon.OptionsPanel and LoadAddOn then
        LoadAddOn("DragonUI_Options")
    end
    if addon.SetSystemSubTab and subTab then
        addon.SetSystemSubTab(subTab)
    end
    if addon.OptionsPanel and addon.OptionsPanel.Open then
        addon.OptionsPanel:Open("system")
    end
end

local function HookOptionFrames()
    if VideoOptionsFrame and not VideoOptionsFrame._dragonUIHooked then
        VideoOptionsFrame._dragonUIHooked = true
        VideoOptionsFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then
                HideUIPanel(self)
            else
                self:Hide()
            end
            OpenSystemTab("graphics")
        end)
    end

    if AudioOptionsFrame and not AudioOptionsFrame._dragonUIHooked then
        AudioOptionsFrame._dragonUIHooked = true
        AudioOptionsFrame:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            if HideUIPanel then
                HideUIPanel(self)
            else
                self:Hide()
            end
            OpenSystemTab("audio")
        end)
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
end

VideoOptionsModule.Apply = VideoOptionsModule.OnEnable
VideoOptionsModule.Refresh = VideoOptionsModule.ApplySettings
VideoOptionsModule.Restore = VideoOptionsModule.OnDisable

addon.ApplyVideoOptionsSystem = function() VideoOptionsModule:OnEnable() end
addon.RestoreVideoOptionsSystem = function() VideoOptionsModule:OnDisable() end
addon.RefreshVideoOptionsSystem = function() VideoOptionsModule:Refresh() end
addon.VideoOptionsModule = VideoOptionsModule

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
