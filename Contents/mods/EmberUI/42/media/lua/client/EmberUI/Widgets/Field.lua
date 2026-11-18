--[[
    Field.lua - EmberUI Widgets
    Declarative form field binding label + input control + FormValidator validation feedback.
    Eliminates manual FormValidator error border drawing and error caption wiring in pages.
]]

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"
local FormValidator = require "EmberUI/Widgets/FormValidator"
local ToggleSwitch = require "EmberUI/Widgets/ToggleSwitch"
local StepperInput = require "EmberUI/Widgets/StepperInput"

---@class EmberUIField:ISPanel
local Field = ISPanel:derive("EmberUIField")

---@param x number
---@param y number
---@param width number
---@param height number?
---@param opts table { label=string, labelWidth=number?, type="input"|"switch"|"stepper"|"custom", control=ISUIElement?, value=any, rules=table?, min=number?, max=number?, steps=number[]?, placeholder=string?, maxLength=number?, onlyNumbers=boolean?, masked=boolean?, onChange=fun(val:any, field:EmberUIField)? }
---@return EmberUIField
function Field:new(x, y, width, height, opts)
    opts = opts or {}
    local tm = type(getTextManager) == "function" and getTextManager() or nil
    local fh = (tm and tm.getFontHeight and tm:getFontHeight(UIFont.Small)) or 14
    local baseH = opts.errorHeight or (fh + 10)
    local h = height or (baseH + 18)
    local o = ISPanel.new(self, x, y, width, h)
    setmetatable(o, self)
    self.__index = self

    o.background = false
    o.label = opts.label or ""
    o.labelWidth = opts.labelWidth or 136
    o.fieldType = opts.type or (opts.control and "custom" or "input")
    o.rules = opts.rules
    o.value = opts.value
    o.onChange = opts.onChange
    o.opts = opts
    o.errorText = nil
    o.controlHeight = opts.controlHeight or math.max(22, fh + 8)
    o.fontHeight = fh
    o._pendingControl = opts.control
    o._valData = { value = o.value }
    o._valSchema = { value = o.rules }
    o:initialise()
    return o
end

function Field:initialise()
    ISPanel.initialise(self)
end

function Field:createChildren()
    ISPanel.createChildren(self)
    local cx = self.labelWidth + 8
    local cw = math.max(40, (self.width or 280) - cx)
    local ch = self.controlHeight
    local opts = self.opts or {}

    if self.fieldType == "custom" and self._pendingControl then
        self.control = self._pendingControl
        self.control:setX(cx)
        self.control:setY(0)
        self.control:setWidth(cw)
        self.control:setHeight(ch)
        self:addChild(self.control)
    elseif self.fieldType == "switch" then
        self.control = ToggleSwitch:new(cx, 0, nil, ch, self.value == true, self, function(_, checked)
            self:setValue(checked, false)
        end)
        self:addChild(self.control)
    elseif self.fieldType == "stepper" then
        local minV = opts.min ~= nil and opts.min or 0
        local maxV = opts.max ~= nil and opts.max or 9999
        local numVal = tonumber(self.value) or minV
        self.control = StepperInput:new(cx, 0, cw, ch, numVal, minV, maxV, opts.steps, function(val)
            self:setValue(val, false)
        end)
        self:addChild(self.control)
    else
        local entry = ISTextEntryBox:new(tostring(self.value or ""), cx, 0, cw, ch)
        entry:initialise()
        entry:instantiate()
        if opts.placeholder and entry.setPlaceholderText then entry:setPlaceholderText(opts.placeholder) end
        if opts.masked and entry.setMasked then entry:setMasked(true) end
        if opts.onlyNumbers and entry.setOnlyNumbers then entry:setOnlyNumbers(true) end
        if type(opts.maxLength) == "number" and entry.setMaxTextLength then entry:setMaxTextLength(opts.maxLength) end
        Theme.input(entry)
        local origChange = entry.onTextChange
        entry.onTextChange = function(box)
            if origChange then origChange(box) end
            self:setValue(box:getText(), false)
        end
        self:addChild(entry)
        self.control = entry
    end
end

function Field:getValue()
    if self.fieldType == "input" and self.control and self.control.getText then
        self.value = self.control:getText()
    elseif self.fieldType == "switch" and self.control and self.control.isChecked then
        self.value = self.control:isChecked()
    elseif self.fieldType == "stepper" and self.control and self.control.value ~= nil then
        self.value = self.control.value
    end
    return self.value
end

function Field:setValue(val, silent)
    self.value = val
    if self.rules then
        self:validate()
    end
    if not silent and type(self.onChange) == "function" then
        self.onChange(self.value, self)
    end
end

function Field:validate()
    if not self.rules then
        self.errorText = nil
        return true
    end
    self._valData.value = self:getValue()
    self._valSchema.value = self.rules
    local ok, err = FormValidator.validate(self._valData, self._valSchema)
    self.errorText = ok and nil or err
    return ok, err
end

local function syncControlBounds(self)
    if self.control and self.fieldType ~= "switch" then
        local cx = self.labelWidth + 8
        local cw = math.max(40, (self.width or 280) - cx)
        self.control:setX(cx)
        self.control:setWidth(cw)
    end
end

function Field:setWidth(w)
    ISPanel.setWidth(self, w)
    syncControlBounds(self)
end

function Field:onResize()
    ISPanel.onResize(self)
    syncControlBounds(self)
end

function Field:prerender()
    ISPanel.prerender(self)
    local fh = self.fontHeight or 14
    local ly = math.floor((self.controlHeight - fh) / 2)
    local clippedLabel = Text.truncate(self.label, math.max(24, self.labelWidth), UIFont.Small)
    Theme.text(self, clippedLabel, 0, ly, self.errorText and Theme.danger or Theme.textColor)
    if self.errorText and self.control then
        Chrome.roundedBorder(self, self.control:getX() - 1, -1, self.control:getWidth() + 2, self.controlHeight + 2, Theme.danger)
        local maxErrW = math.max(32, (self.width or 280) - (self.labelWidth + 8))
        local clippedErr = Text.truncate(self.errorText, maxErrW, UIFont.Small)
        Theme.text(self, clippedErr, self.labelWidth + 8, self.controlHeight + 2, Theme.danger)
    end
end

return Field
