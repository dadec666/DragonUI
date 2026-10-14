-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local unpack = unpack
local select = select
local tostring = tostring
local math_max = math.max
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
local TakeInboxMoney = TakeInboxMoney
local TakeInboxItem = TakeInboxItem
local AutoLootMailItem = AutoLootMailItem
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local CheckInbox = CheckInbox

local MailModule = {
    initialized = false,
    applied = false,
}

local isRu = (GetLocale and GetLocale() == "ruRU")
local DEFAULT_STRINGS = {
    ["Mail"] = isRu and "Почта" or "Mail",
    ["Retail-style mail window with Open All button"] = isRu
        and "Окно почты в стиле Retail с кнопкой «Открыть все»"
        or "Retail-style mail window with Open All button",
    ["Open All"] = isRu and "Открыть все" or "Open All",
    ["Opening..."] = isRu and "Открытие..." or "Opening...",
    ["Loot all mail attachments and gold (skips COD mail)"] = isRu
        and "Забрать все вложения и золото из писем (пропускает наложенный платеж)"
        or "Loot all mail attachments and gold (skips COD mail)",
    ["Inventory is full."] = isRu and "Инвентарь полон." or "Inventory is full.",
}

if addon.L then
    for k, v in pairs(DEFAULT_STRINGS) do
        if rawget(addon.L, k) == nil then
            rawset(addon.L, k, v)
        end
    end
end

if addon.defaults and addon.defaults.profile and addon.defaults.profile.modules then
    if addon.defaults.profile.modules.mail == nil then
        addon.defaults.profile.modules.mail = { enabled = true }
    end
end
if addon.db and addon.db.profile and addon.db.profile.modules then
    if addon.db.profile.modules.mail == nil then
        addon.db.profile.modules.mail = { enabled = true }
    end
end

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return DEFAULT_STRINGS[key] or key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("mail", MailModule,
        localized("Mail"),
        localized("Retail-style mail window with Open All button"),
        { lifecyclePrefix = "Mail", loadOnce = true })
end

local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local MARBLE = DIR .. "UI\\ui-background-marble"
local REDBUTTON = DIR .. "UI\\redbutton2x"
local PAGE_BG = DIR .. "Merchant\\pagebutton-background"
local PAGE_HILITE = DIR .. "Merchant\\pagebutton-hover"
local TAB_TEX = DIR .. "UI\\uiframetabs"
local PAGE_BTN_TEX = {
    InboxPrevPageButton = {
        up = DIR .. "Merchant\\pagebutton-prev-normal",
        down = DIR .. "Merchant\\pagebutton-prev-pressed",
        disabled = DIR .. "Merchant\\pagebutton-prev-disabled",
    },
    InboxNextPageButton = {
        up = DIR .. "Merchant\\pagebutton-next-normal",
        down = DIR .. "Merchant\\pagebutton-next-pressed",
        disabled = DIR .. "Merchant\\pagebutton-next-disabled",
    },
}

local WIDTH, HEIGHT = 338, 424
local INSET_LEFT, INSET_TOP, INSET_RIGHT, INSET_BOTTOM = 4, -60, -6, 4
local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 7, -63, 321, 354
local PANEL_X_NUDGE = 6
local INBOX_ITEMS_PER_PAGE = _G.INBOXITEMS_TO_DISPLAY or 7
local ATTACHMENTS_MAX_RECEIVE = _G.ATTACHMENTS_MAX_RECEIVE or 16
local ATTACHMENTS_MAX_SEND = _G.ATTACHMENTS_MAX_SEND or 12

local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }
local TEXT_ACTIVE_DROP, TEXT_NUDGE_X = -7, -2
local TAB_GAP = 1

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("mail")
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
    if not window or not window.SetAttribute then return end
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

local function skinActionButton(btn, width, height)
    if not btn then return end
    if width and height then
        btn:SetSize(width, height)
    end
    if addon.SkinRedButton then
        addon.SkinRedButton(btn)
    end
end

