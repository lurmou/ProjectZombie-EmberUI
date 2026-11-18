--[[
    StatMeter.lua - EmberRoutes UI
    High-density physiological, progress, and resource capacity gauge.
    Inspired by Frostpunk gauges, RimWorld colonist vitals, and State of Decay stamina caps.
    Provides both an ISPanel component and a static zero-GC draw function.
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local UICache = require "EmberUI/Core/UICache"

---@class EmberRoutesStatMeter:ISPanel
---@field fontHeight number
---@field pad number
---@field fraction number
---@field capFraction number?
---@field mode string "progress"|"health"|"load"|"custom"
---@field customColor table?
---@field threshold number?
---@field label string?
---@field labelW number
---@field fillW number
---@field capW number
---@field activeColor table
---@field _drawOpts table
local StatMeter = ISPanel:derive("EmberRoutesStatMeter")

-- Pre-allocated color buffers synced to Theme.revision (Zero GC)
local COLOR_GREEN     = {r = 0, g = 0, b = 0, a = 1.0}
local COLOR_YELLOW    = {r = 0, g = 0, b = 0, a = 1.0}
local COLOR_RED       = {r = 0, g = 0, b = 0, a = 1.0}
local COLOR_BLUE      = {r = 0, g = 0, b = 0, a = 1.0}
local COLOR_TROUGH    = {r = 0, g = 0, b = 0, a = 0.96}
local COLOR_BORDER    = {r = 0, g = 0, b = 0, a = 0.90}
local COLOR_CAP       = {r = 0, g = 0, b = 0, a = 0.75}
local COLOR_CAP_HATCH = {r = 0, g = 0, b = 0, a = 0.80}
local COLOR_SHADOW    = {r = 0, g = 0, b = 0, a = 0.85}
local EMPTY_OPTS      = {}
local syncedRev       = -1
local cachedFontH     = nil

local function copyInto(dst, src, a)
    dst.r, dst.g, dst.b = src.r, src.g, src.b
    if a ~= nil then dst.a = a else dst.a = src.a or 1.0 end
end

local function syncTheme()
    local rev = Theme.revision or 0
    if syncedRev == rev then return end
    syncedRev = rev
    local ready = (Theme.status and Theme.status.READY) or Theme.accent
    local warn  = Theme.gold or (Theme.status and Theme.status.UPDATING) or Theme.accent
    local err   = (Theme.status and Theme.status.ERROR) or Theme.danger
    local info  = Theme.info or Theme.accent
    local well  = Theme.well or Theme.panel
    local bdr   = Theme.borderSubtle or Theme.border
    copyInto(COLOR_GREEN, ready, 1.0)
    copyInto(COLOR_YELLOW, warn, 1.0)
    copyInto(COLOR_RED, err, 1.0)
    copyInto(COLOR_BLUE, info, 1.0)
    copyInto(COLOR_TROUGH, well, well.a or 0.96)
    copyInto(COLOR_BORDER, bdr, bdr.a or 0.90)
    COLOR_CAP.r = well.r * 0.70 + err.r * 0.30
    COLOR_CAP.g = well.g * 0.70 + err.g * 0.30
    COLOR_CAP.b = well.b * 0.70 + err.b * 0.30
    COLOR_CAP_HATCH.r = well.r * 0.50 + err.r * 0.50
    COLOR_CAP_HATCH.g = well.g * 0.50 + err.g * 0.50
    COLOR_CAP_HATCH.b = well.b * 0.50 + err.b * 0.50
end

syncTheme()

local function resolveColor(mode, fraction, customColor)
    if customColor then return customColor end
    local f = math.max(0, math.min(1, fraction or 0))
    if mode == "health" then
        -- High is good
        if f > 0.60 then return COLOR_GREEN
        elseif f > 0.25 then return COLOR_YELLOW
        else return COLOR_RED end
    elseif mode == "load" or mode == "danger" or mode == "fatigue" then
        -- Low is good, high is danger
        if f < 0.60 then return COLOR_GREEN
        elseif f < 0.85 then return COLOR_YELLOW
        else return COLOR_RED end
    else
        -- Progress mode
        if f >= 1.0 then return COLOR_GREEN
        else return COLOR_BLUE end
    end
end

---Static zero-GC draw function for embedding inside list rows or custom prerender loops.
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number? default 4
---@param fraction number 0.0 to 1.0
---@param color table? {r, g, b, a}
---@param trough table? {r, g, b, a}
function StatMeter.drawBar(owner, x, y, width, height, fraction, color, trough)
    syncTheme()
    local h = height or 4
    local f = math.max(0, math.min(1.0, fraction or 0))
    Chrome.roundedFill(owner, x, y, width, h, trough or COLOR_TROUGH)
    local fillW = math.floor(width * f)
    if fillW > 0 then
        local col = color or COLOR_GREEN
        if fillW >= 14 and h >= 14 then
            Chrome.roundedFill(owner, x, y, fillW, h, col)
        elseif h >= 12 and width >= 14 then
            local ix = x + 2
            local iw = math.min(fillW, math.max(1, width - 4))
            Theme.rect(owner, ix, y + 2, iw, math.max(1, h - 4), col)
        else
            Chrome.roundedFill(owner, x, y, fillW, h, col)
        end
    end
end

---Static zero-GC draw function for a two-segment comparative ratio bar (e.g. Work vs Leisure).
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number
---@param ratioA number 0.0 to 1.0 (proportion of segment A)
---@param opts table? {colorA=table, colorB=table, trough=table, border=table, isEmpty=boolean, plain=boolean}
function StatMeter.drawSplitBar(owner, x, y, width, height, ratioA, opts)
    syncTheme()
    opts = opts or EMPTY_OPTS
    local trough = opts.trough or COLOR_TROUGH
    Chrome.roundedFill(owner, x, y, width, height, trough)

    if not opts.isEmpty and width > 4 then
        local fA = math.max(0, math.min(1.0, ratioA or 0))
        local colA = opts.colorA or COLOR_BLUE
        local colB = opts.colorB or COLOR_GREEN

        -- Keep segments neatly inset within the rounded trough border
        local insetX = (height >= 10) and 2 or 0
        local insetY = (height >= 10) and 2 or 0
        local innerX = x + insetX
        local innerY = y + insetY
        local innerW = math.max(1, width - insetX * 2)
        local innerH = math.max(1, height - insetY * 2)

        local fillA = math.floor(innerW * fA)
        local fillB = innerW - fillA

        if fA > 0 and fillA > 0 then
            Theme.rect(owner, innerX, innerY, fillA, innerH, colA)
        end
        if fA < 1.0 and fillB > 0 then
            Theme.rect(owner, innerX + fillA, innerY, fillB, innerH, colB)
        end

        -- Clean 1px divider seam between segments when both exist
        if fillA > 1 and fillB > 1 then
            Theme.rect(owner, innerX + fillA, innerY, 1, innerH, trough)
        end
    end

    if not opts.plain then
        Chrome.roundedBorder(owner, x, y, width, height, opts.border or COLOR_BORDER)
    end
end

---Static zero-GC draw function for embedding inside list rows or custom prerender loops.
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number
---@param fraction number 0.0 to 1.0
---@param opts table? {mode="progress"|"health"|"load"|"custom", color=table, capFraction=number, threshold=number, label=string, labelW=number, showPercent=boolean}
function StatMeter.draw(owner, x, y, width, height, fraction, opts)
    syncTheme()
    opts = opts or EMPTY_OPTS
    local f = math.max(0, math.min(1, fraction or 0))
    local mode = opts.mode or "progress"
    local col = resolveColor(mode, f, opts.color)

    -- 1. Dark Trough (rounded via Chrome when large enough, flat fallback for thin meters)
    Chrome.roundedFill(owner, x, y, width, height, opts.trough or COLOR_TROUGH)

    -- 2. Fill Bar (1px inset from rounded border to prevent outer corner halo mixing)
    local fillW = math.max(0, math.floor(width * f))
    if fillW > 0 then
        local inset = (not opts.plain and width >= 6 and height >= 6) and 1 or 0
        local fx = x + inset
        local fy = y + inset
        local fw = math.min(fillW, math.max(1, width - inset * 2))
        local fh = math.max(1, height - inset * 2)
        if fw >= 14 and fh >= 14 then
            Chrome.roundedFill(owner, fx, fy, fw, fh, col)
        elseif fh >= 10 and width >= 14 then
            local iw = math.min(fillW, math.max(1, width - 4))
            Theme.rect(owner, x + 2, y + 2, iw, math.max(1, height - 4), col)
        else
            Chrome.roundedFill(owner, fx, fy, fw, fh, col)
        end
    end

    -- 3. Stamina/Capacity Lock (Cap Region)
    if opts.capFraction and opts.capFraction < 1.0 then
        local capStart = math.floor(width * math.max(0, opts.capFraction))
        local capWidth = width - capStart
        if capWidth > 0 then
            Theme.rect(owner, x + capStart, y, capWidth, height, COLOR_CAP)
            -- Shaded hatch lines (State of Decay style)
            local step = math.max(4, math.floor(height * 0.8))
            for hx = capStart, width, step do
                Theme.rect(owner, x + hx, y, 1, height, COLOR_CAP_HATCH)
            end
        end
    end

    -- 4. Threshold Marker
    if opts.threshold and opts.threshold > 0 and opts.threshold < 1.0 then
        local tx = x + math.floor(width * opts.threshold)
        Theme.rect(owner, tx, y - 1, 2, height + 2, COLOR_RED)
    end

    -- 5. Border Frame
    if not opts.plain then
        Chrome.roundedBorder(owner, x, y, width, height, opts.border or COLOR_BORDER)
    end

    -- 6. Label Overlay
    local text = opts.label
    if not text and opts.showPercent then
        text = math.floor(f * 100) .. "%"
    end
    if text and text ~= "" then
        if not cachedFontH then
            local tm = getTextManager and getTextManager()
            cachedFontH = (tm and tm:getFontHeight(UIFont.Small)) or 14
        end
        local tw = opts.labelW or UICache.measure(UIFont.Small, text)
        local h = cachedFontH
        local tx = x + math.floor((width - tw) / 2)
        local ty = y + math.floor((height - h) / 2)

        -- Micro shadow for maximum readability
        Theme.text(owner, text, tx + 1, ty + 1, COLOR_SHADOW)
        Theme.text(owner, text, tx, ty, Theme.textColor)
    end
end

---Create an interactive or self-contained ISPanel StatMeter.
---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table?
---@return EmberRoutesStatMeter
function StatMeter:new(x, y, width, height, opts)
    opts = opts or {}
    local o = ISPanel.new(self, x, y, width, height)
    o.background = false
    o.fontHeight = getTextManager():getFontHeight(UIFont.Small)
    o.pad = math.ceil(o.fontHeight * 0.4)
    o.fraction = opts.fraction or 0
    o.capFraction = opts.capFraction
    o.mode = opts.mode or "progress"
    o.customColor = opts.color
    o.threshold = opts.threshold
    o.label = opts.label
    o.labelW = 0
    o.fillW = 0
    o.activeColor = resolveColor(o.mode, o.fraction, o.customColor)
    o._drawOpts = {
        mode = o.mode,
        color = o.customColor,
        capFraction = o.capFraction,
        threshold = o.threshold,
        label = o.label,
        labelW = 0,
        plain = opts.plain
    }
    o:initialise()
    o:recompute()
    return o
end

function StatMeter:initialise()
    ISPanel.initialise(self)
end

function StatMeter:recompute()
    syncTheme()
    local f = math.max(0, math.min(1, self.fraction or 0))
    self.fillW = math.floor(self.width * f)
    self.activeColor = resolveColor(self.mode, f, self.customColor)
    if self.label and self.label ~= "" then
        self.labelW = UICache.measure(UIFont.Small, self.label)
    else
        self.labelW = 0
    end
    if self._drawOpts then
        self._drawOpts.mode = self.mode
        self._drawOpts.color = self.customColor
        self._drawOpts.capFraction = self.capFraction
        self._drawOpts.threshold = self.threshold
        self._drawOpts.label = self.label
        self._drawOpts.labelW = self.labelW
    end
end

---Update meter value and presentation.
---@param fraction number 0.0 to 1.0
---@param label string?
---@param capFraction number?
function StatMeter:setValue(fraction, label, capFraction)
    self.fraction = fraction or 0
    if label ~= nil then self.label = label end
    if capFraction ~= nil then self.capFraction = capFraction end
    self:recompute()
end

function StatMeter:prerender()
    ISPanel.prerender(self)
    StatMeter.draw(self, 0, 0, self.width, self.height, self.fraction, self._drawOpts)
end

return StatMeter
