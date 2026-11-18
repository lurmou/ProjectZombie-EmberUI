--[[
    SearchInput.lua - EmberUI Widgets
    Ergonomic Flat 2.0 Search & Text Input Component.
      - Embedded left search icon (StatusVisual "search") & clear button (StatusVisual "cross").
      - B42 UITextBox2 text/placeholder RGBA synchronization with live Theme switches.
      - Bound to FocusManager.bindTextEntry for clean ESC unfocus & Tab traversal.
]]

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local StatusVisual = require "EmberUI/Widgets/StatusVisual"
local FocusManager = require "EmberUI/Core/FocusManager"

---@class EmberRoutesSearchInput:ISPanel
local SearchInput = ISPanel:derive("EmberRoutesSearchInput")

local function syncEntryColors(entry)
    if not entry then return end
    local tc = Theme.textColor
    local mc = Theme.muted or tc
    entry.textColor = tc
    if entry.setTextRGBA and entry.javaObject then
        entry:setTextRGBA(tc.r, tc.g, tc.b, tc.a or 1)
    end
    if entry.setPlaceholderTextRGBA and entry.javaObject then
        entry:setPlaceholderTextRGBA(mc.r, mc.g, mc.b, 0.78)
    end
    entry._emberThemeRev = Theme.revision
end

function SearchInput:new(x, y, width, height, placeholder, target, onChange, opts)
    local o = ISPanel.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.placeholder = placeholder or ""
    o.target = target
    o.onTextChangeFunction = onChange
    o.opts = opts or {}
    o.onSubmit = o.opts.onSubmit
    o.editable = true
    o.pad = 6
    o.iconSize = 14
    o.background = false

    o:initialise()
    return o
end

function SearchInput:initialise()
    ISPanel.initialise(self)
end

function SearchInput:createChildren()
    ISPanel.createChildren(self)

    local pad = self.pad or 6
    local iconSize = self.iconSize or 14
    local entryX = pad
    if self.opts.icon ~= false then entryX = pad + iconSize + 6 end
    local entryW = math.max(20, self.width - entryX - (iconSize + pad + 2))
    local entryH = math.max(16, self.height - 2)

    local entry = ISTextEntryBox:new("", entryX, 1, entryW, entryH)
    entry:initialise()
    entry:instantiate()
    if self.editable == false then entry:setEditable(false) end
    entry.background = false
    entry.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    entry.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    if entry.setClearButton then entry:setClearButton(false) end
    entry.target = self
    entry.onTextChange = function()
        self:onInnerChange()
    end
    entry.onTextChangeFunction = function()
        self:onInnerChange()
    end
    if self.placeholder and self.placeholder ~= "" and entry.setPlaceholderText then
        entry:setPlaceholderText(self.placeholder)
    end
    if type(self.opts.maxLength) == "number" and entry.setMaxTextLength then
        entry:setMaxTextLength(self.opts.maxLength)
    end
    if self.onSubmit then
        entry.onCommandEntered = function() self:submit() end
    end
    syncEntryColors(entry)
    FocusManager.bindTextEntry(entry, self.opts.focusGroup)

    self:addChild(entry)
    self.entry = entry
end

function SearchInput:onResize()
    ISPanel.onResize(self)
    if self.entry then
        local pad = self.pad or 6
        local iconSize = self.iconSize or 14
        local entryX = pad
        if self.opts.icon ~= false then entryX = pad + iconSize + 6 end
        local entryW = math.max(20, self.width - entryX - (iconSize + pad + 2))
        local entryH = math.max(16, self.height - 2)
        self.entry:setX(entryX)
        self.entry:setWidth(entryW)
        self.entry:setHeight(entryH)
    end
end

function SearchInput:onInnerChange()
    local val = self:getText()
    if self.onTextChangeFunction then
        self.onTextChangeFunction(self.target or self, val, self)
    end
end

function SearchInput:submit()
    if self.editable == false then return end
    if not self.onSubmit then return end
    self.onSubmit(self.target or self, self:getText(), self)
end

function SearchInput:setEditable(editable)
    self.editable = editable
    if self.entry and self.entry.javaObject then
        self.entry:setEditable(editable)
    end
    if not editable then
        self:unfocus()
    end
end

function SearchInput:isEditable()
    return self.editable ~= false
end

function SearchInput:getText()
    return self.entry and self.entry:getText() or ""
end

function SearchInput:setText(text)
    if self.entry then
        self.entry:setText(text or "")
    end
end

function SearchInput:setPlaceholderText(text)
    self.placeholder = text or ""
    if self.entry and self.entry.setPlaceholderText then
        self.entry:setPlaceholderText(self.placeholder)
    end
end

function SearchInput:isFocused()
    if self.focused == true then return true end
    if not self.entry then return false end
    if self.entry.focused == true then return true end
    if self.entry.isFocused then return self.entry:isFocused() == true end
    if self.entry.javaObject and self.entry.javaObject.isFocused then
        return self.entry.javaObject:isFocused() == true
    end
    return false
end

function SearchInput:focus()
    self.focused = true
    if self.entry then
        self.entry.focused = true
        if self.entry.focus then self.entry:focus() end
    end
end

function SearchInput:unfocus()
    self.focused = false
    if self.entry then
        self.entry.focused = false
        if self.entry.unfocus then self.entry:unfocus() end
    end
end

function SearchInput:clear()
    self:setText("")
    self:onInnerChange()
end

function SearchInput:isOverClear(x, y)
    local text = self:getText()
    if not text or text == "" then return false end
    local pad = self.pad or 6
    local iconSize = self.iconSize or 14
    local clearX = self.width - iconSize - pad - 4
    return x >= clearX and x <= self.width and y >= 0 and y <= self.height
end

function SearchInput:onMouseDown(x, y)
    if self.editable == false then return true end
    if self:isOverClear(x, y) then
        self:clear()
        return true
    end
    if self.entry and self.entry.focus then
        self.entry:focus()
    end
    return true
end

function SearchInput:prerender()
    if self.entry and self.entry._emberThemeRev ~= Theme.revision then
        syncEntryColors(self.entry)
    end

    local bg = Theme.well or Theme.panel
    local isFocused = self:isFocused()
    Chrome.roundedRect(self, 0, 0, self.width, self.height, bg, isFocused and (Theme.borderFocus or Theme.accent) or Theme.border)
    if isFocused then
        local fc = Theme.borderFocus or Theme.accent
        self:drawRectBorder(-1, -1, self.width + 2, self.height + 2, 0.55, fc.r, fc.g, fc.b)
    end

    local pad = self.pad or 6
    local iconSize = self.iconSize or 14
    local iconY = math.floor((self.height - iconSize) / 2)
    local iconColor = isFocused and (Theme.borderFocus or Theme.accent) or Theme.muted
    if self.opts.icon ~= false then
        StatusVisual.icon(self, pad, iconY, iconSize, "search", iconColor)
    end

    local text = self:getText()
    if self.editable ~= false and text and text ~= "" then
        local clearX = self.width - iconSize - pad
        local mx = self:getMouseX()
        local my = self:getMouseY()
        local isHover = self:isOverClear(mx, my)
        local clearColor = isHover and Theme.textColor or Theme.muted
        StatusVisual.icon(self, clearX, iconY, iconSize, "cross", clearColor)
    end
end

return SearchInput