local function paintWindowChrome(window, portrait, closeBtn)
    window:SetSize(WIDTH, HEIGHT)
    if window.SetHitRectInsets then
        window:SetHitRectInsets(0, 0, 0, 0)
    end
    nudgePanel(window)

    local rock = window:CreateTexture(nil, "BACKGROUND", nil, -6)
    rock._duiOwned = true
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", window, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 2)
    window._duiRockBg = rock

    local streaks = window:CreateTexture(nil, "BORDER")
    streaks._duiOwned = true
    setAtlas(streaks, "_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetPoint("TOPLEFT", window, "TOPLEFT", 6, -21)
    streaks:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -2, -64)
    window._duiStreaks = streaks

    applySlices(window, "PortraitFrameTemplate")

    if portrait then
        portrait._duiOwned = true
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", window, "TOPLEFT", -2, 4)
        portrait:SetSize(56, 56)
        portrait:SetDrawLayer("ARTWORK")
        portrait:Show()
    end

    if closeBtn then
        dressCloseButton(closeBtn, window)
    end

    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_LEFT, INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    applySlices(inset, "InsetFrameTemplate")

    local marble = inset:CreateTexture(nil, "BACKGROUND")
    marble._duiOwned = true
    marble:SetTexture(MARBLE)
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)
    window._duiInset = inset

    return inset
end

local function hideStockTextures(frame, keepMap)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture"
            and not region._duiOwned and not (keepMap and keepMap[region]) then
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function reskinPageNav(btnName)
    local btn = _G[btnName]
    local set = PAGE_BTN_TEX[btnName]
    if not (btn and set) then return end

    local function retexture(getter, path, blend)
        local t = path and btn[getter] and btn[getter](btn)
        if not t then return end
        t:SetTexture(path)
        if blend then t:SetBlendMode(blend) end
    end

    retexture("GetNormalTexture", set.up)
    retexture("GetPushedTexture", set.down)
    retexture("GetDisabledTexture", set.disabled)
    retexture("GetHighlightTexture", PAGE_HILITE, "ADD")

    for _, r in ipairs({ btn:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then
            local layer = r:GetDrawLayer()
            if layer == "BACKGROUND" or layer == "ARTWORK" then
                r:SetTexture(PAGE_BG)
                r:Show()
            end
        end
    end
end

local function reskinSingleTab(tabName)
    local tab = _G[tabName]
    if not tab or tab._duiTabReskinned then return end

    tab:SetFrameLevel(tab:GetFrameLevel() + 4)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)

    local left   = _G[tabName .. "Left"]
    local right  = _G[tabName .. "Right"]
    local middle = _G[tabName .. "Middle"]
    local leftD  = _G[tabName .. "LeftDisabled"]
    local rightD = _G[tabName .. "RightDisabled"]
    local midD   = _G[tabName .. "MiddleDisabled"]

    if left then
        left:ClearAllPoints()
        left:SetSize(35, 36)
        left:SetTexture(TAB_TEX)
        left:SetTexCoord(0.015625, 0.5625, 0.816406, 0.957031)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", -CAP_OVERHANG, 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetSize(37, 36)
        right:SetTexture(TAB_TEX)
        right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", CAP_OVERHANG, 0)
    end
    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetSize(1, 36)
        middle:SetTexture(TAB_TEX)
        middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    end

    if leftD then
        leftD:ClearAllPoints()
        leftD:SetSize(35, 42)
        leftD:SetTexture(TAB_TEX)
        leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
        leftD:SetPoint("TOPLEFT", tab, "TOPLEFT", -ACTIVE_OVERHANG_L, 0)
    end
    if rightD then
        rightD:ClearAllPoints()
        rightD:SetSize(37, 42)
        rightD:SetTexture(TAB_TEX)
        rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
        rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", ACTIVE_OVERHANG_R, 0)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetSize(1, 42)
        midD:SetTexture(TAB_TEX)
        midD:SetTexCoord(0, 0.015625, 0.00390625, 0.167969)
        midD:SetPoint("TOPLEFT", leftD, "TOPRIGHT")
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT")
    end

    local stock = tab:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local function glow(tc, w, anchor)
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(tc))
        t:SetSize(w, HL_H)
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end

    local hlLeft  = left  and glow(HL_LEFT_TC, 35, left)
    local hlRight = right and glow(HL_RIGHT_TC, 37, right)
    local hlMid   = middle and (function()
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(HL_MIDDLE_TC))
        t:SetHeight(HL_H)
        t:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT")
        t:SetPoint("TOPRIGHT", hlRight, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end)()

    tab._duiHighlight = { hlLeft, hlRight, hlMid }

    local textObj = _G[tabName .. "Text"]
    if textObj then
        textObj:SetWordWrap(false)
        textObj:SetWidth(92)
    end
    local w = math_max(64, math.min(108, (tab:GetTextWidth() or 64) + 24))
    tab._duiWidth = w
    tab:SetWidth(w)
    tab._duiTabReskinned = true
