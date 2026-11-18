--[[
    ToastManager.lua - EmberUI Widgets
    Global Floating Non-Blocking Toast / Snackbar Notification Queue.

    B42 Engine Invariants:
      - Tight Bounding Box + Auto-Unmount: Never keeps a full-screen (0,0,sw,sh) element in
        UIManager.getUI(), which would otherwise make UIElement.isPointOver return false for
        all windows underneath and eat right-click hold aiming.
      - Mounts tightly around active toast stack only while #toastQueue > 0; immediately hides
        and removes itself from UIManager when the last toast expires or session resets.
      - Zero-GC Render & Pool: Pre-allocated toast pool + scalar alpha/offset math.
]]

require 'ISUI/ISUIElement'
local Theme = require 'EmberUI/Core/Theme'
local Chrome = require 'EmberUI/Core/Chrome'
local StatusVisual = require 'EmberUI/Widgets/StatusVisual'
local Clock = require 'EmberUI/Core/Clock'
local Text = require 'EmberUI/Core/Text'
local Runtime = require 'EmberUI/Core/Runtime'

---@class EmberRoutesToastManager:ISUIElement
local ToastManager = ISUIElement:derive('EmberRoutesToastManager')

local PALETTES = {
    info    = { bar = { r = 0, g = 0, b = 0, a = 1.00 }, bg = { r = 0, g = 0, b = 0, a = 0.96 }, border = { r = 0, g = 0, b = 0, a = 0.85 }, icon = "bullet" },
    success = { bar = { r = 0, g = 0, b = 0, a = 1.00 }, bg = { r = 0, g = 0, b = 0, a = 0.96 }, border = { r = 0, g = 0, b = 0, a = 0.85 }, icon = "done" },
    warning = { bar = { r = 0, g = 0, b = 0, a = 1.00 }, bg = { r = 0, g = 0, b = 0, a = 0.96 }, border = { r = 0, g = 0, b = 0, a = 0.85 }, icon = "blocked" },
    danger  = { bar = { r = 0, g = 0, b = 0, a = 1.00 }, bg = { r = 0, g = 0, b = 0, a = 0.96 }, border = { r = 0, g = 0, b = 0, a = 0.85 }, icon = "blocked" },
}

local textColorBuf = { r = 1, g = 1, b = 1, a = 1 }
local syncedRev = -1
local cachedFontH = nil

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
    local tones = {
        info    = Theme.info or Theme.accent,
        success = (Theme.status and Theme.status.READY) or Theme.accent,
        warning = Theme.gold or (Theme.status and Theme.status.UPDATING) or Theme.accent,
        danger  = (Theme.status and Theme.status.ERROR) or Theme.danger,
    }
    for key, pal in pairs(PALETTES) do
        local tone = tones[key]
        pal.bar.r, pal.bar.g, pal.bar.b = tone.r, tone.g, tone.b
        blendInto(pal.bg, card, tone, 0.14)
        blendInto(pal.border, border, tone, 0.55)
    end
end

syncPalettes()

local instance = nil
local mounted = false
local toastQueue = {}
local toastPool = {}
local MAX_TOASTS = 3
local TOAST_WIDTH = 340
local TOAST_HEIGHT = 34
local TOAST_GAP = 6
local BASE_Y = 20
local PAD_X = 6
local SLIDE_HEADROOM = 14

local function getScreenWidthSafe()
    local core = type(getCore) == "function" and getCore() or nil
    return (core and core.getScreenWidth and core:getScreenWidth()) or 1280
end

local function syncOverlayBounds(screenW)
    if not instance then return end
    local count = #toastQueue
    if count <= 0 then
        if mounted then
            mounted = false
            instance:setVisible(false)
            instance:removeFromUIManager()
        end
        return
    end
    local sw = screenW or getScreenWidthSafe()
    local w = TOAST_WIDTH + PAD_X * 2
    local h = SLIDE_HEADROOM + count * TOAST_HEIGHT + math.max(0, count - 1) * TOAST_GAP + 8
    local x = math.max(0, math.floor((sw - w) / 2))
    local y = math.max(0, BASE_Y - SLIDE_HEADROOM)
    instance:setX(x)
    instance:setY(y)
    instance:setWidth(w)
    instance:setHeight(h)
    if not mounted then
        mounted = true
        instance:setVisible(true)
        instance:addToUIManager()
        if instance.setAlwaysOnTop then instance:setAlwaysOnTop(true) end
    end
end

Runtime.onResolution(function(newW)
    if mounted then
        syncOverlayBounds(newW)
    end
end)

