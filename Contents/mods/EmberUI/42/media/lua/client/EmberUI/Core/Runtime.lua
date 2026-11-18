--[[
    Runtime.lua - EmberUI Core
    Global session teardown & screen-resolution lifecycle guardian.
    Ensures 3-element lifecycle closure across save reloads (OnMainMenuEnter)
    and window/fullscreen resizes (OnResolutionChange):
      1. Force-closes any still-mounted WindowHost / ModalDialog / ChoiceMenu in LIFO order.
      2. Resets ToastManager, HoverCard, TooltipManager, FocusManager, Failsafe,
         SlotRegistry session capabilities, and UICache/Text caches.
      3. Relays OnResolutionChange to tracked top-level surfaces and overlays.
]]

local FocusManager = require "EmberUI/Core/FocusManager"
local Failsafe = require "EmberUI/Core/Failsafe"
local TooltipManager = require "EmberUI/Core/TooltipManager"
local UICache = require "EmberUI/Core/UICache"
local SlotRegistry = require "EmberUI/Shell/SlotRegistry"

local Runtime = {}

local trackedSurfaces = {}
local resolutionListeners = {}
local hooksInstalled = false

---Tracks a top-level surface (WindowHost, ModalDialog, ChoiceMenu) for automatic
---session teardown and resolution-change notification.
---@param surface table
---@param opts table? { onResolutionChange = fun(surface, newW, newH)? }
---@return table handle { release = function }
function Runtime.trackSurface(surface, opts)
    if not surface then return { release = function() end } end
    local entry = {
        surface = surface,
        onResolutionChange = opts and opts.onResolutionChange or nil,
        released = false,
    }
    trackedSurfaces[#trackedSurfaces + 1] = entry
    return {
        release = function()
            if entry.released then return end
            entry.released = true
            for i = #trackedSurfaces, 1, -1 do
                if trackedSurfaces[i] == entry then
                    table.remove(trackedSurfaces, i)
                    break
                end
            end
        end,
    }
end

---@param fn fun(newW:number, newH:number, oldW:number?, oldH:number?)
---@return table handle { release = function }
function Runtime.onResolution(fn)
    assert(type(fn) == "function", "RUNTIME_RESOLUTION_FN_REQUIRED")
    resolutionListeners[#resolutionListeners + 1] = fn
    local live = true
    return {
        release = function()
            if not live then return end
            live = false
            for i = #resolutionListeners, 1, -1 do
                if resolutionListeners[i] == fn then
                    table.remove(resolutionListeners, i)
                    break
                end
            end
        end,
    }
end

---Notifies all tracked surfaces and overlays of a screen resolution change.
function Runtime.handleResolutionChange(oldW, oldH, newW, newH)
    local core = type(getCore) == "function" and getCore() or nil
    local w = tonumber(newW) or (core and core.getScreenWidth and core:getScreenWidth()) or 1280
    local h = tonumber(newH) or (core and core.getScreenHeight and core:getScreenHeight()) or 720

    for i = 1, #trackedSurfaces do
        local e = trackedSurfaces[i]
        if e and not e.released and e.surface and not e.surface.disposed then
            if type(e.onResolutionChange) == "function" then
                pcall(e.onResolutionChange, e.surface, w, h)
            end
        end
    end

    for i = 1, #resolutionListeners do
        pcall(resolutionListeners[i], w, h, oldW, oldH)
    end
end

---Tears down all active EmberUI overlays, windows, focus locks, tooltips, and caches.
function Runtime.resetSession()
    -- 1. Close tracked top-level surfaces in LIFO order
    for i = #trackedSurfaces, 1, -1 do
        local e = trackedSurfaces[i]
        if e and not e.released and e.surface and not e.surface.disposed then
            e.released = true
            if type(e.surface.close) == "function" then
                pcall(e.surface.close, e.surface, "SESSION_TEARDOWN")
            end
        end
    end
    trackedSurfaces = {}

    -- 2. Unfocus active native text entry if any
    if Core and type(Core.UnfocusActiveTextEntryBox) == "function" then
        pcall(Core.UnfocusActiveTextEntryBox)
    end

    -- 3. Reset lazy-loaded singleton overlays if loaded
    local loaded = package and package.loaded
    if type(loaded) == "table" then
        local toast = loaded["EmberUI/Widgets/ToastManager"]
        if type(toast) == "table" and type(toast.reset) == "function" then
            pcall(toast.reset)
        end
        local hover = loaded["EmberUI/Widgets/HoverCard"]
        if type(hover) == "table" and type(hover.reset) == "function" then
            pcall(hover.reset)
        end
    end

    -- 4. Reset core managers & ephemeral capabilities
    TooltipManager.clearAll()
    FocusManager.resetAll()
    Failsafe.clearAll()
    SlotRegistry.clearCapabilities()
    UICache.clear()
end

function Runtime.installHooks()
    if hooksInstalled then return end
    if type(Events) ~= "table" then return end
    hooksInstalled = true
    if Events.OnMainMenuEnter and type(Events.OnMainMenuEnter.Add) == "function" then
        Events.OnMainMenuEnter.Add(Runtime.resetSession)
    end
    if Events.OnResolutionChange and type(Events.OnResolutionChange.Add) == "function" then
        Events.OnResolutionChange.Add(Runtime.handleResolutionChange)
    end
end

Runtime.installHooks()

return Runtime
