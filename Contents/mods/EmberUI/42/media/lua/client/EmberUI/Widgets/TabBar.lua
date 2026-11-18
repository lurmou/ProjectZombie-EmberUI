--[[
    TabBar.lua - EmberRoutes UI Core
    Reusable Zero-GC animated navigation tab bar.
    Supports "underline" (LFS / GitHub bottom accent strip + glow wash) and
    "pill" (segmented rounded capsule indicator), backed by SpringDriver,
    optional icons (StatusVisual), count/text badges, disabled tabs,
    and automatic panel switching via bindPanels(map).
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Failsafe = require "EmberUI/Core/Failsafe"
local SpringDriver = require "EmberUI/Core/SpringDriver"
local Visual = require "EmberUI/Widgets/StatusVisual"
local UICache = require "EmberUI/Core/UICache"

---@class EmberRoutesTabBar:ISPanel
---@field tabs table[]
---@field items table[]
---@field selectedId any
---@field variant "underline"|"pill"
---@field panels table?
---@field target any?
---@field onChange fun(targetOrId:any, idOrTab:any, tab:table?, bar:EmberRoutesTabBar)?
local TabBar = ISPanel:derive("EmberRoutesTabBar")

local ACTIVE_TEXT = { r = 1, g = 1, b = 1, a = 1 }
local BADGE_BG_BUF = { r = 0.04, g = 0.06, b = 0.09, a = 0.90 }

---@param x number
---@param y number
---@param width number
---@param height number
---@param tabs table[]? Array of { id=any, label=string, icon=string?, badge=string|number?, disabled=boolean?, tooltip=string?, panel=ISUIElement? }
---@param selectedId any?
---@param onChange function?
---@param opts table? { variant="underline"|"pill", gap=number, target=any, panels=table, stretch=boolean }
---@return EmberRoutesTabBar
function TabBar:new(x, y, width, height, tabs, selectedId, onChange, opts)
    opts = opts or {}
    local o = ISPanel.new(self, x, y, width, height or 30)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.font = opts.font or UIFont.Small
    local tm = getTextManager and getTextManager()
    o.fontHeight = (tm and tm.getFontHeight and tm:getFontHeight(o.font)) or 14
    o.pad = math.max(8, math.ceil(o.fontHeight * 0.55))
    o.gap = opts.gap or 4
    o.variant = opts.variant or "underline"
    o.stretch = opts.stretch == true
    o.target = opts.target
    o.onChange = onChange
    o.panels = opts.panels
    o.tabs = {}
    o.items = {}
    o.selectedId = selectedId
    o.hoveredIndex = nil
    o.indicator = SpringDriver.create2D(0, 0, { stiffness = 360, damping = 30, precision = 0.5 })
    o.indicatorInitialized = false
    o:initialise()
    if tabs then
        o:setTabs(tabs, selectedId)
    end
    return o
end

function TabBar:initialise()
    ISPanel.initialise(self)
end

function TabBar:measureItems()
    self.items = {}
    local count = #self.tabs
    if count == 0 then return end

    local gap = self.gap or 4
    local h = self.fontHeight or 14
    local pad = self.pad or 8
    local padH = (self.variant == "pill") and 2 or 0
    local itemH = math.max(18, (self.height or 28) - padH * 2)
    local curX = (self.variant == "pill") and 3 or 0
    local availW = math.max(1, (self.width or 200) - (self.variant == "pill" and 6 or 0) - gap * (count - 1))
    local totalNatural = 0

    for i = 1, count do
        local tab = self.tabs[i]
        local label = tostring(tab.label or tab.id or "")
        local labelW = UICache.measure(self.font, label)
        local badgeStr = tab.badge ~= nil and tostring(tab.badge) or nil
        local badgeW = badgeStr and (UICache.measure(self.font, badgeStr) + 10) or 0
        local iconW = tab.icon and 18 or 0
        local naturalW = math.ceil(labelW + iconW + badgeW + pad * 2 + (badgeStr and 6 or 0))
        totalNatural = totalNatural + naturalW
        self.items[i] = {
            id = tab.id,
            label = label,
            labelW = labelW,
            icon = tab.icon,
            badgeStr = badgeStr,
            badgeW = badgeW,
            disabled = tab.disabled == true,
            tooltip = tab.tooltip,
            panel = tab.panel,
            naturalW = naturalW,
            textY = math.floor((itemH - h) / 2),
        }
    end

    for i = 1, count do
        local it = self.items[i]
        local w
        if self.stretch then
            w = math.floor(availW / count)
        elseif totalNatural > availW then
            w = math.max(36, math.floor(it.naturalW * (availW / totalNatural)))
        else
            w = it.naturalW
        end
        it.x = curX
        it.y = padH
        it.width = w
        it.height = itemH
        curX = curX + w + gap
    end
end

function TabBar:syncPanels()
    if self.panels then
        for id, panel in pairs(self.panels) do
            if panel and panel.setVisible then
                panel:setVisible(id == self.selectedId)
            end
        end
    end
    for i = 1, #self.items do
        local p = self.items[i].panel
        if p and p.setVisible then
            p:setVisible(self.items[i].id == self.selectedId)
        end
    end
end

---@param panelsById table<any, ISUIElement>
function TabBar:bindPanels(panelsById)
    self.panels = panelsById
    self:syncPanels()
end

---@param tabs table[]
---@param selectedId any?
function TabBar:setTabs(tabs, selectedId)
    self.tabs = tabs or {}
    self.indicatorInitialized = false
    if selectedId ~= nil then
        self.selectedId = selectedId
    elseif self.selectedId == nil and self.tabs[1] then
        self.selectedId = self.tabs[1].id
    end
    self:measureItems()
    self:syncPanels()
end

function TabBar:setBadge(id, badge)
    for i = 1, #self.tabs do
        if self.tabs[i].id == id then
            self.tabs[i].badge = badge
            self:measureItems()
            return true
        end
    end
    return false
end

function TabBar:setTabDisabled(id, disabled)
    for i = 1, #self.tabs do
        if self.tabs[i].id == id then
            self.tabs[i].disabled = disabled == true
            if self.items[i] then
                self.items[i].disabled = disabled == true
            end
            return true
        end
    end
    return false
end

function TabBar:setSelected(id, silent)
    local foundTab = nil
    for i = 1, #self.items do
        if self.items[i].id == id then
            if self.items[i].disabled then return false end
            foundTab = self.tabs[i]
            break
        end
    end
    if not foundTab then return false end
    local changed = self.selectedId ~= id
    self.selectedId = id
    self:syncPanels()
    if changed and not silent and self.onChange then
        local guardKey = "TabBar:" .. tostring(id)
        Failsafe.reset(guardKey)
        Failsafe.guard(guardKey, function()
            if self.target ~= nil then
                self.onChange(self.target, id, foundTab, self)
            else
                self.onChange(id, foundTab, self)
            end
        end)
    end
    return true
end

function TabBar:onResize()
    ISPanel.onResize(self)
    self.indicatorInitialized = false
    self:measureItems()
end

function TabBar:onMouseMove(dx, dy)
    local mx = self.getMouseX and self:getMouseX() or -1
    local my = self.getMouseY and self:getMouseY() or -1
    self.hoveredIndex = nil
    self.tooltip = nil
    for i = 1, #self.items do
        local it = self.items[i]
        if mx >= it.x and mx <= it.x + it.width and my >= it.y and my <= it.y + it.height then
            self.hoveredIndex = i
            self.tooltip = it.tooltip
            break
        end
    end
end

function TabBar:onMouseMoveOutside()
    self.hoveredIndex = nil
    self.tooltip = nil
end

function TabBar:onMouseDown(x, y)
    for i = 1, #self.items do
        local it = self.items[i]
        if not it.disabled and x >= it.x and x <= it.x + it.width and y >= it.y and y <= it.y + it.height then
            self:setSelected(it.id, false)
            if getSoundManager then
                pcall(function() getSoundManager():playUISound("UIActivateButton") end)
            end
            return true
        end
    end
    return false
end

function TabBar:onKeyPress(key)
    if #self.items == 0 then return false end
    local dir = (key == Keyboard.KEY_RIGHT and 1) or (key == Keyboard.KEY_LEFT and -1) or nil
    if not dir then return false end
    local cur = 1
    for i = 1, #self.items do
        if self.items[i].id == self.selectedId then cur = i break end
    end
    for step = 1, #self.items do
        local idx = ((cur - 1 + dir * step) % #self.items) + 1
        if not self.items[idx].disabled then
            self:setSelected(self.items[idx].id, false)
            return true
        end
    end
    return false
end

function TabBar:prerender()
    ISPanel.prerender(self)
    if self._measuredWidth ~= self.width or self._measuredHeight ~= self.height then
        self._measuredWidth = self.width
        self._measuredHeight = self.height
        self.indicatorInitialized = false
        self:measureItems()
    end
    local n = #self.items
    if n == 0 then return end

    if self.variant == "pill" then
        Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.well or Theme.panel, Theme.borderSubtle or Theme.border)
    else
        Theme.rect(self, 0, self.height - 1, self.width, 1, Theme.borderSubtle or Theme.border)
    end

    local targetItem
    for i = 1, n do
        if self.items[i].id == self.selectedId then
            targetItem = self.items[i]
            break
        end
    end

    local dt = 0.016
    if UIManager and UIManager.getMillisSinceLastRender then
        dt = UIManager.getMillisSinceLastRender() / 1000.0
    end

    local ix, iw
    if targetItem then
        if not self.indicatorInitialized then
            SpringDriver.snap2D(self.indicator, targetItem.x, targetItem.width)
            self.indicatorInitialized = true
        end
        ix, iw = SpringDriver.update2D(self.indicator, targetItem.x, targetItem.width, dt)
        if self.variant == "pill" then
            Chrome.roundedRect(self, ix, targetItem.y, iw, targetItem.height, Theme.selected, Theme.selectedBorder or Theme.accent)
            Chrome.hGradient(self, ix + 1, targetItem.y + 1, math.max(0, iw - 2), math.max(1, targetItem.height - 2), Theme.accent, 0.14)
        else
            Chrome.hGradient(self, ix, targetItem.y, iw, math.max(1, targetItem.height - 2), Theme.accent, 0.12)
            Chrome.pill(self, ix + 2, self.height - 3, math.max(4, iw - 4), 3, Theme.accent)
        end
    end

    local pad = self.pad or 8
    for i = 1, n do
        local it = self.items[i]
        local isSel = it.id == self.selectedId
        local isHover = (not it.disabled) and (self.hoveredIndex == i) and not isSel
        if isHover then
            Chrome.roundedFill(self, it.x, it.y, it.width, it.height, Theme.hover)
        end

        local curX = it.x + pad
        local col = it.disabled and Theme.muted or (isSel and ACTIVE_TEXT or (isHover and Theme.textColor or Theme.muted))
        if it.icon then
            local iconY = it.y + math.floor((it.height - 13) / 2)
            Visual.icon(self, curX, iconY, 13, it.icon, col, { forceMono = true })
            curX = curX + 18
        end
        Theme.text(self, it.label, curX, it.y + it.textY, col, self.font)

        if it.badgeStr then
            local bx = it.x + it.width - it.badgeW - math.max(4, math.floor(pad * 0.6))
            local by = it.y + math.floor((it.height - (self.fontHeight + 2)) / 2)
            local bc = isSel and (Theme.accent or Theme.borderFocus) or (Theme.borderSubtle or Theme.border)
            Chrome.roundedRect(self, bx, by, it.badgeW, self.fontHeight + 2, Theme.badgeBg or BADGE_BG_BUF, bc)
            Theme.text(self, it.badgeStr, bx + 5, by + 1, isSel and ACTIVE_TEXT or Theme.muted, self.font)
        end
    end
end

return TabBar