function ToastManager.getInstance()
    if instance then return instance end
    instance = ToastManager:new(0, BASE_Y, TOAST_WIDTH + PAD_X * 2, TOAST_HEIGHT + SLIDE_HEADROOM)
    instance:initialise()
    instance:instantiate()
    if instance.setWantMouseEvents then instance:setWantMouseEvents(false) end
    instance:setVisible(false)
    return instance
end

function ToastManager:new(x, y, width, height)
    local o = ISUIElement.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.wantMouseEvents = false
    o.keepOnScreen = false
    return o
end

function ToastManager:isPointOver() return false end
function ToastManager:isMouseOver() return false end
function ToastManager:onMouseDown() return false end
function ToastManager:onMouseUp() return false end
function ToastManager:onRightMouseDown() return false end
function ToastManager:onRightMouseUp() return false end

local function recycleToast(item)
    if item and #toastPool < 8 then
        toastPool[#toastPool + 1] = item
    end
end

local function pushToast(pType, message, durationMs)
    ToastManager.getInstance()
    local now = Clock.nowMs()
    local dur = durationMs or 3000

    if #toastQueue >= MAX_TOASTS then
        recycleToast(table.remove(toastQueue, 1))
    end

    local rawMsg = tostring(message or "")
    local clipped = Text.truncate(rawMsg, TOAST_WIDTH - 40, UIFont.Small)
    local item = table.remove(toastPool) or {}
    item.type = pType
    item.message = clipped
    item.startTime = now
    item.duration = dur
    toastQueue[#toastQueue + 1] = item
    syncOverlayBounds()
end

function ToastManager.info(message, duration) pushToast("info", message, duration) end
function ToastManager.success(message, duration) pushToast("success", message, duration) end
function ToastManager.warning(message, duration) pushToast("warning", message, duration) end
function ToastManager.danger(message, duration) pushToast("danger", message, duration) end

function ToastManager.clear()
    for i = #toastQueue, 1, -1 do
        recycleToast(toastQueue[i])
        toastQueue[i] = nil
    end
    syncOverlayBounds()
end

function ToastManager.reset()
    ToastManager.clear()
    instance = nil
    mounted = false
end

function ToastManager.isActive()
    return mounted and #toastQueue > 0
end

function ToastManager:prerender()
    if #toastQueue == 0 then
        if mounted then syncOverlayBounds() end
        return
    end
    syncPalettes()
    if not cachedFontH then
        local tm = type(getTextManager) == "function" and getTextManager() or nil
        cachedFontH = (tm and tm.getFontHeight and tm:getFontHeight(UIFont.Small)) or 14
    end

    local now = Clock.nowMs()
    local tc = Theme.textColor
    textColorBuf.r, textColorBuf.g, textColorBuf.b = tc.r, tc.g, tc.b

    local removedAny = false
    local i = 1
    while i <= #toastQueue do
        local toast = toastQueue[i]
        local elapsed = now - toast.startTime

        if elapsed >= toast.duration then
            recycleToast(table.remove(toastQueue, i))
            removedAny = true
        else
            local alpha = 1.0
            local yOffset = 0

            if elapsed < 200 then
                local frac = math.max(0, elapsed / 200)
                alpha = frac
                yOffset = math.floor((1.0 - frac) * -12)
            elseif elapsed > (toast.duration - 400) then
                local frac = (toast.duration - elapsed) / 400
                alpha = math.max(0.0, math.min(1.0, frac))
            end

            local toastX = PAD_X
            local targetY = SLIDE_HEADROOM + (i - 1) * (TOAST_HEIGHT + TOAST_GAP) + yOffset
            local pal = PALETTES[toast.type] or PALETTES.info

            pal.bg.a = alpha * 0.96
            pal.border.a = alpha * 0.85
            pal.bar.a = alpha * 1.00

            Chrome.roundedRect(self, toastX, targetY, TOAST_WIDTH, TOAST_HEIGHT, pal.bg, pal.border)
            Chrome.hGradient(self, toastX + 4, targetY + 1, 72, TOAST_HEIGHT - 2, pal.bar, alpha * 0.08)
            Theme.rect(self, toastX + 1, targetY + 4, 3, TOAST_HEIGHT - 8, pal.bar)

            local iconSize = 14
            local iconY = targetY + math.floor((TOAST_HEIGHT - iconSize) / 2)
            StatusVisual.mark(self, toastX + 10, iconY, iconSize, pal.icon, pal.bar)

            local textX = toastX + 30
            local textY = targetY + math.floor((TOAST_HEIGHT - cachedFontH) / 2)
            textColorBuf.a = alpha
            Theme.text(self, toast.message, textX, textY, textColorBuf, UIFont.Small)

            i = i + 1
        end
    end

    if removedAny then
        syncOverlayBounds()
    end
end

return ToastManager