end

local function updateMailTabHighlight()
    local f = _G.MailFrame
    if not f then return end
    local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(f) or f.selectedTab or 1
    for i = 1, 2 do
        local tab = _G["MailFrameTab" .. i]
        if tab then
            local active = (i == selected)
            tab:SetNormalFontObject(GameFontNormalSmall)
            tab:SetHighlightFontObject(GameFontHighlightSmall)
            tab:SetDisabledFontObject(active and GameFontHighlightSmall or GameFontNormalSmall)
            if tab._duiWidth then tab:SetWidth(tab._duiWidth) end

            local text = _G[tab:GetName() .. "Text"]
            if text then
                text:ClearAllPoints()
                text:SetPoint("CENTER", tab, "CENTER", TEXT_NUDGE_X, active and TEXT_ACTIVE_DROP or 0)
            end

            for _, piece in ipairs(tab._duiHighlight or {}) do
                piece:SetAlpha(active and 0 or HL_ALPHA)
            end
        end
    end
end

local function reskinMailTabs(f)
    reskinSingleTab("MailFrameTab1")
    reskinSingleTab("MailFrameTab2")

    local prev
    for _, name in ipairs({ "MailFrameTab1", "MailFrameTab2" }) do
        local tab = _G[name]
        if tab and tab:IsShown() then
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
            else
                tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
            end
            prev = tab
        end
    end
    updateMailTabHighlight()
end

-- Sequential mail looter that skips COD and Guild Master invoices.
local openAllBtn
local openAllFrame = CreateFrame("Frame")
openAllFrame:Hide()

local isOpeningAll = false
local currentMailIndex = 0
local currentAttachIndex = 0
local waitTimer = 0
local WAIT_DELAY = 0.15

local function CountFreeBagSlots()
    local totalFree = 0
    for bag = 0, 4 do
        local freeSlots, bagFamily = GetContainerNumFreeSlots(bag)
        if freeSlots and (bagFamily == 0 or bagFamily == nil) then
            totalFree = totalFree + freeSlots
        end
    end
    return totalFree
end

local function HasLootableMail()
    local numItems = GetInboxNumItems() or 0
    for i = 1, numItems do
        local _, _, _, _, money, codAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(i)
        if not isGM and (not codAmount or codAmount == 0) then
            if (money and money > 0) or (hasItem and hasItem > 0) then
                return true
            end
        end
    end
    return false
end

local function UpdateOpenAllButtonState()
    if not openAllBtn then return end
    if isOpeningAll then
        openAllBtn:Disable()
        openAllBtn:SetText(localized("Opening..."))
    else
        openAllBtn:SetText(localized("Open All"))
        if HasLootableMail() then
            openAllBtn:Enable()
        else
            openAllBtn:Disable()
        end
    end
end

local function StopOpenAll(reasonMsg)
    isOpeningAll = false
    openAllFrame:Hide()
    currentMailIndex = 0
    currentAttachIndex = 0
    waitTimer = 0
    UpdateOpenAllButtonState()
    if reasonMsg and addon.Print then
        addon:Print(reasonMsg)
    end
end

local function ProcessNextMailAction()
    if not _G.MailFrame or not _G.MailFrame:IsShown() then
        StopOpenAll()
        return
    end

    local numItems = GetInboxNumItems() or 0
    if currentMailIndex > numItems then
        currentMailIndex = numItems
    end

    while currentMailIndex >= 1 do
        local _, _, _, _, money, codAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(currentMailIndex)

        if isGM or (codAmount and codAmount > 0) then
            currentMailIndex = currentMailIndex - 1
            currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
        else
            if money and money > 0 then
                TakeInboxMoney(currentMailIndex)
                waitTimer = WAIT_DELAY
                return
            end

            if hasItem and hasItem > 0 then
                while currentAttachIndex >= 1 do
                    local itemName = GetInboxItem(currentMailIndex, currentAttachIndex)
                    if itemName then
                        if CountFreeBagSlots() == 0 then
                            StopOpenAll(localized("Inventory is full."))
                            return
                        end
                        TakeInboxItem(currentMailIndex, currentAttachIndex)
                        currentAttachIndex = currentAttachIndex - 1
                        waitTimer = WAIT_DELAY
                        return
                    end
                    currentAttachIndex = currentAttachIndex - 1
                end
            end

            currentMailIndex = currentMailIndex - 1
            currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
        end
    end

    CheckInbox()
    StopOpenAll()
end

