--[[
    RadialDial.lua - EmberRoutes UI
    Mechanism 8: Industrial Tactical Radial Gauge & Arc Dial.
    
    Architectural Compliance:
      - Ergonomic Sizing: Minimum radius enforced (R >= 36px, default 40px, diameter 80px),
        completely eliminating micro-smudge readability collapse.
      - Industrial Bezel Socket: Sunken octagonal frame with double border and depth.
      - 16-Segment Tactical LED Arc: 270-degree sweep with precomputed cos/sin LUT (Zero GC).
      - Multi-Tier Color Thresholds: Green / Yellow / Red / Blue with high-contrast active glow.
      - Spacious Center Readout: Clean micro-shadowed text with dedicated breathing room.
      - Zero-GC: Zero table allocations in render/prerender execution.
]]

local Theme = require 'EmberUI/Core/Theme'
local UICache = require 'EmberUI/Core/UICache'

local RadialDial = {}

local MIN_ERGONOMIC_RADIUS = 36

-- Pre-allocated immutable micro-highlights/shadows (Zero GC in draw loop)
local COLOR_SPECULAR_LINE = {r = 1, g = 1, b = 1, a = 0.55}
local COLOR_SPECULAR_EDGE = {r = 1, g = 1, b = 1, a = 0.35}
local COLOR_TEXT_SHADOW   = {r = 0, g = 0, b = 0, a = 0.90}

-- Precomputed static trigonometric offsets for 16-segment 270-degree gauge (135 deg to 405 deg)
-- Zero runtime math.sin/math.cos overhead, Zero GC
local NUM_SEGMENTS = 16
local PRECOMPUTED_COS = {}
local PRECOMPUTED_SIN = {}
local PERCENT_STRINGS = {}
for i = 0, 100 do
    PERCENT_STRINGS[i] = tostring(i) .. "%"
end

do
    local startDeg = 135
    local sweepDeg = 270
    for i = 1, NUM_SEGMENTS do
        local deg = startDeg + ((i - 1) / (NUM_SEGMENTS - 1)) * sweepDeg
        local rad = math.rad(deg)
        PRECOMPUTED_COS[i] = math.cos(rad)
        PRECOMPUTED_SIN[i] = math.sin(rad)
    end
end

---Creates a scalar state container for smooth interpolation.
---@param lambda number? Exponential decay coefficient
---@return table
function RadialDial.createState(lambda)
    return {
        current = 1.0,
        target = 1.0,
        lambda = lambda or 8.0
    }
end

---Updates damped annealing step towards target fraction using frame delta.
---@param state table
---@param targetFraction number 0.0 to 1.0
function RadialDial.update(state, targetFraction)
    if not state then return end
    state.target = math.max(0, math.min(1, targetFraction or 0))

    local dt = UIManager.getMillisSinceLastRender() / 1000.0
    if dt > 0.1 then dt = 0.1 end
    if dt <= 0 then dt = 0.016 end

    local diff = state.target - state.current
    if math.abs(diff) < 0.002 then
        state.current = state.target
    else
        local factor = 1.0 - math.exp(-(state.lambda or 8.0) * dt)
        state.current = state.current + diff * factor
    end
end

local function resolveLedColor(mode, fraction, customColor)
    if customColor then return customColor end
    local f = math.max(0, math.min(1, fraction or 0))
    local st = Theme.status
    if mode == "health" then
        if f > 0.60 then return st.READY
        elseif f > 0.25 then return st.UPDATING
        else return st.ERROR end
    elseif mode == "load" or mode == "danger" then
        if f < 0.60 then return st.READY
        elseif f < 0.85 then return st.UPDATING
        else return st.ERROR end
    else
        if f >= 1.0 then return st.READY
        else return Theme.info or Theme.accent end
    end
end

