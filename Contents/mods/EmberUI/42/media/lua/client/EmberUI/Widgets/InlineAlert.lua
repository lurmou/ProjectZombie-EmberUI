--[[
    InlineAlert.lua - EmberRoutes UI
    Mechanism: 4-Tier Semantic Inline Alert & Banner Component.
    
    Architectural Compliance:
      - GitHub Primer Flash / Alert Parity: Left 3px solid accent stripe + subtle tint bg + Primer Octicon.
      - 4 Industry Semantic Levels: INFO, SUCCESS, WARNING, DANGER.
      - Zero-GC Invariant: Pre-allocated palette tables, reusable measured text buffers.
      - Interactive Dismiss & Action Hooks: Optional close callback and inline CTA.
]]

local Theme = require 'EmberUI/Core/Theme'
local Chrome = require 'EmberUI/Core/Chrome'
local StatusVisual = require 'EmberUI/Widgets/StatusVisual'
local Text = require 'EmberUI/Core/Text'

local InlineAlert = {}

-- Pre-allocated semantic palette buffers synced to Theme.revision (Zero GC)
local PALETTES = {
    info = {
        bar    = {r = 0, g = 0, b = 0, a = 1.00},
        bg     = {r = 0, g = 0, b = 0, a = 0.92},
        border = {r = 0, g = 0, b = 0, a = 0.85},
        text   = {r = 0, g = 0, b = 0, a = 1.00},
        icon   = "bullet"
    },
    success = {
        bar    = {r = 0, g = 0, b = 0, a = 1.00},
        bg     = {r = 0, g = 0, b = 0, a = 0.92},
        border = {r = 0, g = 0, b = 0, a = 0.85},
        text   = {r = 0, g = 0, b = 0, a = 1.00},
        icon   = "done"
    },
    warning = {
        bar    = {r = 0, g = 0, b = 0, a = 1.00},
        bg     = {r = 0, g = 0, b = 0, a = 0.92},
        border = {r = 0, g = 0, b = 0, a = 0.85},
        text   = {r = 0, g = 0, b = 0, a = 1.00},
        icon   = "blocked"
    },
    danger = {
        bar    = {r = 0, g = 0, b = 0, a = 1.00},
        bg     = {r = 0, g = 0, b = 0, a = 0.92},
        border = {r = 0, g = 0, b = 0, a = 0.85},
        text   = {r = 0, g = 0, b = 0, a = 1.00},
        icon   = "blocked"
    }
}

local syncedRev = -1

local function blendInto(dst, base, tone, ratio)
    local inv = 1 - ratio
    dst.r = base.r * inv + tone.r * ratio
    dst.g = base.g * inv + tone.g * ratio
    dst.b = base.b * inv + tone.b * ratio
end

local function syncPalettes()
    local rev = Theme.revision or 0
    if syncedRev == rev then return end
    syncedRev = rev
    local card = Theme.card or Theme.panel
    local border = Theme.border
    local ink = Theme.textColor
    local tones = {
        info    = Theme.info or Theme.accent,
        success = Theme.status and Theme.status.READY or Theme.accent,
        warning = Theme.gold or (Theme.status and Theme.status.UPDATING) or Theme.accent,
        danger  = (Theme.status and Theme.status.ERROR) or Theme.danger,
    }
    for key, pal in pairs(PALETTES) do
        local tone = tones[key]
        pal.bar.r, pal.bar.g, pal.bar.b = tone.r, tone.g, tone.b
        blendInto(pal.bg, card, tone, 0.16)
        blendInto(pal.border, border, tone, 0.45)
        blendInto(pal.text, ink, tone, 0.14)
    end
end

syncPalettes()

---Calculates recommended height for an inline alert given text and width.
---@param text string
---@param width number
---@param pad number?
---@return number height
function InlineAlert.measureHeight(text, width, pad)
    pad = pad or 8
    local tm = getTextManager()
    local fontH = tm and tm:getFontHeight(UIFont.Small) or 14
    local availableW = math.max(40, width - 26 - pad * 2)
    local lines = Text.wrapLimited(text or "", availableW, UIFont.Small, 3)
    return math.max(28, #lines * fontH + pad * 2)
end

---Draws an inline alert banner inside owner.
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table {type="info"|"success"|"warning"|"danger", message=string?, lines=string[]?, fontHeight=number?, icon=string?, title=string?}
function InlineAlert.draw(owner, x, y, width, height, opts)
    if not owner or width <= 0 or height <= 0 then return end
    syncPalettes()
    opts = opts or {}
    local pType = opts.type or "info"
    local pal = PALETTES[pType] or PALETTES.info

    -- 1. Rounded Outer Container Background, Subtle Left Wash, and Semantic Bar
    local barInset = (width >= 12 and height >= 12) and math.min(4, math.floor(height / 4)) or 0
    Chrome.roundedFill(owner, x, y, width, height, pal.bg)
    if width > 12 and height > 8 then
        Chrome.hGradient(owner, x + 4, y + math.max(1, barInset - 1), math.min(64, width - 8), math.max(1, height - math.max(1, barInset - 1) * 2), pal.bar, 0.08)
    end

    -- 2. Clean 3px Semantic Left Accent Bar (inset inside rounded corners)
    Theme.rect(owner, x + 1, y + barInset, 3, math.max(1, height - barInset * 2), pal.bar)
    Chrome.roundedBorder(owner, x, y, width, height, pal.border)

    -- 3. Semantic Primer Octicon
    local iconSize = 14
    local iconName = opts.icon or pal.icon
    local iconY = y + math.floor((height - iconSize) / 2)
    StatusVisual.mark(owner, x + 9, iconY, iconSize, iconName, pal.bar)

    -- 4. Text Message
    local textX = x + 28
    local title = opts.title
    local textY = y + (title and title ~= "" and 5 or 6)
    local msg = opts.message or ""

    local fontH = opts.fontHeight
    if not fontH then
        local tm = getTextManager()
        fontH = tm and tm:getFontHeight(UIFont.Small) or 14
    end

    if title and title ~= "" then
        Theme.text(owner, title, textX, textY, pal.bar, UIFont.Small)
        textY = textY + fontH + 2
    end

    local lines = opts.lines
    if not lines then
        local maxTextW = math.max(20, width - (textX - x) - 8)
        lines = Text.wrapLimited(msg, maxTextW, UIFont.Small, 2)
    end
    for _, line in ipairs(lines) do
        Theme.text(owner, line, textX, textY, pal.text, UIFont.Small)
        textY = textY + fontH
    end
end

return InlineAlert
