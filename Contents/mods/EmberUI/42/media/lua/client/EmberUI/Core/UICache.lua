-- EmberRoutes UI Performance Cache
-- Memoizes expensive JNI text measurement calls outside render loops.
-- All semantic colors live in EmberUI/Core/Theme.lua (single source of truth).
local UICache = {}

local measureCache = {}
local countWidthCache = {}

---@param countText string
---@return number
function UICache.measureCount(countText)
    if not countText or countText == "" then return 0 end
    local val = countWidthCache[countText]
    if not val then
        local tm = type(getTextManager) == "function" and getTextManager() or nil
        if tm and tm.MeasureStringX then
            val = tm:MeasureStringX(UIFont.Small, countText)
        else
            val = #countText * 8
        end
        countWidthCache[countText] = val
    end
    return val
end

---Memoized MeasureStringX for draw-loop text.
---@param font any
---@param text string?
---@return number
function UICache.measure(font, text)
    if text == nil then return 0 end
    local keyFont = font or (UIFont and UIFont.Small) or "Small"
    local byFont = measureCache[keyFont]
    if not byFont then
        byFont = {}
        measureCache[keyFont] = byFont
    end
    local width = byFont[text]
    if width == nil then
        local tm = type(getTextManager) == "function" and getTextManager() or nil
        if tm and tm.MeasureStringX then
            width = tm:MeasureStringX(keyFont, text)
        else
            width = #text * 8
        end
        byFont[text] = width
    end
    return width
end

function UICache.clear()
    measureCache = {}
    countWidthCache = {}
    local textMod = package and package.loaded and package.loaded["EmberUI/Core/Text"]
    if type(textMod) == "table" and type(textMod.clearCache) == "function" then
        textMod.clearCache()
    end
end

return UICache
