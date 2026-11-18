--[[
    SkeletonView.lua - EmberRoutes UI
    Mechanism: Shimmer Pulsing Placeholder for Asynchronous Loading States.
    
    Architectural Compliance:
      - Sinusoidal Micro-Motion Shimmer (60FPS Zero-GC).
      - Zero table allocation per frame in render loop.
      - Primer / Radix UI Skeleton Parity: Cards, Lists, Texts, Avatars.
]]

local Theme = require 'EmberUI/Core/Theme'
local Chrome = require 'EmberUI/Core/Chrome'
local Clock = require 'EmberUI/Core/Clock'

local SkeletonView = {}

-- Pre-allocated color buffers synced to Theme.revision (Zero GC)
local SHIMMER_BASE   = { r = 0, g = 0, b = 0, a = 0.08 }
local SHIMMER_BORDER = { r = 0, g = 0, b = 0, a = 0.12 }
local SHIMMER_ACCENT = { r = 0, g = 0, b = 0, a = 0.15 }
local syncedRev = -1

local function syncTheme()
    local rev = Theme.revision or 0
    if syncedRev == rev then return end
    syncedRev = rev
    local base = Theme.muted or Theme.textColor
    local border = Theme.borderSubtle or Theme.border
    local accent = Theme.accent or base
    SHIMMER_BASE.r, SHIMMER_BASE.g, SHIMMER_BASE.b = base.r, base.g, base.b
    SHIMMER_BORDER.r, SHIMMER_BORDER.g, SHIMMER_BORDER.b = border.r, border.g, border.b
    SHIMMER_ACCENT.r, SHIMMER_ACCENT.g, SHIMMER_ACCENT.b = accent.r, accent.g, accent.b
end

syncTheme()

-- Mathematical parameters for the low-frequency sinusoidal breathing pulse
local PULSE_SPEED = 3.5 -- rad/s
local MIN_ALPHA = 0.05
local MAX_ALPHA = 0.17

---Calculates dynamic pulse alpha using smooth sine wave.
---@return number
local function getPulseAlpha()
    local t = (Clock.nowMs()) / 1000.0
    local sineVal = (math.sin(t * PULSE_SPEED) + 1.0) / 2.0 -- 0.0 to 1.0
    return MIN_ALPHA + sineVal * (MAX_ALPHA - MIN_ALPHA)
end

---Draws a rectangular skeleton shimmer block.
---@param owner ISPanel
---@param arg2 number|table
---@param y number?
---@param width number?
---@param height number?
function SkeletonView.rect(owner, arg2, y, width, height)
    local x, w, h
    if type(arg2) == "table" then
        x, y, w, h = arg2.x or 0, arg2.y or 0, arg2.width or 0, arg2.height or 0
    else
        x, w, h = arg2 or 0, width or 0, height or 0
    end
    if not owner or w <= 0 or h <= 0 then return end
    syncTheme()
    local a = getPulseAlpha()
    SHIMMER_BASE.a = a
    SHIMMER_BORDER.a = a * 1.5
    SHIMMER_ACCENT.a = a * 0.65
    Chrome.roundedRect(owner, x, y, w, h, SHIMMER_BASE, SHIMMER_BORDER)
    if w > 8 and h > 4 then
        Chrome.hGradient(owner, x + 1, y + 1, math.min(w - 2, math.max(16, math.floor(w * 0.45))), h - 2, SHIMMER_ACCENT, 0.55)
    end
end

---Draws a pill-shaped or rounded text line skeleton slot.
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number?
function SkeletonView.text(owner, x, y, width, height)
    if not owner or width <= 0 then return end
    syncTheme()
    local h = height or 12
    local a = getPulseAlpha()
    SHIMMER_BASE.a = a
    Chrome.roundedFill(owner, x, y, width, h, SHIMMER_BASE)
end

---Draws a circular/octagonal avatar skeleton slot.
---@param owner ISPanel
---@param cx number
---@param cy number
---@param radius number
function SkeletonView.avatar(owner, cx, cy, radius)
    if not owner or radius <= 0 then return end
    syncTheme()
    local size = radius * 2
    local x = cx - radius
    local y = cy - radius
    local a = getPulseAlpha()
    SHIMMER_ACCENT.a = a * 1.3
    SHIMMER_BORDER.a = a * 1.6
    Chrome.roundedRect(owner, x, y, size, size, SHIMMER_ACCENT, SHIMMER_BORDER)
end

---Draws a composite card skeleton (header bar + 2 content lines).
---@param owner ISPanel
---@param arg2 number|table
---@param y number?
---@param width number?
---@param height number?
function SkeletonView.card(owner, arg2, y, width, height)
    local x, w, h
    if type(arg2) == "table" then
        x, y, w, h = arg2.x or 0, arg2.y or 0, arg2.width or 0, arg2.height or 0
    else
        x, w, h = arg2 or 0, width or 0, height or 0
    end
    if not owner or w <= 0 or h <= 0 then return end
    SkeletonView.rect(owner, x, y, w, h)

    local pad = 12
    local innerW = math.max(20, w - pad * 2)
    local curY = y + pad

    -- Header line (60% width)
    SkeletonView.text(owner, x + pad, curY, math.floor(innerW * 0.6), 14)
    curY = curY + 22

    -- Divider line
    local a = getPulseAlpha() * 0.8
    SHIMMER_BORDER.a = a
    Theme.rect(owner, x + pad, curY, innerW, 1, SHIMMER_BORDER)
    curY = curY + 8

    -- Detail line 1 (90% width)
    if curY + 12 <= y + h - pad then
        SkeletonView.text(owner, x + pad, curY, math.floor(innerW * 0.9), 12)
        curY = curY + 18
    end

    -- Detail line 2 (45% width)
    if curY + 12 <= y + h - pad then
        SkeletonView.text(owner, x + pad, curY, math.floor(innerW * 0.45), 12)
    end
end

---Draws a composite list skeleton filled with rows up to the container height.
---@param owner ISPanel
---@param arg2 number|table
---@param y number?
---@param width number?
---@param height number?
---@param rowHeight number?
---@param maxRows number?
function SkeletonView.list(owner, arg2, arg3, arg4, arg5, arg6, arg7)
    local x, y, w, h, rH, count, gap
    if type(arg2) == "table" then
        x, y, w, h = arg2.x or 0, arg2.y or 0, arg2.width or 0, arg2.height or 0
        if arg5 ~= nil then
            count, rH, gap = arg3, arg4 or 36, arg5
        elseif arg3 and arg3 >= 16 and (not arg4 or arg4 < arg3) then
            rH, count, gap = arg3, arg4, 4
        else
            count, rH, gap = arg3, arg4 or 36, 4
        end
    else
        x, y, w, h = arg2 or 0, arg3 or 0, arg4 or 0, arg5 or 0
        rH = arg6 or 36
        count = arg7
        gap = 4
    end
    if not owner or w <= 0 or h <= 0 or rH <= 0 then return end
    local pad = 8
    count = count or math.floor((h + gap) / (rH + gap))
    if count < 1 then count = 1 end

    local curY = y
    local innerW = math.max(20, w - pad * 2)

    for _ = 1, count do
        if curY + rH > y + h then break end

        -- Row outer frame
        SkeletonView.rect(owner, x, curY, w, rH)

        -- Content line (70% width)
        SkeletonView.text(owner, x + pad, curY + math.floor((rH - 12) / 2), math.floor(innerW * 0.70), 12)

        curY = curY + rH + gap
    end
end

return SkeletonView
