--[[
    BulkBar.lua - EmberUI Widgets
    Batch selection floating action bar paired with PickSet.
    Displays current selection count badge, Select All / Clear controls, and batch action buttons.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"

---@class EmberUIBulkBar:ISPanel
---@field pickSet table?
---@field actions table[]
local BulkBar = ISPanel:derive("EmberUIBulkBar")

local function labelText(key, fallback, arg1)
    if type(getTextOrNull) == "function" then
        local v = getTextOrNull("IGUI_EmberUI_UI_" .. key)
        if v and v ~= "" then
            if arg1 ~= nil then return v:gsub("%%1", tostring(arg1)) end
            return v
        end
    end
    if arg1 ~= nil and fallback:find("%%1") then
        return fallback:gsub("%%1", tostring(arg1))
    end
    return fallback
end

function BulkBar:new(x, y, width, height, opts)
    opts = opts or {}
    local o = ISPanel.new(self, x, y, width, height or 34)
    setmetatable(o, self)
    self.__index = self

    o.background = false
    o.pickSet = opts.pickSet
    o.allIds = opts.allIds
    o.actions = opts.actions or {}
    o.onSelectAll = opts.onSelectAll
    o.onClear = opts.onClear
    o.autoHide = opts.autoHide ~= false
    o.lastCount = -1
    o.countLabel = labelText("BulkSelected", "%1 selected", 0)
    o.buttons = {}
    o:initialise()
    return o
end

function BulkBar:initialise()
    ISPanel.initialise(self)
end

function BulkBar:createChildren()
    ISPanel.createChildren(self)
    local h = math.max(20, (self.height or 34) - 8)
    local by = math.floor(((self.height or 34) - h) / 2)

    local btnClear = ISButton:new(0, by, 68, h, labelText("BulkClear", "Clear"), self, function(bar)
        if bar.pickSet then bar.pickSet:clear() end
        if type(bar.onClear) == "function" then bar.onClear(bar.pickSet) end
        bar:sync()
    end)
    btnClear:initialise()
    btnClear:instantiate()
    Theme.button(btnClear, false)
    self:addChild(btnClear)
    self.clearButton = btnClear

    local btnAll = ISButton:new(0, by, 86, h, labelText("BulkSelectAll", "Select All"), self, function(bar)
        local ids = type(bar.allIds) == "function" and bar.allIds() or bar.allIds
        if bar.pickSet and type(ids) == "table" then
            for i = 1, #ids do bar.pickSet:add(ids[i]) end
        end
        if type(bar.onSelectAll) == "function" then bar.onSelectAll(bar.pickSet) end
        bar:sync()
    end)
    btnAll:initialise()
    btnAll:instantiate()
    Theme.button(btnAll, false)
    self:addChild(btnAll)
    self.selectAllButton = btnAll

    for i = 1, #self.actions do
        local act = self.actions[i]
        local bw = act.width or 96
        local btn = ISButton:new(0, by, bw, h, act.label or act.id or "Action", self, function(bar)
            if type(act.onClick) == "function" then
                local ids = bar.pickSet and bar.pickSet:list() or {}
                act.onClick(ids, bar.pickSet, bar)
            end
            bar:sync()
        end)
        btn:initialise()
        btn:instantiate()
        Theme.button(btn, act.primary == true or act.role == "primary")
        self:addChild(btn)
        self.buttons[i] = btn
    end

    self:layoutButtons()
    self:sync()
end

function BulkBar:layoutButtons()
    local pad = 10
    local gap = 6
    local rightX = (self.width or 320) - pad
    for i = #self.buttons, 1, -1 do
        local btn = self.buttons[i]
        rightX = rightX - (btn.width or 90)
        btn:setX(rightX)
        rightX = rightX - gap
    end
    if self.clearButton then
        rightX = rightX - (self.clearButton.width or 68)
        self.clearButton:setX(rightX)
        rightX = rightX - gap
    end
    if self.selectAllButton then
        rightX = rightX - (self.selectAllButton.width or 86)
        self.selectAllButton:setX(rightX)
    end
end

function BulkBar:sync()
    local count = self.pickSet and self.pickSet:count() or 0
    if count ~= self.lastCount then
        self.lastCount = count
        self.countLabel = labelText("BulkSelected", "%1 selected", count)
    end
    if self.autoHide and self.setVisible then
        self:setVisible(count > 0)
    end
end

function BulkBar:setWidth(w)
    ISPanel.setWidth(self, w)
    self:layoutButtons()
end

function BulkBar:onResize()
    ISPanel.onResize(self)
    self:layoutButtons()
end

function BulkBar:prerender()
    ISPanel.prerender(self)
    self:sync()
    local count = self.lastCount
    if self.autoHide and count <= 0 then return end
    Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.card or Theme.panel, Theme.accent or Theme.border)
    Chrome.hGradient(self, 1, 1, math.min(180, self.width - 2), math.max(1, self.height - 2), Theme.accent, 0.14, 6)
    local fh = type(getTextManager) == "function" and getTextManager():getFontHeight(UIFont.Small) or 14
    Theme.text(self, self.countLabel, 12, math.floor((self.height - fh) / 2), Theme.textColor)
end

return BulkBar
