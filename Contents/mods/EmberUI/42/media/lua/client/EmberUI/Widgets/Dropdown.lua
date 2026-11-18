--[[
    Dropdown.lua - EmberUI Widgets
    Encapsulated Flat 2.0 dropdown select component.
    Adheres to Theme palette, Flat 2.0 vector chevron, cached truncation, and Zero-GC rendering.
]]

require "ISUI/ISComboBox"
require "ISUI/ISScrollBar"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"
local Visual = require "EmberUI/Widgets/StatusVisual"

---@class EmberRoutesDropdown: ISComboBox
local Dropdown = ISComboBox:derive("EmberRoutesDropdown")

local ACTIVE_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local POPUP_TRANSPARENT = { r = 0, g = 0, b = 0, a = 0 }
local fontHeightCache = {}

local function getCachedFontHeight(font)
    local key = font or UIFont.Small
    local h = fontHeightCache[key]
    if h == nil then
        local tm = type(getTextManager) == "function" and getTextManager()
        h = (tm and tm.getFontHeight and tm:getFontHeight(key)) or 14
        fontHeightCache[key] = h
    end
    return h
end

function Dropdown:new(x, y, width, height, target, onChange)
    local o = ISComboBox.new(self, x, y, width, height, target, nil)
    setmetatable(o, self)
    self.__index = self

    o.userOnChange = onChange
    o.onChange = function(cbTarget, combo)
        local data = combo:getSelectedData()
        local txt = combo:getOptionText(combo.selected)
        if o.userOnChange then
            o.userOnChange(cbTarget, data, txt, combo)
        end
    end

    Theme.combo(o)
    return o
end

function Dropdown:initialise()
    ISComboBox.initialise(self)
    Theme.combo(self)
end

function Dropdown:showPopup()
    ISComboBox.showPopup(self)
    if self.popup then
        local popup = self.popup
        Theme.list(popup)
        if popup.vscroll then Theme.scrollbar(popup.vscroll) end
        if popup.hscroll then Theme.scrollbar(popup.hscroll) end
        popup.backgroundColor = Theme.window or Theme.panel
        popup.borderColor = Theme.borderFocus or Theme.border
        if type(popup.prerender) == "function" and not popup._emberChromeStyled then
            popup._emberChromeStyled = true
            popup.drawBorder = false
            local origPrerender = popup.prerender
            popup.prerender = function(p)
                local sy = p.getYScroll and p:getYScroll() or 0
                p.backgroundColor = POPUP_TRANSPARENT
                Chrome.roundedRect(p, 0, -sy, p.width, p.height, Theme.window or Theme.panel, Theme.borderFocus or Theme.border)
                origPrerender(p)
            end
        end
    end
end

function Dropdown:closePopup()
    if self.expanded then
        if self.hidePopup then
            self:hidePopup()
        end
        self.expanded = false
    end
end

function Dropdown:addOptionWithData(label, data)
    if ISComboBox.addOptionWithData then
        ISComboBox.addOptionWithData(self, label, data)
    else
        self.options = self.options or {}
        table.insert(self.options, { text = label, data = data })
    end
end

function Dropdown:setOptions(items, selectedId)
    self:clear()
    local targetIdx = (items and #items > 0) and 1 or 0
    for i, it in ipairs(items or {}) do
        local label, id
        if type(it) == "table" then
            label = it.label or tostring(it.id)
            if it.id ~= nil then
                id = it.id
            else
                id = it
            end
        else
            label = tostring(it)
            id = it
        end
        self:addOptionWithData(label, id)
        if selectedId ~= nil and id == selectedId then
            targetIdx = i
        end
    end
    self.selected = targetIdx
end

function Dropdown:getOptionText(index)
    if not self.options or not index or index <= 0 or index > #self.options then return "" end
    local opt = self.options[index]
    if type(opt) == "table" then
        return opt.text or ""
    elseif type(opt) == "string" then
        return opt
    end
    if ISComboBox.getOptionText then
        return ISComboBox.getOptionText(self, index) or ""
    end
    return ""
end

function Dropdown:getOptionData(index)
    if not self.options or not index or index <= 0 or index > #self.options then return nil end
    local opt = self.options[index]
    if type(opt) == "table" and opt.data ~= nil then
        return opt.data
    end
    if ISComboBox.getOptionData then
        return ISComboBox.getOptionData(self, index)
    end
    return nil
end

function Dropdown:getSelectedData()
    if not self.selected or self.selected <= 0 then return nil end
    return self:getOptionData(self.selected)
end

function Dropdown:setSelectedId(id)
    if not self.options then return false end
    for i = 1, #self.options do
        if self:getOptionData(i) == id then
            self.selected = i
            return true
        end
    end
    return false
end

function Dropdown:selectNext()
    if not self.options or #self.options == 0 then return end
    self.selected = (self.selected % #self.options) + 1
    if self.onChange then
        self.onChange(self.target, self)
    end
end

function Dropdown:selectPrev()
    if not self.options or #self.options == 0 then return end
    self.selected = (self.selected - 2 + #self.options) % #self.options + 1
    if self.onChange then
        self.onChange(self.target, self)
    end
end

function Dropdown:prerender()
    local isDisabled = self.enable == false or self.disabled == true
    local isFocused = (self.joypadFocused or self.isFocused == true) and not isDisabled
    local isHover = (not isDisabled) and self:isMouseOver()
    local isExpanded = self.expanded == true

    local bg = isDisabled and Theme.panel
        or (isExpanded and Theme.selected
        or (isHover and Theme.hover or (Theme.control or Theme.card)))
    local bc = isDisabled and (Theme.borderSubtle or Theme.border)
        or ((isExpanded or isFocused) and (Theme.borderFocus or Theme.accent)
        or (isHover and (Theme.hoverBorder or Theme.borderFocus or Theme.accent) or Theme.border))
    Chrome.roundedRect(self, 0, 0, self.width, self.height, bg, bc)

    local font = self.font or UIFont.Small
    local fontHgt = getCachedFontHeight(font)
    local textY = math.floor((self.height - fontHgt) / 2)
    local label = self:getOptionText(self.selected)
    if label and label ~= "" then
        local maxTextW = math.max(12, self.width - 28)
        local clipped = Text.truncate(label, maxTextW, font)
        local textColor = isDisabled and Theme.muted
            or ((isExpanded or isHover or isFocused) and ACTIVE_TEXT_COLOR or Theme.textColor)
        Theme.text(self, clipped, 8, textY, textColor, font)
    end

    local isize = 12
    local iconX = self.width - isize - 8
    local iconY = math.floor((self.height - isize) / 2)
    local chevronColor = isDisabled and Theme.muted
        or ((isExpanded or isHover or isFocused) and (Theme.borderFocus or Theme.accent) or Theme.muted)
    Visual.icon(self, iconX, iconY, isize, isExpanded and "chevronUp" or "chevronDown", chevronColor)
end

return Dropdown