openAllFrame:SetScript("OnUpdate", function(_, elapsed)
    if not isOpeningAll then
        openAllFrame:Hide()
        return
    end
    waitTimer = waitTimer - elapsed
    if waitTimer <= 0 then
        waitTimer = WAIT_DELAY
        ProcessNextMailAction()
    end
end)

local function StartOpenAll()
    if isOpeningAll then return end
    local numItems = GetInboxNumItems() or 0
    if numItems == 0 or not HasLootableMail() then
        UpdateOpenAllButtonState()
        return
    end

    isOpeningAll = true
    currentMailIndex = numItems
    currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
    waitTimer = 0
    UpdateOpenAllButtonState()
    openAllFrame:Show()
end

local function reskinItemSlot(btn)
    if not btn or btn._duiSlotSkinned then return end
    btn._duiSlotSkinned = true

    local name = btn:GetName()
    local icon = _G[name .. "IconTexture"] or btn.icon or (btn.GetNormalTexture and btn:GetNormalTexture())
    if icon and icon ~= (btn.GetNormalTexture and btn:GetNormalTexture()) then
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function dressMailItemRow(i, inbox)
    local itemRow = _G["MailItem" .. i]
    local itemBtn = _G["MailItem" .. i .. "Button"]
    local slotTex = _G["MailItem" .. i .. "ButtonSlot"]

    if not itemRow then return end

    hideStockTextures(itemRow)
    itemRow:SetSize(305, 42)
    itemRow:ClearAllPoints()
    if i == 1 then
        itemRow:SetPoint("TOPLEFT", inbox, "TOPLEFT", 13, -68)
    else
        itemRow:SetPoint("TOPLEFT", _G["MailItem" .. (i - 1)], "BOTTOMLEFT", 0, -1)
    end

    -- Subtle divider line across the parchment between rows.
    if not itemRow._duiDivider then
        local line = itemRow:CreateTexture(nil, "BORDER")
        line._duiOwned = true
        line:SetTexture(0.35, 0.26, 0.16, 0.55)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", itemRow, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", itemRow, "BOTTOMRIGHT", 2, 0)
        itemRow._duiDivider = line
    end

    if slotTex then
        slotTex._duiOwned = true
        slotTex:Show()
    end

    if itemBtn then
        reskinItemSlot(itemBtn)
    end

    local sender = _G["MailItem" .. i .. "Sender"]
    if sender then
        sender:SetPoint("TOPLEFT", itemRow, "TOPLEFT", 47, -4)
        sender:SetWidth(185)
    end

    local subject = _G["MailItem" .. i .. "Subject"]
    if subject then
        subject:SetPoint("TOPLEFT", sender, "BOTTOMLEFT", 0, -2)
        subject:SetWidth(248)
    end
end

