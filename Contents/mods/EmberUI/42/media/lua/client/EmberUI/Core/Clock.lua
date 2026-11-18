--[[
    Clock.lua - EmberUI Core
    Monotonic millisecond timer for UI animations, debouncers, toasts, and double-click detection.
    Zero dependency on host mod kernels; supports test clock injection via Clock.setProvider(fn).
]]

local Clock = {}

local customProvider = nil
local frameFallbackMs = 0

---@param fn (fun():number)?
function Clock.setProvider(fn)
    customProvider = type(fn) == "function" and fn or nil
end

---@return number ms
function Clock.nowMs()
    if customProvider then
        return customProvider()
    end
    if type(getTimestampMs) == "function" then
        local ok, ms = pcall(getTimestampMs)
        if ok and type(ms) == "number" then return ms end
    end
    if UIManager and type(UIManager.getMillisSinceLastRender) == "function" then
        local ok, dt = pcall(UIManager.getMillisSinceLastRender, UIManager)
        if ok and type(dt) == "number" and dt > 0 and dt < 5000 then
            frameFallbackMs = frameFallbackMs + dt
            return frameFallbackMs
        end
    end
    if os and type(os.clock) == "function" then
        return math.floor(os.clock() * 1000)
    end
    frameFallbackMs = frameFallbackMs + 16
    return frameFallbackMs
end

return Clock
