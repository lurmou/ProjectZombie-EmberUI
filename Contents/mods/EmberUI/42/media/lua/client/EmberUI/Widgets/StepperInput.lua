--[[
    StepperInput.lua - EmberRoutes UI
    Ergonomic numeric stepper input widget.
    Encapsulates [-10] [-1] [ Value ] [+1] [+10] with mouse-wheel support,
    bounds clamping, direct typing, and zero layout boilerplate.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
local LayoutSolver = require "EmberUI/Core/LayoutSolver"
local Theme = require "EmberUI/Core/Theme"

---@class EmberRoutesStepperInput:ISPanel
---@field fontHeight number
---@field pad number
---@field value number
---@field min number
---@field max number
---@field steps number[]
---@field entry ISTextEntryBox
---@field stepButtons ISButton[]
---@field onChange fun(value:number, widget:EmberRoutesStepperInput)
local StepperInput = ISPanel:derive("EmberRoutesStepperInput")

---@param x number
---@param y number
---@param width number
---@param height number
---@param initialValue number?
---@param min number?
---@param max number?
---@param steps number[]? Array of 4 deltas, e.g. {-5, -1, 1, 5}
---@param onChange fun(value:number, widget:EmberRoutesStepperInput)?
---@return EmberRoutesStepperInput
function StepperInput:new(x, y, width, height, initialValue, min, max, steps, onChange)
    local o = ISPanel.new(self, x, y, width, height)
    o.background = false
    o.fontHeight = getTextManager():getFontHeight(UIFont.Small)
    o.pad = math.ceil(o.fontHeight * 0.4)
    o.min = min or 1
    o.max = max or 9999
    o.value = math.max(o.min, math.min(o.max, initialValue or o.min))
    o.steps = steps or {-5, -1, 1, 5}
    o.onChange = onChange or function() end
    o.stepButtons = {}
    o:initialise()
    return o
end

function StepperInput:initialise()
    ISPanel.initialise(self)
end

local function applyRow(bounds, tracks, controls, gap)
    assert(LayoutSolver.tracks(bounds, tracks, { direction = "row", gap = gap }, controls))
end

function StepperInput:createChildren()
    ISPanel.createChildren(self)
    local h, p = self.fontHeight, self.pad
    local btnW = math.max(24, math.floor(h * 2.2))
    local gap = math.max(2, math.floor(p / 3))

    -- Decrement Button 1
    local d1 = self.steps[1] or -5
    local b1 = ISButton:new(0, 0, btnW, self.height, tostring(d1), self, function()
        self:applyDelta(d1)
    end)
    b1:initialise()
    Theme.button(b1)
    self:addChild(b1)
    self.stepButtons[1] = b1

    -- Decrement Button 2
    local d2 = self.steps[2] or -1
    local b2 = ISButton:new(0, 0, btnW, self.height, (d2 > 0 and "+" or "") .. tostring(d2), self, function()
        self:applyDelta(d2)
    end)
    b2:initialise()
    Theme.button(b2)
    self:addChild(b2)
    self.stepButtons[2] = b2

    -- Center Input
    local entryBox = ISTextEntryBox:new(tostring(self.value), 0, 0, 40, self.height)
    entryBox:initialise()
    entryBox:instantiate()
    if entryBox.setOnlyNumbers and entryBox.javaObject then
        entryBox:setOnlyNumbers(true)
    end
    entryBox.target = self
    Theme.input(entryBox)
    entryBox.onTextChangeFunction = function()
        if self.syncing then return end
        local text = entryBox:getText()
        local n = tonumber(text)
        if n and n==math.floor(n) and n>=self.min and n<=self.max then
            self.value = n
            if self.onChange then self.onChange(self.value, self) end
        else
            self.value = nil
            if self.onChange then self.onChange(nil, self) end
        end
    end
    self:addChild(entryBox)
    self.entry = entryBox

    -- Increment Button 1
    local d3 = self.steps[3] or 1
    local b3 = ISButton:new(0, 0, btnW, self.height, (d3 > 0 and "+" or "") .. tostring(d3), self, function()
        self:applyDelta(d3)
    end)
    b3:initialise()
    Theme.button(b3)
    self:addChild(b3)
    self.stepButtons[3] = b3

    -- Increment Button 2
    local d4 = self.steps[4] or 5
    local b4 = ISButton:new(0, 0, btnW, self.height, (d4 > 0 and "+" or "") .. tostring(d4), self, function()
        self:applyDelta(d4)
    end)
    b4:initialise()
    Theme.button(b4)
    self:addChild(b4)
    self.stepButtons[4] = b4

    self:_reflow()
end

function StepperInput:_reflow()
    if not self.entry or not self.stepButtons or #self.stepButtons < 4 then return end
    local w, h = self.width or 0, self.height or 0
    if w <= 0 or h <= 0 then return end

    local fh, p = self.fontHeight, self.pad
    local btnW = math.max(24, math.floor(fh * 2.2))
    local gap = math.max(2, math.floor(p / 3))
    local minEntryW = 16

    if not self._forceCompact and w >= btnW * 4 + gap * 4 + minEntryW then
        self.stepButtons[1]:setVisible(true)
        self.stepButtons[2]:setVisible(true)
        self.entry:setVisible(true)
        self.stepButtons[3]:setVisible(true)
        self.stepButtons[4]:setVisible(true)
        applyRow(
            { width = w, height = h },
            { { basis = btnW }, { basis = btnW }, { grow = 1 }, { basis = btnW }, { basis = btnW } },
            { self.stepButtons[1], self.stepButtons[2], self.entry, self.stepButtons[3], self.stepButtons[4] },
            gap
        )
        return
    end

    local buttonW = math.min(h, math.max(1, w / 4))
    local compactGap = gap
    if w < buttonW * 2 + compactGap * 2 then
        compactGap = math.max(0, math.min(compactGap, math.floor((w - 2) / 2)))
        buttonW = math.max(1, math.min(h, math.floor((w - compactGap * 2) / 2)))
    end
    if w < buttonW * 2 + compactGap * 2 then return end
    applyRow(
        { width = w, height = h },
        { { basis = buttonW }, { grow = 1 }, { basis = buttonW } },
        { self.stepButtons[2], self.entry, self.stepButtons[3] },
        compactGap
    )
    self.stepButtons[1]:setVisible(false)
    self.stepButtons[4]:setVisible(false)
    self.stepButtons[2]:setVisible(true)
    self.stepButtons[3]:setVisible(true)
    self.entry:setVisible(true)
end

function StepperInput:onResize()
    ISPanel.onResize(self)
    if self._layingOut then return end
    self:_reflow()
end

-- Compact layout uses the same controls and change callback, with no second stepper implementation.
function StepperInput:layoutCompact(width, height)
    self._forceCompact = true
    self._layingOut = true
    self:setWidth(width)
    self:setHeight(height)
    self._layingOut = false
    self:_reflow()
end

function StepperInput:applyDelta(delta)
    local cur = tonumber(self.entry:getText()) or self.value or self.min
    local nextVal = math.max(self.min, math.min(self.max, cur + delta))
    self:setValue(nextVal)
    if self.onChange then
        self.onChange(self.value, self)
    end
end

function StepperInput:setValue(n)
    local clamped = math.max(self.min, math.min(self.max, tonumber(n) or self.min))
    self.value = clamped
    if self.entry then
        self.syncing = true
        self.entry:setText(tostring(clamped))
        self.syncing = false
    end
end

function StepperInput:onMouseWheel(del)
    if not self.entry or not self.entry:isFocused() then return false end
    -- Scrolling up (del < 0) increments, scrolling down (del > 0) decrements
    local delta = (del < 0) and 1 or -1
    self:applyDelta(delta)
    return true
end

return StepperInput
