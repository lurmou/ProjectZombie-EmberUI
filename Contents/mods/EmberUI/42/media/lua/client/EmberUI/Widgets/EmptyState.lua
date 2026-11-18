--[[
    EmptyState.lua - EmberRoutes UI
    Mechanism: Industrial Blankslate & Zero-Data Instructional Placeholder.
    
    Architectural Compliance:
      - GitHub Primer Blankslate Parity: Large Octicon + High-Contrast Title + Muted Guidance.
      - Zero-GC Invariant: Static scalar colors, pre-calculated text measurements.
      - Dynamic Centering: Adapts smoothly to arbitrary container dimensions.
      - Embedded Action Support: Optional CTA (Call-to-Action) button coordination & hit-testing.
]]

local Theme = require 'EmberUI/Core/Theme'
local Chrome = require 'EmberUI/Core/Chrome'
local StatusVisual = require 'EmberUI/Widgets/StatusVisual'
local Text = require 'EmberUI/Core/Text'
local UICache = require 'EmberUI/Core/UICache'

local EmptyState = {}

-- Pre-allocated mutable scalar color buffers synced to Theme.revision (Zero GC)
local ICON_COLOR   = {r = 0, g = 0, b = 0, a = 0.45}
local HINT_COLOR   = {r = 0, g = 0, b = 0, a = 0.80}
local BTN_BG       = {r = 0, g = 0, b = 0, a = 0.90}
local BTN_BORDER   = {r = 0, g = 0, b = 0, a = 0.90}
local BTN_HOVER_BG = {r = 0, g = 0, b = 0, a = 0.96}
local syncedRev = -1

local function syncTheme()
    local rev = Theme.revision or 0
    if syncedRev == rev then return end
    syncedRev = rev
    local muted = Theme.muted or Theme.textColor
    local ctrl = Theme.control or Theme.card or Theme.panel
    local border = Theme.border
    local hover = Theme.hover or ctrl
    ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b = muted.r, muted.g, muted.b
    HINT_COLOR.r, HINT_COLOR.g, HINT_COLOR.b = muted.r, muted.g, muted.b
    BTN_BG.r, BTN_BG.g, BTN_BG.b = ctrl.r, ctrl.g, ctrl.b
    BTN_BORDER.r, BTN_BORDER.g, BTN_BORDER.b = border.r, border.g, border.b
    BTN_HOVER_BG.r, BTN_HOVER_BG.g, BTN_HOVER_BG.b = hover.r, hover.g, hover.b
end

syncTheme()

---Draws an industrial empty state placeholder vertically and horizontally centered.
---@param owner ISPanel
---@param bounds table {x=number, y=number, width=number, height=number}
---@param opts table {icon=string?, iconSize=number?, title=string, hint=string?, hintLines=string[]?, fontHeight=number?, action=string?}
function EmptyState.draw(owner, bounds, opts)
    if not owner or not bounds or bounds.width <= 0 or bounds.height <= 0 then return end
    syncTheme()
    opts = opts or {}

    local iconName = opts.icon or "box"
    local title = opts.title or ""
    local hint = opts.hint or ""
    local action = opts.action
    local iconSize = opts.iconSize or 32

    local tm = getTextManager()
    local fontH = opts.fontHeight
    if not fontH then
        fontH = tm and tm:getFontHeight(UIFont.Small) or 14
    end
    local titleW = tm and UICache.measure(UIFont.Small, title) or (#title * 8)

    -- Calculate total stack height
    local totalContentH = iconSize + 10 + fontH
    local hintLines = opts.hintLines
    if hintLines then
        if #hintLines > 0 then
            totalContentH = totalContentH + 6 + #hintLines * fontH
        end
    elseif hint and hint ~= "" then
        local maxTextW = math.max(60, bounds.width - 40)
        hintLines = Text.wrapWordsLimited(hint, maxTextW, UIFont.Small, 2)
        totalContentH = totalContentH + 6 + #hintLines * fontH
    end

    local btnH = 24
    local btnW = 0
    if action and action ~= "" then
        btnW = (tm and UICache.measure(UIFont.Small, action) or (#action * 8)) + 24
        totalContentH = totalContentH + 14 + btnH
    end

    local startY = bounds.y + math.floor((bounds.height - totalContentH) / 2)
    local centerX = bounds.x + math.floor(bounds.width / 2)

    -- 1. Large Primer Octicon Centerpiece
    local iconX = centerX - math.floor(iconSize / 2)
    StatusVisual.icon(owner, iconX, startY, iconSize, iconName, ICON_COLOR)

    -- 2. Title Text
    local titleY = startY + iconSize + 10
    local titleX = centerX - math.floor(titleW / 2)
    Theme.text(owner, title, titleX, titleY, Theme.textColor, UIFont.Small)

    -- 3. Muted Guidance Subtext
    local curY = titleY + fontH
    if hintLines and #hintLines > 0 then
        curY = curY + 6
        for _, line in ipairs(hintLines) do
            local lineW = tm and UICache.measure(UIFont.Small, line) or (#line * 7)
            Theme.text(owner, line, centerX - math.floor(lineW / 2), curY, HINT_COLOR, UIFont.Small)
            curY = curY + fontH
        end
    end

    -- 4. Interactive Call-To-Action (CTA) Pill Button
    if action and action ~= "" then
        local btnX = centerX - math.floor(btnW / 2)
        local btnY = curY + 12

        local isHover = false
        if owner.getMouseX and owner.getMouseY then
            local mx, my = owner:getMouseX(), owner:getMouseY()
            if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
                isHover = true
            end
        end

        local hoverBorder = Theme.borderFocus or Theme.accent
        Chrome.roundedRect(owner, btnX, btnY, btnW, btnH, isHover and BTN_HOVER_BG or BTN_BG, isHover and hoverBorder or BTN_BORDER)
        if isHover then
            Chrome.hGradient(owner, btnX + 2, btnY + 1, math.max(0, btnW - 4), math.max(0, btnH - 2), hoverBorder, 0.12)
        end
        local tw = tm and UICache.measure(UIFont.Small, action) or (#action * 8)
        local tx = btnX + math.floor((btnW - tw) / 2)
        local ty = btnY + math.floor((btnH - fontH) / 2)
        Theme.text(owner, action, tx, ty, isHover and hoverBorder or Theme.textColor, UIFont.Small)

        -- Cache button bounds for zero-allocation hit testing
        local b = bounds._emptyActionBtn
        if not b then
            b = {x = btnX, y = btnY, width = btnW, height = btnH, visible = true}
            bounds._emptyActionBtn = b
        else
            b.x = btnX
            b.y = btnY
            b.width = btnW
            b.height = btnH
            b.visible = true
        end
    elseif bounds._emptyActionBtn then
        bounds._emptyActionBtn.visible = false
    end
end

---Autonomous Hit-Testing for EmptyState Action Button
---@param bounds table
---@param lx number Local container X
---@param ly number Local container Y
---@return boolean
function EmptyState.hitTest(bounds, lx, ly)
    local btn = bounds and bounds._emptyActionBtn
    if not btn or not btn.visible then return false end
    return lx >= btn.x and lx <= btn.x + btn.width and ly >= btn.y and ly <= btn.y + btn.height
end

return EmptyState
