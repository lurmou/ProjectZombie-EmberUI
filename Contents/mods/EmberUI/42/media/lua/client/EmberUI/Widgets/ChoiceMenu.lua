--[[
    ChoiceMenu.lua - EmberUI Widgets
    Searchable, sectioned floating choice picker:
      - Zero per-frame closure allocations during prerender() (Viewport.draw static callback).
      - Full B42 keyboard/ESC consumption + searchBox unfocus on close.
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Viewport = require "EmberUI/Core/Viewport"
local StatusVisual = require "EmberUI/Widgets/StatusVisual"
local SearchInput = require "EmberUI/Widgets/SearchInput"
local UICache = require "EmberUI/Core/UICache"
local Text = require "EmberUI/Core/Text"
local Tooltip = require "EmberUI/Core/TooltipManager"
local FocusManager = require "EmberUI/Core/FocusManager"
local Runtime = require "EmberUI/Core/Runtime"

---@class EmberRoutesChoiceMenu:ISPanel
local ChoiceMenu = ISPanel:derive("EmberRoutesChoiceMenu")

local DEFAULT_WIDTH = 280
local MAX_HEIGHT = 340
local ROW_HEIGHT = 26
local SECTION_HEIGHT = 22
local TITLE_HEIGHT = 26
local SEARCH_HEIGHT = 26
local PAD = 8

local function fontHeight()
    if type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and tm.getFontHeight then return tm:getFontHeight(UIFont.Small) end
    end
    return 14
end

function ChoiceMenu:new(x, y, opts)
    opts = opts or {}
    local width = opts.width or DEFAULT_WIDTH
    local o = ISPanel.new(self, x or 0, y or 0, width, 160)
    setmetatable(o, self)
    self.__index = self

    o.opts = opts
    o.title = opts.title or ""
    o.owner = opts.owner
    o.onPick = opts.onPick
    o.onClose = opts.onClose
    o.maxHeight = opts.maxHeight or MAX_HEIGHT
    o.searchQuery = ""
    o.scrollY = 0
    o.contentHeight = 0
    o.hoveredIndex = nil
    o.disposed = false
    o.background = false
    o.wantKeyEvents = true
    if o.setWantKeyEvents then o:setWantKeyEvents(true) end
    o.rows = {}
    o._viewportBounds = { x = 0, y = 0, width = width, height = 100 }
    o._searchHint = opts.searchPlaceholder or (type(getTextOrNull) == "function" and getTextOrNull("IGUI_EmberUI_UI_SearchHint")) or "Search..."

    o:normalizeSections(opts)
    o:rebuildFilteredRows()
    o:recomputeSizeAndClamp(x or 0, y or 0)
    return o
end

function ChoiceMenu:normalizeSections(opts)
    if type(opts.sections) == "table" and #opts.sections > 0 then
        self.sections = opts.sections
    else
        self.sections = {
            { title = nil, items = opts.items or {} },
        }
    end
    local total = 0
    for i = 1, #self.sections do
        local items = self.sections[i].items or {}
        total = total + #items
    end
    self.totalItems = total
    if opts.searchable ~= nil then
        self.searchable = opts.searchable == true
    else
        self.searchable = total >= 6
    end
end

function ChoiceMenu:rebuildFilteredRows()
    local q = string.lower(self.searchQuery or "")
    local rows = {}
    local y = 0
    local fh = fontHeight()

    for sIdx = 1, #self.sections do
        local sec = self.sections[sIdx]
        local items = sec.items or {}
        local matched = {}
        for i = 1, #items do
            local item = items[i]
            if q == "" then
                matched[#matched + 1] = item
            else
                local label = string.lower(tostring(item.label or ""))
                local sub = string.lower(tostring(item.subLabel or ""))
                if string.find(label, q, 1, true) or (sub ~= "" and string.find(sub, q, 1, true)) then
                    matched[#matched + 1] = item
                end
            end
        end

        if #matched > 0 then
            if sec.title and sec.title ~= "" then
                rows[#rows + 1] = {
                    kind = "section",
                    title = sec.title,
                    y = y,
                    height = SECTION_HEIGHT,
                }
                y = y + SECTION_HEIGHT
            end
            for i = 1, #matched do
                local item = matched[i]
                local h = ROW_HEIGHT
                rows[#rows + 1] = {
                    kind = "item",
                    item = item,
                    y = y,
                    height = h,
                    fontH = fh,
                }
                y = y + h + 2
            end
        end
    end

    self.rows = rows
    self.contentHeight = math.max(0, y)
    self:clampScroll()
end

function ChoiceMenu:listTopY()
    local top = (self.title ~= "" and TITLE_HEIGHT or PAD)
    if self.searchable then
        top = top + SEARCH_HEIGHT + 6
    else
        top = top + 4
    end
    return top
end

function ChoiceMenu:recomputeSizeAndClamp(anchorX, anchorY)
    local top = self:listTopY()
    local bodyH = math.max(ROW_HEIGHT + 4, math.min(self.contentHeight + 4, self.maxHeight - top - PAD))
    local totalH = math.min(self.maxHeight, top + bodyH + PAD)
    self.height = totalH

    local x = anchorX
    local y = anchorY
    local core = type(getCore) == "function" and getCore()
    if core then
        local sw = core:getScreenWidth()
        local sh = core:getScreenHeight()
        if type(sw) == "number" and x + self.width > sw - 6 then
            x = math.max(6, sw - self.width - 6)
        end
        if type(sh) == "number" and y + totalH > sh - 6 then
            y = math.max(6, sh - totalH - 6)
        end
    end
    self.x = x
    self.y = y
    self._viewportBounds.x = PAD
    self._viewportBounds.y = top
    self._viewportBounds.width = math.max(20, self.width - PAD * 2)
    self._viewportBounds.height = math.max(20, totalH - top - PAD)
end

function ChoiceMenu:clampScroll()
    local viewH = self._viewportBounds and self._viewportBounds.height or 100
    local maxScroll = math.max(0, (self.contentHeight or 0) - viewH)
    self.scrollY = math.max(0, math.min(maxScroll, self.scrollY or 0))
end

function ChoiceMenu:initialise()
    ISPanel.initialise(self)
end

function ChoiceMenu:createChildren()
    ISPanel.createChildren(self)
    if self.setWantKeyEvents then self:setWantKeyEvents(true) end
    if self.searchable then
        local sy = (self.title ~= "" and TITLE_HEIGHT or PAD) + 4
        local box = SearchInput:new(PAD, sy, self.width - PAD * 2, SEARCH_HEIGHT, self._searchHint, self, function(_, val)
            self:setFilter(val)
        end, {
            onSubmit = function()
                self:pickFirstEnabled()
            end,
        })
        box:initialise()
        box:instantiate()
        self:addChild(box)
        self.searchBox = box
    end
end

function ChoiceMenu:setFilter(query)
    self.searchQuery = query or ""
    self.scrollY = 0
    self:rebuildFilteredRows()
end

function ChoiceMenu:pickFirstEnabled()
    for i = 1, #self.rows do
        local r = self.rows[i]
        if r.kind == "item" and not r.item.disabled then
            self:selectItem(r.item)
            return true
        end
    end
    return false
end

function ChoiceMenu:selectItem(item)
    if not item or item.disabled then return false end
    local cb = self.onPick
    self:close("PICKED")
    if cb then cb(item) end
    return true
end

function ChoiceMenu:hitRow(localX, localY)
    local vb = self._viewportBounds
    if localX < vb.x or localX > vb.x + vb.width or localY < vb.y or localY > vb.y + vb.height then
        return nil
    end
    local contentY = (localY - vb.y) + (self.scrollY or 0)
    for i = 1, #self.rows do
        local r = self.rows[i]
        if r.kind == "item" and contentY >= r.y and contentY <= r.y + r.height then
            return i, r
        end
    end
    return nil
end

function ChoiceMenu:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)
    local mx, my = self:getMouseX(), self:getMouseY()
    self.hoveredIndex = self:hitRow(mx, my)
end

function ChoiceMenu:onMouseWheel(del)
    local viewH = self._viewportBounds.height
    if self.contentHeight <= viewH then return true end
    self.scrollY = (self.scrollY or 0) + (del * 28)
    self:clampScroll()
    return true
end

function ChoiceMenu:onMouseDown(x, y)
    if self.disposed then return true end
    if self.title ~= "" and x >= self.width - 24 and x <= self.width - 4 and y >= 3 and y <= TITLE_HEIGHT - 3 then
        self:close("CLOSE_BUTTON")
        return true
    end
    local _, row = self:hitRow(x, y)
    if row and row.item then
        self:selectItem(row.item)
        return true
    end
    return true
end

function ChoiceMenu:onMouseDownOutside()
    if not self.disposed then
        self:close("OUTSIDE")
    end
end

function ChoiceMenu:onKeyPress(key)
    local menuSelf = self
    return FocusManager.handleWindowKeyPress(self, key, function()
        menuSelf:close("ESCAPE")
        return true
    end)
end

function ChoiceMenu:isKeyConsumed(key)
    return FocusManager.isWindowKeyConsumed(self, key, true)
end

function ChoiceMenu:drawRows()
    local vb = self._viewportBounds
    local scroll = self.scrollY or 0
    local x = vb.x
    local w = vb.width
    local fh = fontHeight()

    if #self.rows == 0 then
        local empty = (type(getTextOrNull) == "function" and getTextOrNull("IGUI_EmberUI_UI_ChoiceEmpty")) or "No matching choices"
        local tw = UICache.measure(UIFont.Small, empty)
        Theme.text(self, empty, x + math.floor((w - tw) / 2), vb.y + 8, Theme.muted)
        return
    end

    for i = 1, #self.rows do
        local r = self.rows[i]
        local ry = vb.y + r.y - scroll
        if ry + r.height >= vb.y and ry <= vb.y + vb.height then
            if r.kind == "section" then
                Theme.text(self, r.title, x + 4, ry + math.floor((r.height - fh) / 2), Theme.muted)
                self:drawRect(x + 4, ry + r.height - 2, w - 8, 1, 0.45, Theme.border.r, Theme.border.g, Theme.border.b)
            else
                local item = r.item
                local isHover = (self.hoveredIndex == i) and not item.disabled
                local isSelected = item.selected == true
                local bg = isSelected and Theme.selected or (isHover and Theme.hover or Theme.card)
                local border = isSelected and Theme.selectedBorder or (isHover and Theme.hoverBorder or Theme.borderSubtle)
                Chrome.roundedRect(self, x, ry, w, r.height, bg, border)

                local cursorX = x + 8
                local iconSize = 14
                local iy = ry + math.floor((r.height - iconSize) / 2)
                if item.icon then
                    local iconCol = item.disabled and Theme.muted or (item.color or (isSelected and Theme.accent or Theme.textColor))
                    StatusVisual.icon(self, cursorX, iy, iconSize, item.icon, iconCol)
                    cursorX = cursorX + iconSize + 6
                end

                local rightReserve = 8
                if isSelected then
                    StatusVisual.icon(self, x + w - 20, iy, 12, "check", Theme.status.READY)
                    rightReserve = 26
                elseif item.disabled then
                    StatusVisual.icon(self, x + w - 20, iy, 12, "lock", Theme.muted)
                    rightReserve = 26
                elseif item.badge and item.badge ~= "" then
                    local bw = UICache.measure(UIFont.Small, item.badge)
                    Theme.text(self, item.badge, x + w - bw - 8, ry + math.floor((r.height - fh) / 2), item.badgeColor or Theme.muted)
                    rightReserve = bw + 14
                end

                local maxLabelW = math.max(24, (x + w - rightReserve) - cursorX)
                local label = Text.truncate(tostring(item.label or ""), maxLabelW, UIFont.Small)
                local fg = item.disabled and Theme.muted or (item.color or Theme.textColor)
                Theme.text(self, label, cursorX, ry + math.floor((r.height - fh) / 2), fg)
            end
        end
    end
end

function ChoiceMenu:prerender()
    Chrome.shadow(self, 0, 0, self.width, self.height, 0.42)
    Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.window, Theme.border)
    if self.title ~= "" then
        Chrome.titleBar(self, 1, 1, math.max(0, self.width - 2), TITLE_HEIGHT - 1, Theme.titleBar or Theme.panel, Theme.titleAccent, Theme.borderSubtle)
        local fh = fontHeight()
        local clippedTitle = Text.truncate(self.title, math.max(24, self.width - 36), UIFont.Small)
        Theme.text(self, clippedTitle, PAD, math.floor((TITLE_HEIGHT - fh) / 2), Theme.textColor)
        StatusVisual.icon(self, self.width - 20, math.floor((TITLE_HEIGHT - 12) / 2), 12, "close", Theme.muted)
    end
    Viewport.draw(self, self._viewportBounds, ChoiceMenu.drawRows, self)
end

function ChoiceMenu:close(reason)
    if self.disposed then return end
    self.disposed = true
    FocusManager.unfocusTree(self)
    FocusManager.clearGroup(self)
    if self._shortcutHandle then
        self._shortcutHandle:release()
        self._shortcutHandle = nil
    end
    if self._surfaceHandle then
        self._surfaceHandle:release()
        self._surfaceHandle = nil
    end
    Tooltip.unregisterOwner(self)
    if self.searchBox then
        Tooltip.unregisterOwner(self.searchBox)
        self.searchBox = nil
    end
    self:setVisible(false)
    if self.removeFromUIManager then self:removeFromUIManager() end
    if self.onClose then self.onClose(self, reason or "CLOSE") end
end

function ChoiceMenu.open(x, y, opts)
    local menu = ChoiceMenu:new(x, y, opts)
    menu:initialise()
    menu:instantiate()
    menu._shortcutHandle = FocusManager.pushShortcutScope(menu, {
        onEscape = function()
            menu:close("ESCAPE")
            return true
        end,
    })
    menu._surfaceHandle = Runtime.trackSurface(menu, {
        onResolutionChange = function(m)
            m:recomputeSizeAndClamp(m.x, m.y)
        end,
    })
    menu:addToUIManager()
    if menu.setAlwaysOnTop then menu:setAlwaysOnTop(true) end
    if menu.bringToTop then menu:bringToTop() end
    if menu.searchBox then menu.searchBox:focus() end
    return menu
end

return ChoiceMenu
