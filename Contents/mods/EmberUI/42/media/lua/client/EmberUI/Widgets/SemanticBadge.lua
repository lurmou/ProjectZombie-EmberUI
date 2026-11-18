--[[
    SemanticBadge.lua - EmberUI Widgets
    High-contrast semantic state badges and extensible badge registry.
    Ships built-in UI status tiers (READY, ACTIVE, UPDATING, WARNING, ERROR, INFO, DISABLED)
    and exposes SemanticBadge.register(id, def) for consuming mods to register domain badges.
]]

local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"
local UICache = require "EmberUI/Core/UICache"
local Visual = require "EmberUI/Widgets/StatusVisual"

local SemanticBadge = {}

SemanticBadge.ICON_SLOT = 16

local function text(key, fallback)
    if key and type(getTextOrNull) == "function" then
        local value = getTextOrNull(key)
        if value and value ~= "" then return value end
    end
    return fallback or key or ""
end

local DEFINITIONS = {
    READY = {
        markState = "done",
        labelKey = "IGUI_EmberUI_Badge_ready",
        fallback = "READY",
        color = { r = 0.40, g = 0.92, b = 0.65, a = 1.0 },
        bg = { r = 0.10, g = 0.22, b = 0.16, a = 0.90 },
        border = { r = 0.25, g = 0.65, b = 0.45, a = 0.85 },
    },
    ACTIVE = {
        markState = "active",
        labelKey = "IGUI_EmberUI_Badge_active",
        fallback = "ACTIVE",
        color = { r = 0.35, g = 0.82, b = 1.00, a = 1.0 },
        bg = { r = 0.08, g = 0.18, b = 0.26, a = 0.90 },
        border = { r = 0.22, g = 0.56, b = 0.78, a = 0.85 },
    },
    UPDATING = {
        markState = "reconcile",
        labelKey = "IGUI_EmberUI_Badge_updating",
        fallback = "UPDATING",
        color = { r = 1.00, g = 0.78, b = 0.25, a = 1.0 },
        bg = { r = 0.25, g = 0.20, b = 0.08, a = 0.90 },
        border = { r = 0.70, g = 0.55, b = 0.18, a = 0.85 },
    },
    WARNING = {
        markState = "paused",
        labelKey = "IGUI_EmberUI_Badge_warning",
        fallback = "WARNING",
        color = { r = 0.95, g = 0.70, b = 0.25, a = 1.0 },
        bg = { r = 0.24, g = 0.18, b = 0.07, a = 0.90 },
        border = { r = 0.68, g = 0.50, b = 0.18, a = 0.85 },
    },
    ERROR = {
        markState = "blocked",
        labelKey = "IGUI_EmberUI_Badge_error",
        fallback = "ERROR",
        color = { r = 1.00, g = 0.42, b = 0.38, a = 1.0 },
        bg = { r = 0.28, g = 0.10, b = 0.10, a = 0.90 },
        border = { r = 0.75, g = 0.30, b = 0.28, a = 0.85 },
    },
    INFO = {
        markState = "bullet",
        labelKey = "IGUI_EmberUI_Badge_info",
        fallback = "INFO",
        color = { r = 0.44, g = 0.68, b = 0.98, a = 1.0 },
        bg = { r = 0.11, g = 0.17, b = 0.27, a = 0.90 },
        border = { r = 0.28, g = 0.46, b = 0.74, a = 0.85 },
    },
    DISABLED = {
        markState = "neutral",
        labelKey = "IGUI_EmberUI_Badge_disabled",
        fallback = "DISABLED",
        color = { r = 0.60, g = 0.64, b = 0.68, a = 0.85 },
        bg = { r = 0.14, g = 0.15, b = 0.17, a = 0.85 },
        border = { r = 0.35, g = 0.37, b = 0.40, a = 0.75 },
    },
}

---Register or override a named badge semantic preset (reusable by consuming mods).
---@param id string
---@param def table { markState:string?, labelKey:string?, label:string?, fallback:string?, color:table?, bg:table?, border:table? }
function SemanticBadge.register(id, def)
    assert(type(id) == "string" and id ~= "" and type(def) == "table", "BADGE_REGISTER_INVALID")
    DEFINITIONS[string.upper(id)] = def
end

---@param id string
function SemanticBadge.unregister(id)
    if type(id) == "string" then
        DEFINITIONS[string.upper(id)] = nil
    end
end

local FALLBACK_MARK_STATE = {
    DONE = "done",
    ACTIVE = "active",
    ERROR = "blocked",
    WARNING = "paused",
}

---@param state string
---@param labelOverride string?
---@return table
function SemanticBadge.resolve(state, labelOverride)
    local key = tostring(state or "INFO")
    local def = DEFINITIONS[key] or DEFINITIONS[string.upper(key)]
    if def then
        local txt = labelOverride or (def.label or text(def.labelKey, def.fallback or key))
        return {
            markState = def.markState or "neutral",
            displayText = txt,
            color = def.color or Theme.textColor,
            bg = def.bg or Theme.panel,
            border = def.border or Theme.border,
        }
    end
    local ms = FALLBACK_MARK_STATE[string.upper(key)] or "neutral"
    return {
        markState = ms,
        displayText = labelOverride or key,
        color = Theme.textColor,
        bg = Theme.panel,
        border = Theme.border,
    }
end

---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number
---@param state string
---@param opts table? {label=string, fontHeight=number, textWidth=number, markState=string, color=table, bg=table, border=table}
function SemanticBadge.draw(owner, x, y, width, height, state, opts)
    opts = opts or {}
    local resolved = SemanticBadge.resolve(state, opts.label)
    local bg = opts.bg or resolved.bg
    local border = opts.border or resolved.border
    local color = opts.color or resolved.color
    local markState = opts.markState or resolved.markState
    local label = opts.displayText or resolved.displayText

    Chrome.roundedRect(owner, x, y, width, height, bg, border)

    local pad = 6
    local markSize = math.min(math.max(10, height - 6), 14)
    local markX = x + pad
    local markY = y + math.floor((height - markSize) / 2)

    Visual.mark(owner, markX, markY, markSize, markState, color)

    local h = opts.fontHeight or getTextManager():getFontHeight(UIFont.Small)
    local availW = math.max(1, width - (pad * 2 + SemanticBadge.ICON_SLOT))
    local tw = opts.textWidth or UICache.measure(UIFont.Small, label)
    if tw > availW and Text.truncate then
        label = Text.truncate(label, availW, UIFont.Small)
        tw = UICache.measure(UIFont.Small, label)
    end
    local tx = markX + SemanticBadge.ICON_SLOT
    local ty = y + math.floor((height - h) / 2)
    Theme.text(owner, label, tx, ty, color)
end

return SemanticBadge
