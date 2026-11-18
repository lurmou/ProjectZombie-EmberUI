require 'ISUI/ISPanel'
local Theme = require 'EmberUI/Core/Theme'
local ScrollContainer = ISPanel:derive('EmberRoutesScrollContainer')

---Creates a high-performance scroll container with OpenGL stencil clipping and
---viewport frustum culling to eliminate Project Zomboid Java mouse event penetration.
---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table? Configuration options: { scrollSpeed, clip, cull, scrollHeight, scrollbarWidth, showScrollbar, background, onScroll }
---@return table ScrollContainer instance
function ScrollContainer:new(x, y, width, height, opts)
    local o = ISPanel.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    opts = opts or {}
    o.background = opts.background == true
    o.scrollSpeed = opts.scrollSpeed or 24
    o.clip = opts.clip ~= false
    o.cull = opts.cull ~= false
    o.scrollHeight = opts.scrollHeight or height
    o.scrollbarWidth = opts.scrollbarWidth or 14
    o.showScrollbar = opts.showScrollbar ~= false
    o.onScroll = opts.onScroll

    o:setScrollChildren(true)
    return o
end

function ScrollContainer:initialise()
    ISPanel.initialise(self)
    if self.showScrollbar and self.addScrollBars then
        self:addScrollBars()
        if self.vscroll then Theme.scrollbar(self.vscroll) end
        if self.hscroll then Theme.scrollbar(self.hscroll) end
    end
end

---Culls direct child widgets outside the visible viewport by toggling visibility.
---This prevents out-of-bounds children from capturing Java mouse clicks through the stencil mask.
function ScrollContainer:cullChildren()
    if not self.cull then return end
    local children = self:getChildren()
    if not children then return end
    local scrollY = self:getYScroll()
    local viewH = self.height

    local size = children:size()
    for i = 0, size - 1 do
        local child = children:get(i)
        if child and child ~= self.vscroll and child ~= self.hscroll then
            local childY = child:getY()
            local childH = child:getHeight()
            local visibleY = childY + scrollY
            local inView = (visibleY + childH > 0) and (visibleY < viewH)

            if not inView then
                if child:getIsVisible() then
                    child._scrollCulled = true
                    child:setVisible(false)
                end
            else
                if child._scrollCulled then
                    child._scrollCulled = false
                    child:setVisible(true)
                end
            end
        end
    end
end

function ScrollContainer:getScrollHeight()
    return self.scrollHeight or 0
end

function ScrollContainer:setScrollHeight(h)
    self.scrollHeight = math.max(0, h or 0)
    if ISPanel.setScrollHeight then ISPanel.setScrollHeight(self, self.scrollHeight) end
    local maxScroll = math.max(0, self.scrollHeight - self.height)
    local cur = self:getYScroll()
    local clamped = math.max(-maxScroll, math.min(0, cur))
    if clamped ~= cur then
        self:setYScroll(clamped)
    end
    self:cullChildren()
end

function ScrollContainer:onMouseWheel(del)
    local maxScroll = math.max(0, self.scrollHeight - self.height)
    if maxScroll <= 0 then
        self:setYScroll(0)
        self:cullChildren()
        return true
    end

    local cur = self:getYScroll()
    local target = cur - (del * self.scrollSpeed)
    local clamped = math.max(-maxScroll, math.min(0, target))
    self:setYScroll(clamped)
    self:cullChildren()
    if self.onScroll then self.onScroll(clamped) end
    return true
end

function ScrollContainer:addChild(child)
    ISPanel.addChild(self, child)
    local childBottom = child:getY() + child:getHeight()
    if childBottom > self.scrollHeight then
        self:setScrollHeight(childBottom)
    else
        self:cullChildren()
    end
end

function ScrollContainer:onResize()
    ISPanel.onResize(self)
    self:setScrollHeight(self.scrollHeight)
end

function ScrollContainer:update()
    ISPanel.update(self)
    self:cullChildren()
end

function ScrollContainer:prerender()
    local vs = self.vscroll
    if vs then
        if not vs._emberScrollSkinned then Theme.scrollbar(vs) end
        local vw = vs.width or 7
        if vw > 8 then
            vw = 7
            if vs.setWidth then vs:setWidth(vw) end
        end
        local targetX = math.max(0, (self.width or 0) - vw)
        local curX = vs.getX and vs:getX() or vs.x
        local curH = vs.getHeight and vs:getHeight() or vs.height
        if curX ~= targetX and vs.setX then vs:setX(targetX) end
        if curH ~= self.height and vs.setHeight then vs:setHeight(self.height) end
    end
    if self.hscroll and not self.hscroll._emberScrollSkinned then Theme.scrollbar(self.hscroll) end
    ISPanel.prerender(self)
    if self.clip then
        self:setStencilRect(0, 0, self.width, self.height)
    end
end

function ScrollContainer:render()
    if self.clip then
        self:clearStencilRect()
    end
    ISPanel.render(self)
end

return ScrollContainer