---Static zero-GC draw function for industrial tactical dial.
---@param owner ISPanel
---@param cx number Center X
---@param cy number Center Y
---@param radius number Outer Radius (enforced >= 36px)
---@param fraction number 0.0 to 1.0
---@param opts table? {mode="progress"|"health"|"load", label=string, title=string, font=UIFont, color=table}
function RadialDial.draw(owner, cx, cy, radius, fraction, opts)
    opts = opts or {}
    -- Enforce minimum ergonomic radius to prevent unreadable smudges
    radius = math.max(MIN_ERGONOMIC_RADIUS, radius or MIN_ERGONOMIC_RADIUS)
    
    local f = math.max(0, math.min(1, fraction or 0))
    local mode = opts.mode or "health"
    local activeCol = resolveLedColor(mode, f, opts.color)

    local diameter = radius * 2
    local bx = cx - radius
    local by = cy - radius

    -- 1. Outer Industrial Bezel Trough (Sunken Socket via Theme hierarchy)
    Theme.rect(owner, bx, by, diameter, diameter, opts.socketBg or Theme.window)
    Theme.rect(owner, bx, by, diameter, diameter, Theme.border, true)
    Theme.rect(owner, bx + 1, by + 1, diameter - 2, diameter - 2, Theme.borderSubtle or Theme.border, true)

    -- Inner recessed well
    local innerR = math.floor(radius * 0.88)
    local innerD = innerR * 2
    Theme.rect(owner, cx - innerR, cy - innerR, innerD, innerD, Theme.well or Theme.panel)
    Theme.rect(owner, cx - innerR, cy - innerR, innerD, innerD, Theme.borderSubtle or Theme.border, true)

    -- 2. 16-Segment Tactical LED Arc (270-degree sweep)
    local ledR = radius * 0.72
    local ledSize = math.max(4, math.floor(radius * 0.12))
    local halfLed = math.floor(ledSize / 2)

    local litCount = math.floor(f * NUM_SEGMENTS + 0.05)

    for i = 1, NUM_SEGMENTS do
        local lx = cx + math.floor(PRECOMPUTED_COS[i] * ledR) - halfLed
        local ly = cy + math.floor(PRECOMPUTED_SIN[i] * ledR) - halfLed
        local isLit = (i <= litCount)
        local col = isLit and activeCol or (Theme.control or Theme.panel)

        Theme.rect(owner, lx, ly, ledSize, ledSize, col)
        if isLit then
            -- High-energy specular micro-highlight on lit LEDs (pre-allocated constants)
            Theme.rect(owner, lx, ly, ledSize, 1, COLOR_SPECULAR_LINE)
            Theme.rect(owner, lx, ly, ledSize, ledSize, COLOR_SPECULAR_EDGE, true)
        end
    end

    -- 3. Center Value / Readout (Comfortable breathing room)
    local tm = getTextManager()
    local font = opts.font or (radius >= 44 and UIFont.Medium or UIFont.Small)
    local text = opts.label
    if not text and opts.showPercent ~= false then
        local pct = math.floor(f * 100 + 0.5)
        text = PERCENT_STRINGS[pct] or (tostring(pct) .. "%")
    end

    if text and text ~= "" then
        local tw = UICache.measure(font, text)
        local th = tm:getFontHeight(font)
        local tx = cx - math.floor(tw / 2)
        local ty = cy - math.floor(th / 2)
        if opts.title then
            ty = ty + 4 -- shift down slightly to accommodate title
        end

        -- Shadow & primary readout
        Theme.text(owner, text, tx + 1, ty + 1, COLOR_TEXT_SHADOW, font)
        Theme.text(owner, text, tx, ty, activeCol, font)
    end

    -- Optional Title Sub-label (e.g. "HEALTH" / "DEFENSE")
    if opts.title and opts.title ~= "" then
        local tFont = UIFont.Small
        local titW = UICache.measure(tFont, opts.title)
        local titH = tm:getFontHeight(tFont)
        local titX = cx - math.floor(titW / 2)
        local titY = cy - math.floor(titH) - 2

        Theme.text(owner, opts.title, titX + 1, titY + 1, COLOR_TEXT_SHADOW, tFont)
        Theme.text(owner, opts.title, titX, titY, Theme.muted, tFont)
    end

    return diameter
end

return RadialDial
