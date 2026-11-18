--[[
    OrderList.lua - EmberUI Widgets
    Reusable drag-and-button reorderable list component.
      - Drag reorder with live landing preview bar, Up/Down step buttons, visibility toggle.
      - Zero per-frame closure allocations during prerender().
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Viewport = require "EmberUI/Core/Viewport"
local StatusVisual = require "EmberUI/Widgets/StatusVisual"
local Text = require "EmberUI/Core/Text"

---@class EmberRoutesOrderList:ISPanel
local OrderList = ISPanel:derive("EmberRoutesOrderList")

local ROW_HEIGHT = 28
local ROW_GAP = 4
local PAD = 6
local BTN_SIZE = 18

local function fontHeight()
    if type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and tm.getFontHeight then return tm:getFontHeight(UIFont.Small) end
    end
    return 14
end

function OrderList:new(x, y, width, height, opts)
    local o = ISPanel.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    opts = opts or {}
    o.opts = opts
    o.items = {}
    o.getLabel = opts.getLabel or function(it) return tostring(it and (it.label or it.name or it) or "") end
    o.getIcon = opts.getIcon
    o.isShown = opts.isShown
    o.onToggle = opts.onToggle
    o.onChange = opts.onChange
    o.scrollY = 0
    o.dragIndex = nil
    o.dropIndex = nil
    o.hoverIndex = nil
    o.background = false
    o._viewportBounds = { x = 0, y = 0, width = width, height = height }
    o:setItems(opts.items or {})
    return o
end

function OrderList:setItems(items)
    self.items = {}
    for i = 1, #(items or {}) do
        self.items[i] = items[i]
    end
    self:clampScroll()
end

function OrderList:totalHeight()
    local n = #self.items
    if n == 0 then return 0 end
    return PAD * 2 + n * ROW_HEIGHT + (n - 1) * ROW_GAP
end

function OrderList:clampScroll()
    local maxScroll = math.max(0, self:totalHeight() - self.height)
    self.scrollY = math.max(0, math.min(maxScroll, self.scrollY or 0))
end

function OrderList:onResize()
    ISPanel.onResize(self)
    self._viewportBounds.width = self.width
    self._viewportBounds.height = self.height
    self:clampScroll()
end

function OrderList:moveItem(fromIdx, toIdx)
    local n = #self.items
    if fromIdx < 1 or fromIdx > n then return false end
    toIdx = math.max(1, math.min(n, toIdx))
    if fromIdx == toIdx then return false end

    local item = table.remove(self.items, fromIdx)
    table.insert(self.items, toIdx, item)
    if self.onChange then
        self.onChange(self.items, fromIdx, toIdx)
    end
    return true
end

function OrderList:rowAtY(localY)
    local contentY = localY + (self.scrollY or 0) - PAD
    if contentY < 0 then return nil end
    local stride = ROW_HEIGHT + ROW_GAP
    local idx = math.floor(contentY / stride) + 1
    if idx < 1 or idx > #self.items then return nil end
    local offsetInStride = contentY - (idx - 1) * stride
    if offsetInStride > ROW_HEIGHT then return nil end
    return idx
end

function OrderList:landingIndexAtY(localY)
    local contentY = localY + (self.scrollY or 0) - PAD
    local stride = ROW_HEIGHT + ROW_GAP
    local slot = math.floor((contentY + ROW_HEIGHT * 0.5) / stride) + 1
    return math.max(1, math.min(#self.items, slot))
end

function OrderList:buttonHit(idx, localX)
    local rightEdge = self.width - PAD - 4
    local downX = rightEdge - BTN_SIZE
    local upX = downX - BTN_SIZE - 4
    local eyeX = self.onToggle and (upX - BTN_SIZE - 6) or nil
    if localX >= downX and localX <= downX + BTN_SIZE then return "down" end
    if localX >= upX and localX <= upX + BTN_SIZE then return "up" end
    if eyeX and localX >= eyeX and localX <= eyeX + BTN_SIZE then return "toggle" end
    return nil
end

function OrderList:onMouseWheel(del)
    self.scrollY = (self.scrollY or 0) + del * 24
    self:clampScroll()
    return true
end

function OrderList:onMouseDown(x, y)
    local idx = self:rowAtY(y)
    if not idx then return true end

    local hit = self:buttonHit(idx, x)
    local jump = type(isShiftKeyDown) == "function" and isShiftKeyDown()
    if hit == "up" then
        self:moveItem(idx, jump and 1 or (idx - 1))
        return true
    elseif hit == "down" then
        self:moveItem(idx, jump and #self.items or (idx + 1))
        return true
    elseif hit == "toggle" and self.onToggle then
        self.onToggle(self.items[idx], idx)
        return true
    end

    self.dragIndex = idx
    self.dropIndex = idx
    return true
end

function OrderList:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)
    local my = self:getMouseY()
    self.hoverIndex = self:rowAtY(my)
    if self.dragIndex ~= nil then
        self.dropIndex = self:landingIndexAtY(my)
    end
end

function OrderList:onMouseMoveOutside()
    self.hoverIndex = nil
end

function OrderList:onMouseUp()
    if self.dragIndex ~= nil and self.dropIndex ~= nil then
        self:moveItem(self.dragIndex, self.dropIndex)
    end
    self.dragIndex = nil
    self.dropIndex = nil
    return true
end

function OrderList:onMouseUpOutside()
    self.dragIndex = nil
    self.dropIndex = nil
end

function OrderList:drawRows()
    local scroll = self.scrollY or 0
    local stride = ROW_HEIGHT + ROW_GAP
    local fh = fontHeight()
    local w = self.width - PAD * 2

    for i = 1, #self.items do
        local ry = PAD + (i - 1) * stride - scroll
        if ry + ROW_HEIGHT >= 0 and ry <= self.height then
            local item = self.items[i]
            local isDragging = (self.dragIndex == i)
            local isHover = (self.hoverIndex == i) and self.dragIndex == nil
            local shown = (not self.isShown) or self.isShown(item) ~= false

            local bg = isDragging and Theme.selected or (isHover and Theme.hover or Theme.card)
            local border = isDragging and Theme.accent or (isHover and Theme.hoverBorder or Theme.border)
            Chrome.roundedRect(self, PAD, ry, w, ROW_HEIGHT, bg, border)

            local cx = PAD + 6
            local iy = ry + math.floor((ROW_HEIGHT - 12) / 2)
            StatusVisual.icon(self, cx, iy, 12, "bullet", Theme.muted)
            cx = cx + 16

            if self.getIcon then
                local ic = self.getIcon(item)
                if ic then
                    StatusVisual.icon(self, cx, ry + math.floor((ROW_HEIGHT - 14) / 2), 14, ic, shown and Theme.accent or Theme.muted)
                    cx = cx + 18
                end
            end

            local rightEdge = self.width - PAD - 4
            local downX = rightEdge - BTN_SIZE
            local upX = downX - BTN_SIZE - 4
            local reserveLeft = upX

            local downColor = (i < #self.items) and Theme.textColor or Theme.muted
            local upColor = (i > 1) and Theme.textColor or Theme.muted
            StatusVisual.icon(self, downX + 3, ry + math.floor((ROW_HEIGHT - 12) / 2), 12, "chevronDown", downColor)
            StatusVisual.icon(self, upX + 3, ry + math.floor((ROW_HEIGHT - 12) / 2), 12, "chevronUp", upColor)

            if self.onToggle then
                local eyeX = upX - BTN_SIZE - 6
                reserveLeft = eyeX
                StatusVisual.icon(self, eyeX + 3, ry + math.floor((ROW_HEIGHT - 12) / 2), 12, "eye", shown and Theme.status.READY or Theme.muted)
            end

            local maxTextW = math.max(24, reserveLeft - cx - 6)
            local label = self.getLabel(item)
            local clipped = Text.truncate(label, maxTextW, UIFont.Small)
            Theme.text(self, clipped, cx, ry + math.floor((ROW_HEIGHT - fh) / 2), shown and Theme.textColor or Theme.muted)
        end
    end

    if self.dragIndex ~= nil and self.dropIndex ~= nil then
        local barY = PAD + (self.dropIndex - 1) * stride - scroll - 2
        if self.dropIndex > self.dragIndex then
            barY = barY + ROW_HEIGHT + 2
        end
        self:drawRect(PAD, barY, w, 2, 0.95, Theme.accent.r, Theme.accent.g, Theme.accent.b)
    end
end

function OrderList:prerender()
    Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.well or Theme.panel, Theme.border)
    Viewport.draw(self, self._viewportBounds, OrderList.drawRows, self)
end

return OrderList
