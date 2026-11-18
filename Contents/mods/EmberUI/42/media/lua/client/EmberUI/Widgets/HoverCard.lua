--[[
    HoverCard.lua - EmberUI Widgets
    Structured rich hover card:
      - Separates prepare() (layout & text wrapping) from drawPrepared() (100% Zero-GC).
      - Non-occluding top-level panel (isPointOver/isMouseOver false, unmounts on hide/reset).
]]

local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"
local UICache = require "EmberUI/Core/UICache"

local HoverCard = {}

local DEFAULT_MAX_WIDTH = 320
local MIN_WIDTH = 160
local PAD = 10
local ROW_GAP = 4
local KEY_VALUE_GAP = 14

local floatPanel = nil
local currentOwner = nil
local currentSpec = nil
local currentPrepared = nil

local function fontHeight()
    if type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and tm.getFontHeight then
            return tm:getFontHeight(UIFont.Small)
        end
    end
    return 14
end

function HoverCard.fromText(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local first, rest = raw:match("^([^\r\n]+)\r?\n+(.+)$")
    if first then
        return { title = first, body = rest }
    end
    return { body = raw }
end

function HoverCard.prepare(spec, maxWidth)
    if type(spec) == "string" then
        spec = HoverCard.fromText(spec)
    end
    if type(spec) ~= "table" then return nil end

    local fh = fontHeight()
    local maxW = spec.maxWidth or maxWidth or DEFAULT_MAX_WIDTH
    local title = spec.title
    local badge = spec.badge
    local rows = spec.rows
    local body = spec.body

    local contentW = MIN_WIDTH - PAD * 2

    local badgeW = 0
    if type(badge) == "table" and badge.label and badge.label ~= "" then
        badgeW = UICache.measure(UIFont.Small, badge.label) + 12
    end
    if title and title ~= "" then
        local maxTitleW = math.max(60, maxW - PAD * 2 - (badgeW > 0 and (badgeW + 14) or 0))
        title = Text.truncate(title, maxTitleW, UIFont.Small)
    end
    local titleW = (title and title ~= "") and UICache.measure(UIFont.Small, title) or 0
    if badgeW > 0 then
        contentW = math.max(contentW, titleW + badgeW + 14)
    elseif titleW > 0 then
        contentW = math.max(contentW, titleW)
    end

    local keyColW = 0
    local valColW = 0
    if type(rows) == "table" and #rows > 0 then
        for i = 1, #rows do
            local r = rows[i]
            if r.key and r.key ~= "" then
                keyColW = math.max(keyColW, UICache.measure(UIFont.Small, r.key))
            end
            if r.value and r.value ~= "" then
                valColW = math.max(valColW, UICache.measure(UIFont.Small, r.value))
            end
        end
        if keyColW > 0 and valColW > 0 then
            contentW = math.max(contentW, keyColW + KEY_VALUE_GAP + valColW)
        else
            contentW = math.max(contentW, keyColW + valColW)
        end
    end

    contentW = math.min(maxW - PAD * 2, math.max(MIN_WIDTH - PAD * 2, contentW))

    local bodyLines = nil
    if body and body ~= "" then
        bodyLines = Text.wrapWordsLimited(body, contentW, UIFont.Small, spec.maxBodyLines or 12)
        if bodyLines then
            for i = 1, #bodyLines do
                contentW = math.max(contentW, math.min(maxW - PAD * 2, UICache.measure(UIFont.Small, bodyLines[i])))
            end
        end
    end

    local w = math.min(maxW, math.max(MIN_WIDTH, contentW + PAD * 2))
    local hasHeader = (title ~= nil and title ~= "") or (badge ~= nil)
    local headerH = hasHeader and (fh + 10) or 0

    local h = PAD
    if hasHeader then
        h = headerH + 6
    end
    if type(rows) == "table" and #rows > 0 then
        h = h + #rows * fh + (#rows - 1) * ROW_GAP + 4
    end
    if bodyLines and #bodyLines > 0 then
        if type(rows) == "table" and #rows > 0 then
            h = h + 6
        end
        h = h + #bodyLines * (fh + 2)
    end
    h = h + PAD - 2

    return {
        width = w,
        height = h,
        fontHeight = fh,
        hasHeader = hasHeader,
        headerHeight = headerH,
        title = title,
        titleColor = spec.titleColor,
        accent = spec.accent,
        badge = badge,
        badgeWidth = badgeW,
        rows = rows,
        keyColWidth = keyColW,
        bodyLines = bodyLines,
        themeRevision = Theme.revision,
    }
end

function HoverCard.drawPrepared(owner, x, y, p)
    if not owner or not p then return end
    local w, h = p.width, p.height
    local fh = p.fontHeight or 14
    local pad = PAD

    Chrome.shadow(owner, x, y, w, h, 0.45)
    Chrome.roundedFill(owner, x, y, w, h, Theme.window or Theme.panel, false, 9)

    local cursorY = y + pad
    if p.hasHeader then
        local hh = p.headerHeight
        Chrome.titleBar(owner, x + 1, y + 1, math.max(0, w - 2), hh, Theme.titleBar or Theme.panel, p.accent or Theme.titleAccent, Theme.borderSubtle, 9)
        if p.title and p.title ~= "" then
            local ty = y + math.floor((hh - fh) / 2)
            Theme.text(owner, p.title, x + pad, ty, p.titleColor or Theme.textColor)
        end
        if type(p.badge) == "table" and p.badge.label and p.badge.label ~= "" then
            local bw = p.badgeWidth
            local bh = fh + 2
            local bx = x + w - pad - bw
            local by = y + math.floor((hh - bh) / 2)
            Chrome.pill(owner, bx, by, bw, bh, p.badge.bg or Theme.badgeBg or Theme.well)
            local bfg = p.badge.color or Theme.textColor
            Theme.text(owner, p.badge.label, bx + 6, by + 1, bfg)
        end
        cursorY = y + hh + 6
    end

    Chrome.roundedBorder(owner, x, y, w, h, Theme.borderFocus or Theme.border, false, 9)

    if type(p.rows) == "table" and #p.rows > 0 then
        for i = 1, #p.rows do
            local r = p.rows[i]
            if r.key and r.key ~= "" then
                Theme.text(owner, r.key, x + pad, cursorY, Theme.muted)
            end
            if r.value and r.value ~= "" then
                local valW = UICache.measure(UIFont.Small, r.value)
                local valX = math.max(x + pad + p.keyColWidth + KEY_VALUE_GAP, x + w - pad - valW)
                Theme.text(owner, r.value, valX, cursorY, r.color or Theme.textColor)
            end
            cursorY = cursorY + fh + ROW_GAP
        end
        if p.bodyLines and #p.bodyLines > 0 then
            owner:drawRect(x + pad, cursorY + 1, w - pad * 2, 1, 0.45, Theme.border.r, Theme.border.g, Theme.border.b)
            cursorY = cursorY + 6
        end
    end

    if p.bodyLines and #p.bodyLines > 0 then
        for i = 1, #p.bodyLines do
            Theme.text(owner, p.bodyLines[i], x + pad, cursorY, Theme.textColor)
            cursorY = cursorY + fh + 2
        end
    end
end

local function ensurePanel()
    if floatPanel then return floatPanel end
    if ISPanel == nil then require "ISUI/ISPanel" end
    local HoverFloat = ISPanel:derive("EmberRoutesHoverCardPanel")
    function HoverFloat:isPointOver() return false end
    function HoverFloat:isMouseOver() return false end
    function HoverFloat:onMouseDown() return false end
    function HoverFloat:onMouseUp() return false end
    function HoverFloat:prerender()
        if currentPrepared then
            HoverCard.drawPrepared(self, 0, 0, currentPrepared)
        end
    end
    local p = HoverFloat:new(0, 0, MIN_WIDTH, 40)
    p.background = false
    p.wantMouseEvents = false
    p.keepOnScreen = false
    p:initialise()
    p:instantiate()
    if p.setWantMouseEvents then p:setWantMouseEvents(false) end
    if p.setAlwaysOnTop then p:setAlwaysOnTop(true) end
    p:setVisible(false)
    floatPanel = p
    return floatPanel
end

local function clampPosition(ax, ay, w, h)
    local x = (ax or 0) + 24
    local y = (ay or 0) + 12
    local core = type(getCore) == "function" and getCore()
    if core then
        local sw = core:getScreenWidth()
        local sh = core:getScreenHeight()
        if type(sw) == "number" and x + w > sw - 6 then
            x = math.max(6, (ax or 0) - w - 12)
        end
        if type(sh) == "number" and y + h > sh - 6 then
            y = math.max(6, sh - h - 8)
        end
    end
    return x, y
end

function HoverCard.show(ownerKey, spec, anchorX, anchorY)
    if not spec then
        HoverCard.hide(ownerKey)
        return
    end
    if currentOwner ~= ownerKey or currentSpec ~= spec or not currentPrepared or currentPrepared.themeRevision ~= Theme.revision then
        currentPrepared = HoverCard.prepare(spec)
        currentSpec = spec
        currentOwner = ownerKey
    end
    if not currentPrepared then return end

    local mx = anchorX or (type(getMouseX) == "function" and getMouseX()) or 0
    local my = anchorY or (type(getMouseY) == "function" and getMouseY()) or 0
    local x, y = clampPosition(mx, my, currentPrepared.width, currentPrepared.height)

    if type(UIManager) == "nil" or type(getCore) ~= "function" then
        return currentPrepared
    end

    local panel = ensurePanel()
    panel:setX(x)
    panel:setY(y)
    panel:setWidth(currentPrepared.width)
    panel:setHeight(currentPrepared.height)
    if not panel.getIsVisible or not panel:getIsVisible() then
        panel:addToUIManager()
        panel:setVisible(true)
    end
    if panel.bringToTop then panel:bringToTop() end
    return currentPrepared
end

function HoverCard.hide(ownerKey)
    if ownerKey ~= nil and currentOwner ~= ownerKey then return false end
    currentOwner = nil
    currentSpec = nil
    currentPrepared = nil
    if floatPanel then
        if floatPanel.setVisible then floatPanel:setVisible(false) end
        if floatPanel.removeFromUIManager then floatPanel:removeFromUIManager() end
    end
    return true
end

function HoverCard.reset()
    HoverCard.hide(nil)
    floatPanel = nil
end

function HoverCard.getCurrent()
    return currentOwner, currentPrepared
end

return HoverCard
