-- ScrollView.lua - EmberRoutes UI
-- Declarative scrollable container: combines ScrollContainer (stencil clipping,
-- frustum culling, scrollbar) with an inner LayoutHost whose height expands
-- automatically to fit its declarative column/grid content.

local ScrollContainer = require 'EmberUI/Widgets/ScrollContainer'
local LayoutHost = require 'EmberUI/Core/LayoutHost'

---@class EmberRoutesScrollView:EmberRoutesScrollContainer
---@field host EmberRoutesLayoutHost
local ScrollView = ScrollContainer:derive('EmberRoutesScrollView')

local function measureMinHeight(node)
    if not node then return 0 end
    local p = node.padding or { top = 0, bottom = 0, left = 0, right = 0 }
    if node.direction == 'row' then
        local maxCross = 0
        for i = 1, #node.items do
            local item = node.items[i]
            if item.visible then
                local m = item.margin or { top = 0, bottom = 0 }
                local itemH = item.child and measureMinHeight(item.child) or (item.resolvedCrossBasis or 0)
                local total = itemH + (m.top or 0) + (m.bottom or 0)
                if total > maxCross then maxCross = total end
            end
        end
        return maxCross + (p.top or 0) + (p.bottom or 0)
    else
        local total = (p.top or 0) + (p.bottom or 0)
        local visibleCount = 0
        for i = 1, #node.items do
            local item = node.items[i]
            if item.visible then
                visibleCount = visibleCount + 1
                local m = item.margin or { top = 0, bottom = 0 }
                local itemH = item.child and measureMinHeight(item.child) or (item.resolvedBasis or 0)
                total = total + itemH + (m.top or 0) + (m.bottom or 0)
            end
        end
        if visibleCount > 1 then
            total = total + (visibleCount - 1) * (node.gap or 0)
        end
        return total
    end
end

function ScrollView:new(x, y, width, height, opts)
    local o = ScrollContainer.new(self, x, y, width, height, opts)
    setmetatable(o, self)
    self.__index = self
    opts = opts or {}
    o._hostProps = opts.hostProps or { direction = 'column' }
    o.host = nil
    return o
end

function ScrollView:contentWidth()
    local sb = self.showScrollbar and (self.scrollbarWidth or 14) or 0
    return math.max(0, (self.width or 0) - sb)
end

function ScrollView:createChildren()
    ScrollContainer.createChildren(self)
    if not self.host then
        self.host = LayoutHost:new(0, 0, self:contentWidth(), self.height or 0, self._hostProps)
        self.host:initialise()
        self:addChild(self.host)
    elseif self.javaObject and self.host.javaObject and self.host.javaObject:getParent() ~= self.javaObject then
        -- Guard against initialise()->addScrollBars()->instantiate() followed by explicit instantiate()
        self.javaObject:AddChild(self.host.javaObject)
        self.host.parent = self
        if self.vscroll and self.vscroll.javaObject and self.vscroll.javaObject:getParent() ~= self.javaObject then
            self.javaObject:AddChild(self.vscroll.javaObject)
        end
    end
end

function ScrollView:_syncContentHeight()
    if not self.host or self.host.closed then return end
    local cw = self:contentWidth()
    local minH = measureMinHeight(self.host.rootNode)
    local targetH = math.max(self.height or 0, minH)
    self.host:setWidth(cw)
    self.host:setHeight(targetH)
    self.host:_syncBounds()
    self:setScrollHeight(minH)
end

function ScrollView:build(spec, initialContext)
    assert(self.host, 'SCROLLVIEW_NOT_INITIALIZED')
    local handles, err = self.host:build(spec, initialContext)
    if not handles then return nil, err end
    self:_syncContentHeight()
    return handles, nil
end

function ScrollView:rebuild(spec, context)
    assert(self.host, 'SCROLLVIEW_NOT_INITIALIZED')
    local handles, err = self.host:rebuild(spec, context)
    if not handles then return nil, err end
    self:_syncContentHeight()
    if self.host:isActivationValid() then
        self.host:resolveLayout()
        self:cullChildren()
    end
    return handles, nil
end

function ScrollView:setActivation(scope)
    if not self.host then return nil, 'SCROLLVIEW_NOT_INITIALIZED' end
    self:_syncContentHeight()
    local ok, err = self.host:setActivation(scope)
    self:cullChildren()
    return ok, err
end

function ScrollView:deactivate()
    if self.host then self.host:deactivate() end
end

function ScrollView:syncVisibility(context)
    if not self.host then return end
    self.host:syncVisibility(context)
    self:_syncContentHeight()
    if self.host:isActivationValid() then
        self.host:resolveLayout()
        self:cullChildren()
    end
end

local function syncAfterResize(self)
    if self.host and not self.host.closed then
        self:_syncContentHeight()
        if self.host:isActivationValid() then
            self.host:resolveLayout()
            self:cullChildren()
        end
    end
end

function ScrollView:setWidth(w)
    ScrollContainer.setWidth(self, w)
    syncAfterResize(self)
end

function ScrollView:setHeight(h)
    ScrollContainer.setHeight(self, h)
    syncAfterResize(self)
end

function ScrollView:onResize()
    ScrollContainer.onResize(self)
    syncAfterResize(self)
end

function ScrollView:cullChildren()
    if not self.cull or not self.host then return end
    local scrollY = self:getYScroll()
    local viewH = self.height or 0
    local leaves = self.host._leafItems
    if not leaves then return end
    for i = 1, #leaves do
        local entry = leaves[i]
        if entry.kind == 'native' and entry.target then
            local child = entry.target
            if entry.item and not entry.item.visible then
                child._scrollCulled = false
            else
                local childY = child:getY()
                local childH = child:getHeight()
                local visibleY = childY + scrollY
                local inView = (visibleY + childH > 0) and (visibleY < viewH)
                if not inView then
                    if child:getIsVisible() then
                        child._scrollCulled = true
                        child:setVisible(false)
                    end
                elseif child._scrollCulled then
                    child._scrollCulled = false
                    child:setVisible(true)
                end
            end
        end
    end
end

function ScrollView:dispose()
    if self.host then
        return self.host:dispose()
    end
    return true
end

return ScrollView