local function buildMailFrame()
    local mailFrame = _G.MailFrame
    if not mailFrame or mailFrame._duiSkinned then return end
    mailFrame._duiSkinned = true

    local portrait = _G.MailPortraitIcon or _G.MailFramePortrait
    hideStockTextures(mailFrame, portrait and { [portrait] = true } or nil)

    local inset = paintWindowChrome(mailFrame, portrait, _G.InboxCloseButton)

    local inbox = _G.InboxFrame
    if inbox then
        hideStockTextures(inbox)
        inbox:SetAllPoints(mailFrame)
        inbox:SetFrameLevel(inset:GetFrameLevel() + 2)

        local page = inbox:CreateTexture(nil, "BACKGROUND")
        page._duiOwned = true
        setAtlas(page, "questbg-parchment")
        page:SetSize(PAGE_W, PAGE_H)
        page:SetPoint("TOPLEFT", inbox, "TOPLEFT", PAGE_X, PAGE_Y)
        inbox._duiPage = page

        if _G.InboxTitleText then
            _G.InboxTitleText:ClearAllPoints()
            _G.InboxTitleText:SetPoint("TOPLEFT", mailFrame, "TOPLEFT", 60, -5)
            _G.InboxTitleText:SetPoint("TOPRIGHT", mailFrame, "TOPRIGHT", -24, -5)
            _G.InboxTitleText:SetHeight(16)
            _G.InboxTitleText:SetJustifyH("CENTER")
        end

        if _G.InboxTooMuchMail then
            _G.InboxTooMuchMail:ClearAllPoints()
            _G.InboxTooMuchMail:SetPoint("TOP", mailFrame, "TOP", 10, -26)
        end

        for i = 1, INBOX_ITEMS_PER_PAGE do
            dressMailItemRow(i, inbox)
        end

        reskinPageNav("InboxPrevPageButton")
        reskinPageNav("InboxNextPageButton")

        local prevBtn = _G.InboxPrevPageButton
        if prevBtn then
            prevBtn:ClearAllPoints()
            prevBtn:SetPoint("BOTTOMLEFT", inbox, "BOTTOMLEFT", 16, 12)
        end

        local nextBtn = _G.InboxNextPageButton
        if nextBtn then
            nextBtn:ClearAllPoints()
            nextBtn:SetPoint("BOTTOMRIGHT", inbox, "BOTTOMRIGHT", -18, 12)
            for _, r in ipairs({ nextBtn:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then
                    r:ClearAllPoints()
                    r:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
                end
            end
        end

        if not openAllBtn then
            openAllBtn = CreateFrame("Button", "DragonUIOpenAllMailButton", inbox, "UIPanelButtonTemplate")
            skinActionButton(openAllBtn, 114, 22)
            openAllBtn:SetPoint("BOTTOM", inbox, "BOTTOM", 0, 14)
            openAllBtn:SetText(localized("Open All"))
            openAllBtn:SetScript("OnClick", StartOpenAll)
            openAllBtn:SetScript("OnEnter", function(self)
                if not _G.GameTooltip then return end
                _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(localized("Open All"), 1, 0.82, 0)
                _G.GameTooltip:AddLine(localized("Loot all mail attachments and gold (skips COD mail)"), 1, 1, 1, true)
                _G.GameTooltip:Show()
            end)
            openAllBtn:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)
        end
    end

    local sendFrame = _G.SendMailFrame
    if sendFrame then
        hideStockTextures(sendFrame)
        sendFrame:SetAllPoints(mailFrame)
        sendFrame:SetFrameLevel(inset:GetFrameLevel() + 2)

        local sendPage = sendFrame:CreateTexture(nil, "BACKGROUND")
        sendPage._duiOwned = true
        setAtlas(sendPage, "questbg-parchment")
        sendPage:SetSize(PAGE_W, PAGE_H)
        sendPage:SetPoint("TOPLEFT", sendFrame, "TOPLEFT", PAGE_X, PAGE_Y)

        if _G.SendMailTitleText then
            _G.SendMailTitleText:ClearAllPoints()
            _G.SendMailTitleText:SetPoint("TOPLEFT", mailFrame, "TOPLEFT", 60, -5)
            _G.SendMailTitleText:SetPoint("TOPRIGHT", mailFrame, "TOPRIGHT", -24, -5)
            _G.SendMailTitleText:SetHeight(16)
            _G.SendMailTitleText:SetJustifyH("CENTER")
        end

        if _G.SendMailScrollFrame then
            hideStockTextures(_G.SendMailScrollFrame)
            local CP = addon.CharacterPanel
            if CP and CP.ReskinScrollBar then
                CP.ReskinScrollBar(_G.SendMailScrollFrame, sendFrame, 60, -14, 90, true)
            end
        end

        for i = 1, ATTACHMENTS_MAX_SEND do
            reskinItemSlot(_G["SendMailAttachment" .. i])
        end

        if _G.SendMailCancelButton then
            _G.SendMailCancelButton:ClearAllPoints()
            _G.SendMailCancelButton:SetPoint("BOTTOMRIGHT", sendFrame, "BOTTOMRIGHT", -12, 12)
            skinActionButton(_G.SendMailCancelButton, 84, 22)
        end
        if _G.SendMailMailButton then
            _G.SendMailMailButton:ClearAllPoints()
            _G.SendMailMailButton:SetPoint("RIGHT", _G.SendMailCancelButton, "LEFT", -6, 0)
            skinActionButton(_G.SendMailMailButton, 84, 22)
        end
    end

    reskinMailTabs(mailFrame)

    local openFrame = _G.OpenMailFrame
    if openFrame and not openFrame._duiSkinned then
        openFrame._duiSkinned = true
        local openIcon = _G.OpenMailFrameIcon
        hideStockTextures(openFrame, openIcon and { [openIcon] = true } or nil)
        local openInset = paintWindowChrome(openFrame, openIcon, _G.OpenMailCloseButton)

        local openPage = openFrame:CreateTexture(nil, "BACKGROUND")
        openPage._duiOwned = true
        setAtlas(openPage, "questbg-parchment")
        openPage:SetSize(PAGE_W, PAGE_H)
        openPage:SetPoint("TOPLEFT", openFrame, "TOPLEFT", PAGE_X, PAGE_Y)
        openPage:SetDrawLayer("ARTWORK", -1)

        if _G.OpenMailTitleText then
            _G.OpenMailTitleText:ClearAllPoints()
            _G.OpenMailTitleText:SetPoint("TOPLEFT", openFrame, "TOPLEFT", 60, -5)
            _G.OpenMailTitleText:SetPoint("TOPRIGHT", openFrame, "TOPRIGHT", -24, -5)
            _G.OpenMailTitleText:SetHeight(16)
            _G.OpenMailTitleText:SetJustifyH("CENTER")
        end

        if _G.OpenMailScrollFrame then
            hideStockTextures(_G.OpenMailScrollFrame)
            _G.OpenMailScrollFrame:ClearAllPoints()
            _G.OpenMailScrollFrame:SetPoint("TOPLEFT", openFrame, "TOPLEFT", 16, -116)
            _G.OpenMailScrollFrame:SetSize(292, 196)
            local CP = addon.CharacterPanel
            if CP and CP.ReskinScrollBar then
                CP.ReskinScrollBar(_G.OpenMailScrollFrame, openFrame, 114, -14, 96, true)
            end
        end

        if _G.OpenMailLetterButton then reskinItemSlot(_G.OpenMailLetterButton) end
        if _G.OpenMailMoneyButton then reskinItemSlot(_G.OpenMailMoneyButton) end
        for i = 1, ATTACHMENTS_MAX_RECEIVE do
            reskinItemSlot(_G["OpenMailAttachmentButton" .. i])
        end

        if _G.OpenMailCancelButton then
            _G.OpenMailCancelButton:ClearAllPoints()
            _G.OpenMailCancelButton:SetPoint("BOTTOMRIGHT", openFrame, "BOTTOMRIGHT", -12, 12)
            skinActionButton(_G.OpenMailCancelButton, 82, 22)
        end
        if _G.OpenMailDeleteButton then
            _G.OpenMailDeleteButton:ClearAllPoints()
            _G.OpenMailDeleteButton:SetPoint("RIGHT", _G.OpenMailCancelButton, "LEFT", -4, 0)
            skinActionButton(_G.OpenMailDeleteButton, 82, 22)
        end
        if _G.OpenMailReplyButton then
            _G.OpenMailReplyButton:ClearAllPoints()
            _G.OpenMailReplyButton:SetPoint("RIGHT", _G.OpenMailDeleteButton, "LEFT", -4, 0)
            skinActionButton(_G.OpenMailReplyButton, 82, 22)
        end

        for _, child in ipairs({ openFrame:GetChildren() }) do
            if child ~= openInset and child:GetFrameLevel() <= openInset:GetFrameLevel() then
                child:SetFrameLevel(openInset:GetFrameLevel() + 2)
            end
        end
    end

    if _G.InboxFrame_Update and not mailFrame._duiUpdateHooked then
        mailFrame._duiUpdateHooked = true
        hooksecurefunc("InboxFrame_Update", function()
            if not IsModuleEnabled() then return end
            UpdateOpenAllButtonState()
        end)
    end

    if _G.MailFrameTab_OnClick and not mailFrame._duiTabHooked then
        mailFrame._duiTabHooked = true
        hooksecurefunc("MailFrameTab_OnClick", function()
            if not IsModuleEnabled() then return end
            updateMailTabHighlight()
        end)
    end
end

function addon.ApplyMailSystem()
    if not IsModuleEnabled() then return end
    MailModule.initialized = true
    MailModule.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("mail_apply", buildMailFrame)
        return
    end
    buildMailFrame()
    UpdateOpenAllButtonState()
end

function addon.RestoreMailSystem()
    StopOpenAll()
    MailModule.applied = false
end

function addon.RefreshMailSystem()
    if IsModuleEnabled() then
        addon.ApplyMailSystem()
    else
        addon.RestoreMailSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("MAIL_SHOW")
boot:RegisterEvent("MAIL_INBOX_UPDATE")
boot:RegisterEvent("MAIL_CLOSED")
boot:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplyMailSystem()
    elseif event == "MAIL_SHOW" then
        buildMailFrame()
        UpdateOpenAllButtonState()
    elseif event == "MAIL_INBOX_UPDATE" then
        UpdateOpenAllButtonState()
    elseif event == "MAIL_CLOSED" then
        StopOpenAll()
    end
end)
