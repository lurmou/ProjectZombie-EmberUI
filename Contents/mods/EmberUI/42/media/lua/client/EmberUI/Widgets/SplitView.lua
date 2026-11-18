--[[
    SplitView.lua - EmberUI Widgets
    Interactive draggable two-pane split container with min/max constraints,
    double-click ratio reset, resize clamping, and Zero-GC render.
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Clock = require "EmberUI/Core/Clock"

---@class EmberUISplitView:ISPanel
---@field orientation string "horizontal" | "vertical"
---@field ratio number
---@field defaultRatio number
---@field minFirst number
---@field minSecond number
---@field handleSize number
local SplitView = ISPanel:derive("EmberUISplitView")

local DOUBLE_CLICK_MS = 380

---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table? { orientation="horizontal"|"vertical", ratio=number, defaultRatio=number, minFirst=number, minSecond=number, handleSize=number, first=ISUIElement?, second=ISUIElement?, onRatioChange=fun(ratio:number, view:table)? }
---@return EmberUISplitView
function SplitView:new(x, y, width, height, opts)
    local o = ISPanel.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    opts = opts or {}
    o.background = false
    o.orientation = (opts.orientation == "vertical") and "vertical" or "horizontal"
    o.defaultRatio = opts.defaultRatio or opts.ratio or 0.34
    o.ratio = opts.ratio or o.defaultRatio
    o.minFirst = opts.minFirst or 120
    o.minSecond = opts.minSecond or 160
    o.handleSize = opts.handleSize or 6
    o.onRatioChange = opts.onRatioChange
    o.firstPane = nil
    o.secondPane = nil
    o.dragging = false
    o.hoverHandle = false
    o._lastHandleClickMs = -1
    o._handlePos = 0

    o:initialise()
    if opts.first then o:setFirst(opts.first) end
    if opts.second then o:setSecond(opts.second) end
    return o
end

function SplitView:initialise()
    ISPanel.initialise(self)
end

function SplitView:clampRatio(r)
    local total = (self.orientation == "vertical") and (self.height or 0) or (self.width or 0)
    local usable = math.max(1, total - self.handleSize)
    local minR = math.min(0.85, self.minFirst / usable)
    local maxR = math.max(minR, 1.0 - (self.minSecond / usable))
    if maxR < minR then
        return 0.5
    end
    return math.max(minR, math.min(maxR, r or 0.5))
end

function SplitView:setRatio(r, silent)
    local clamped = self:clampRatio(r)
    local changed = math.abs(clamped - (self.ratio or 0)) > 0.001
    self.ratio = clamped
    self:syncBounds()
    if changed and not silent and type(self.onRatioChange) == "function" then
        self.onRatioChange(self.ratio, self)
    end
end

function SplitView:setFirst(pane)
    if self.firstPane and self.firstPane ~= pane then
        self:removeChild(self.firstPane)
    end
    self.firstPane = pane
    if pane then
        assert(type(pane) == "table" and type(pane.instantiate) == "function", "SPLITVIEW_FIRST_INVALID_ELEMENT")
        self:addChild(pane)
        self:syncBounds()
    end
end

function SplitView:setSecond(pane)
    if self.secondPane and self.secondPane ~= pane then
        self:removeChild(self.secondPane)
    end
    self.secondPane = pane
    if pane then
        assert(type(pane) == "table" and type(pane.instantiate) == "function", "SPLITVIEW_SECOND_INVALID_ELEMENT")
        self:addChild(pane)
        self:syncBounds()
    end
end

function SplitView:setActivation(scope)
    self:syncBounds()
    if self.firstPane and type(self.firstPane.setActivation) == "function" then
        self.firstPane:setActivation(scope)
    end
    if self.secondPane and type(self.secondPane.setActivation) == "function" then
        self.secondPane:setActivation(scope)
    end
end

function SplitView:deactivate()
    if self.firstPane and type(self.firstPane.deactivate) == "function" then
        self.firstPane:deactivate()
    end
    if self.secondPane and type(self.secondPane.deactivate) == "function" then
        self.secondPane:deactivate()
    end
end

function SplitView:dispose()
    if self.firstPane and type(self.firstPane.dispose) == "function" then
        pcall(self.firstPane.dispose, self.firstPane)
    end
    if self.secondPane and type(self.secondPane.dispose) == "function" then
        pcall(self.secondPane.dispose, self.secondPane)
    end
end

function SplitView:syncBounds()
    local w = self.width or 0
    local h = self.height or 0
    if w <= 0 or h <= 0 then return end

    -- Compute effective clamped ratio for current width/height without clobbering
    -- the preferred ratio when temporarily laid out at a smaller initial size.
    local clamped = self:clampRatio(self.ratio)
    local hs = self.handleSize

    if self.orientation == "vertical" then
        local usable = math.max(0, h - hs)
        local firstH = math.floor(usable * clamped)
        local secondY = firstH + hs
        local secondH = math.max(0, h - secondY)
        self._handlePos = firstH
        if self.firstPane then
            self.firstPane:setX(0)
            self.firstPane:setY(0)
            self.firstPane:setWidth(w)
            self.firstPane:setHeight(firstH)
            if self.firstPane.onResize then self.firstPane:onResize() end
        end
        if self.secondPane then
            self.secondPane:setX(0)
            self.secondPane:setY(secondY)
            self.secondPane:setWidth(w)
            self.secondPane:setHeight(secondH)
            if self.secondPane.onResize then self.secondPane:onResize() end
        end
    else
        local usable = math.max(0, w - hs)
        local firstW = math.floor(usable * clamped)
        local secondX = firstW + hs
        local secondW = math.max(0, w - secondX)
        self._handlePos = firstW
        if self.firstPane then
            self.firstPane:setX(0)
            self.firstPane:setY(0)
            self.firstPane:setWidth(firstW)
            self.firstPane:setHeight(h)
            if self.firstPane.onResize then self.firstPane:onResize() end
        end
        if self.secondPane then
            self.secondPane:setX(secondX)
            self.secondPane:setY(0)
            self.secondPane:setWidth(secondW)
            self.secondPane:setHeight(h)
            if self.secondPane.onResize then self.secondPane:onResize() end
        end
    end
end

function SplitView:setWidth(w)
    ISPanel.setWidth(self, w)
    self:syncBounds()
end

function SplitView:setHeight(h)
    ISPanel.setHeight(self, h)
    self:syncBounds()
end

function SplitView:onResize()
    ISPanel.onResize(self)
    self:syncBounds()
end

function SplitView:isOverHandle(x, y)
    if self.orientation == "vertical" then
        return y >= self._handlePos and y <= (self._handlePos + self.handleSize) and x >= 0 and x <= self.width
    end
    return x >= self._handlePos and x <= (self._handlePos + self.handleSize) and y >= 0 and y <= self.height
end

function SplitView:onMouseDown(x, y)
    if self:isOverHandle(x, y) then
        local now = Clock.nowMs()
        if self._lastHandleClickMs > 0 and (now - self._lastHandleClickMs) <= DOUBLE_CLICK_MS then
            self._lastHandleClickMs = -1
            self.dragging = false
            self:setRatio(self.defaultRatio, false)
            return true
        end
        self._lastHandleClickMs = now
        self.dragging = true
        return true
    end
    return false
end

function SplitView:onMouseMove(dx, dy)
    local mx = self.getMouseX and self:getMouseX() or -1
    local my = self.getMouseY and self:getMouseY() or -1
    self.hoverHandle = self:isOverHandle(mx, my)
    if self.dragging then
        if self.orientation == "vertical" then
            local usable = math.max(1, (self.height or 1) - self.handleSize)
            self:setRatio((my - self.handleSize * 0.5) / usable, false)
        else
            local usable = math.max(1, (self.width or 1) - self.handleSize)
            self:setRatio((mx - self.handleSize * 0.5) / usable, false)
        end
    end
end

function SplitView:onMouseUp()
    self.dragging = false
end

function SplitView:onMouseUpOutside()
    self.dragging = false
end

function SplitView:prerender()
    ISPanel.prerender(self)
    local active = self.dragging or self.hoverHandle
    local barColor = active and (Theme.accent or Theme.border) or (Theme.borderSubtle or Theme.border)
    if self.orientation == "vertical" then
        local py = self._handlePos + math.floor((self.handleSize - 2) / 2)
        Chrome.pill(self, math.max(8, math.floor(self.width * 0.35)), py, math.max(24, math.floor(self.width * 0.30)), 2, barColor)
    else
        local px = self._handlePos + math.floor((self.handleSize - 2) / 2)
        Chrome.pill(self, px, math.max(8, math.floor(self.height * 0.35)), 2, math.max(24, math.floor(self.height * 0.30)), barColor)
    end
end

return SplitView
