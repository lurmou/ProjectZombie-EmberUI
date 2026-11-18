--[[
    Failsafe.lua - EmberRoutes UI Core
    Circuit-breaker guard for UI render and interaction paths.
    Inspired by LFS UI Rethemed Core Failsafe: catches unexpected runtime
    failures once, logs once with stack trace, isolates the broken part,
    and renders a safe fallback card instead of bricking the dashboard.
]]

local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"

local Failsafe = {}

local failed = {}
local logged = {}

local function traceError(err)
    local msg = tostring(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(msg, 2)
    end
    return msg
end

local function labelText(key, fallback)
    if type(getTextOrNull) == "function" then
        local v = getTextOrNull("IGUI_EmberUI_UI_" .. key)
        if v and v ~= "" then return v end
    end
    return fallback
end

---Executes fn(...) inside an isolated error boundary keyed by `key`.
---Once `key` fails, subsequent calls short-circuit until `Failsafe.reset(key)`.
---@param key any
---@param fn function
---@return boolean ok
---@return any ...
function Failsafe.guard(key, fn, ...)
    if key ~= nil and failed[key] ~= nil then
        return false, failed[key]
    end
    if type(fn) ~= "function" then
        return false, "FAILSAFE_NON_FUNCTION"
    end

    local ok, r1, r2, r3, r4 = pcall(fn, ...)
    if ok then
        return true, r1, r2, r3, r4
    end

    local errStr = traceError(r1 or "unknown error")
    if key ~= nil then
        failed[key] = errStr
        if not logged[key] then
            logged[key] = true
            print("[EmberUI Failsafe] '" .. tostring(key) .. "' isolated after error:\n" .. errStr)
        end
    else
        print("[EmberUI Failsafe] isolated error:\n" .. errStr)
    end
    return false, errStr
end

---@param key any
---@return boolean
function Failsafe.hasFailed(key)
    return key ~= nil and failed[key] ~= nil
end

---@param key any
---@return string?
function Failsafe.errorOf(key)
    return key ~= nil and failed[key] or nil
end

---@param key any
function Failsafe.reset(key)
    if key == nil then return end
    failed[key] = nil
    logged[key] = nil
end

function Failsafe.clearAll()
    failed = {}
    logged = {}
end

---Draws a safe, Zero-GC diagnostic fallback panel for an isolated UI failure.
---@param owner any
---@param x number
---@param y number
---@param w number
---@param h number
---@param key any
---@param title string?
function Failsafe.drawFallback(owner, x, y, w, h, key, title)
    if not owner or w <= 0 or h <= 0 then return end
    local danger = Theme.danger or (Theme.status and Theme.status.ERROR)
    Chrome.roundedRect(owner, x, y, w, h, Theme.well or Theme.panel, danger)
    local barH = math.min(h, 26)
    Chrome.titleBar(owner, x + 1, y + 1, math.max(0, w - 2), math.max(1, barH - 1), Theme.titleBar or Theme.panel, danger, Theme.borderSubtle)

    local pad = 10
    local badgeSize = 14
    local by = y + math.floor((barH - badgeSize) / 2)
    Chrome.pill(owner, x + pad, by, badgeSize, badgeSize, danger)
    Theme.rect(owner, x + pad + 6, by + 3, 2, 5, Theme.well or Theme.panel)
    Theme.rect(owner, x + pad + 6, by + 10, 2, 2, Theme.well or Theme.panel)
    local head = title or labelText("FailsafeTitle", "UI section paused due to an error")
    local fh = getTextManager and getTextManager():getFontHeight(UIFont.Small) or 14
    Theme.text(owner, head, x + pad + badgeSize + 6, y + math.floor((barH - fh) / 2), danger)

    local bodyY = y + barH + 8
    if bodyY + fh <= y + h - 6 then
        local hint = labelText("FailsafeHint", "Isolated safely so other tabs keep working.")
        Theme.text(owner, hint, x + pad, bodyY, Theme.textColor)
        bodyY = bodyY + fh + 6
    end

    local err = key ~= nil and failed[key]
    if err and bodyY + fh <= y + h - 6 then
        local firstLine = tostring(err):match("^([^\r\n]+)") or tostring(err)
        local maxW = math.max(40, w - pad * 2)
        local clipped = Text.truncate and Text.truncate(firstLine, maxW, UIFont.Small) or firstLine
        Theme.text(owner, clipped, x + pad, bodyY, Theme.muted)
    end
end

return Failsafe
