--[[
    CardPanel.lua - EmberRoutes UI
    Unified survival-aesthetic card container.
    Eliminates dozens of repetitive manual Theme.rect calls, providing a consistent
    card style with header, icon slot, top-right status badge, and hover/selection states.
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Failsafe = require "EmberUI/Core/Failsafe"
local Visual = require "EmberUI/Widgets/StatusVisual"

---@class EmberRoutesCardPanel:ISPanel
---@field fontHeight number
---@field pad number
---@field title string?
---@field subtitle string?
---@field titleColor table?
---@field icon Texture?
---@field iconSize number
---@field badge string?
---@field badgeColor table?
---@field selected boolean
---@field hover boolean
---@field headerHeight number
---@field contentBounds {x:number, y:number, width:number, height:number}
local CardPanel = ISPanel:derive("EmberRoutesCardPanel")

-- Draw-loop caches: the small font height is constant for the session and badge
-- widths repeat, so neither should reach the font manager every frame.
local smallFontHeight
local badgeWidthCache={}
local function smallHeight()
    if not smallFontHeight then smallFontHeight=getTextManager():getFontHeight(UIFont.Small) end
    return smallFontHeight
end
local function cachedMeasure(text)
    local width=badgeWidthCache[text]
    if not width then
        width=getTextManager():MeasureStringX(UIFont.Small,text)
        badgeWidthCache[text]=width
    end
    return width
end

---Static zero-GC draw function for drawing a card inside list rows or custom prerender loops.
---@param owner ISPanel
---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table? {title=string, titleColor=table, icon=Texture, iconSize=number, badge=string, badgeColor=table, selected=boolean, hover=boolean, statusColor=table, headerHeight=number}
function CardPanel.draw(owner, x, y, width, height, opts)
    opts = opts or {}
    local isSelected = opts.selected or false
    local isHover = opts.hover or false

    -- 1. Card Background & Border (single source of truth in Theme + 9-slice Chrome)
    local bg = isSelected and Theme.selected or (isHover and Theme.hover or opts.backgroundColor or Theme.card or Theme.panel)
    local border = opts.borderColor or (isSelected and (Theme.selectedBorder or Theme.border) or (isHover and (Theme.hoverBorder or Theme.accent) or Theme.border))

    local isCustomFrame = (opts.frameStyle == 'briefing' or opts.frameStyle == 'plain')
    if opts.frameStyle=='briefing' then
        Theme.rect(owner, x, y, width, height, bg)
        local edge=math.min(14,width/4,height/4)
        Theme.rect(owner,x,y,edge,1,border) Theme.rect(owner,x,y,1,edge,border)
        Theme.rect(owner,x+width-edge,y,edge,1,border) Theme.rect(owner,x+width-1,y,1,edge,border)
        Theme.rect(owner,x,y+height-1,edge,1,border) Theme.rect(owner,x,y+height-edge,1,edge,border)
        Theme.rect(owner,x+width-edge,y+height-1,edge,1,border) Theme.rect(owner,x+width-1,y+height-edge,1,edge,border)
    elseif opts.frameStyle=='plain' then
        Theme.rect(owner, x, y, width, height, bg)
        Theme.rect(owner,x,y+height-1,width,1,border)
    else
        Chrome.roundedFill(owner, x, y, width, height, bg, false, 9)
    end

    -- 2. Optional Header (unified title bar wash + accent rule)
    if opts.title and opts.title ~= "" then
        local h = smallHeight()
        local pad = math.max(4, math.floor(h * 0.4))
        local headerH = opts.headerHeight or (h + pad)

        if not isCustomFrame then
            local headerFill = isSelected and Theme.selected or (Theme.titleBar or Theme.panel)
            local accent = opts.statusColor or (isSelected and Theme.titleAccent) or nil
            Chrome.titleBar(owner, x, y, width, headerH, headerFill, accent, Theme.borderSubtle or border, 9)
        else
            local divider = opts.dividerColor
            if not divider or opts.dividerFor ~= border then
                divider = {r = border.r, g = border.g, b = border.b, a = 0.35}
                opts.dividerColor = divider
                opts.dividerFor = border
            end
            Theme.rect(owner, x + 1, y + headerH, width - 2, 1, divider)
        end

        local textX = x + pad
        local iconSize = opts.iconSize or h

        -- Icon
        if opts.icon then
            owner:drawTextureScaledAspect(opts.icon, textX, y + math.floor((headerH - iconSize) / 2), iconSize, iconSize, 1, 1, 1, 1)
            textX = textX + iconSize + pad / 2
        end

        -- Title
        local titleCol = opts.titleColor or Theme.gold
        Theme.text(owner, opts.title, textX, y + math.floor((headerH - h) / 2), titleCol)

        -- Top-right badge & collapse chevron
        local rightPad = pad
        if opts.collapsible then
            local chevSize = math.min(12, math.max(8, h - 2))
            local cx = x + width - chevSize - pad
            local cy = y + math.floor((headerH - chevSize) / 2)
            Visual.icon(owner, cx, cy, chevSize, opts.collapsed and "chevronDown" or "chevronUp", Theme.muted)
            rightPad = rightPad + chevSize + 6
        end
        if opts.badge and opts.badge ~= "" then
            local bw = cachedMeasure(opts.badge)
            local bx = x + width - bw - rightPad
            local bCol = opts.badgeColor or Theme.accent
            Theme.text(owner, opts.badge, bx, y + math.floor((headerH - h) / 2), bCol)
        end
    end

    if not isCustomFrame then
        Chrome.roundedBorder(owner, x, y, width, height, border, false, 9)
    end
end

---Create an ISPanel CardPanel instance.
---@param x number
---@param y number
---@param width number
---@param height number
---@param opts table?
---@return EmberRoutesCardPanel
function CardPanel:new(x, y, width, height, opts)
    opts = opts or {}
    local o = ISPanel.new(self, x, y, width, height)
    o.background = false
    o.fontHeight = getTextManager():getFontHeight(UIFont.Small)
    o.pad = math.ceil(o.fontHeight * 0.4)
    o.title = opts.title
    o.titleColor = opts.titleColor or Theme.gold
    o.icon = opts.icon
    o.iconSize = opts.iconSize or o.fontHeight
    o.badge = opts.badge
    o.badgeColor = opts.badgeColor or Theme.accent
    o.selected = opts.selected or false
    o.hover = opts.hover or false
    o.statusColor = opts.statusColor
    o.collapsible = opts.collapsible == true
    o.collapsed = opts.collapsed == true
    o.onToggle = opts.onToggle
    o._hostProps = opts.hostProps or { direction = "column", gap = o.pad, align = "stretch" }
    o._pendingSpec = opts.contentSpec
    o._pendingContext = opts.context
    o._pendingScope = opts.scope
    o.headerHeight = (opts.title or o.collapsible) and (o.fontHeight + o.pad) or 0

    local contentY = o.headerHeight > 0 and (o.headerHeight + 2) or 0
    o.contentBounds = {
        x = o.pad,
        y = contentY + o.pad / 2,
        width = math.max(0, width - o.pad * 2),
        height = math.max(0, height - contentY - o.pad)
    }

    o._drawOpts = {
        title = o.title,
        titleColor = o.titleColor,
        icon = o.icon,
        iconSize = o.iconSize,
        badge = o.badge,
        badgeColor = o.badgeColor,
        selected = o.selected,
        hover = o.hover,
        statusColor = o.statusColor,
        headerHeight = o.headerHeight,
        collapsible = o.collapsible,
        collapsed = o.collapsed
    }

    o:initialise()
    return o
end

function CardPanel:initialise()
    ISPanel.initialise(self)
end

function CardPanel:createChildren()
    ISPanel.createChildren(self)
    if self._pendingSpec and not self.contentHost then
        self:setContentSpec(self._pendingSpec, self._pendingContext, self._pendingScope)
        self._pendingSpec = nil
        self._pendingContext = nil
        self._pendingScope = nil
    end
end

function CardPanel:syncContentBounds()
    local contentY = self.headerHeight > 0 and (self.headerHeight + 2) or 0
    local cb = self.contentBounds
    cb.x = self.pad
    cb.y = contentY + self.pad / 2
    cb.width = math.max(0, (self.width or 0) - self.pad * 2)
    cb.height = math.max(0, (self.height or 0) - contentY - self.pad)
    if self.contentHost and not self.contentHost.closed then
        self.contentHost:setX(cb.x)
        self.contentHost:setY(cb.y)
        self.contentHost:setWidth(cb.width)
        self.contentHost:setHeight(cb.height)
        self.contentHost:setVisible(not self.collapsed)
        self.contentHost:requestLayout()
        if not self.collapsed and cb.width > 0 and cb.height > 0 and self.contentHost.built and self.contentHost:isActivationValid() then
            self.contentHost:resolveLayout()
        end
    end
end

function CardPanel:setContentSpec(spec, initialContext, scope)
    if self.collapsed == nil then self.collapsed = false end
    self._guardKey = self._guardKey or ("CardPanel:" .. tostring(self.title or self))
    Failsafe.reset(self._guardKey)
    if not self.contentHost then
        local LayoutHost = require "EmberUI/Core/LayoutHost"
        local cb = self.contentBounds
        self.contentHost = LayoutHost:new(cb.x, cb.y, cb.width, cb.height, self._hostProps)
        self.contentHost:initialise()
        self:addChild(self.contentHost)
    end
    if not self.contentHost._emberFailsafeWrapped then
        self.contentHost._emberFailsafeWrapped = true
        local cardSelf = self
        for _, method in ipairs({ "prerender", "render", "update" }) do
            local orig = self.contentHost[method]
            if type(orig) == "function" then
                self.contentHost[method] = function(chSelf, ...)
                    local ok = Failsafe.guard(cardSelf._guardKey, orig, chSelf, ...)
                    if not ok and chSelf.setVisible then
                        chSelf:setVisible(false)
                    end
                end
            end
        end
    end
    local ok, handles, err = Failsafe.guard(self._guardKey, function()
        local h, e
        if self.contentHost.built then
            h, e = self.contentHost:rebuild(spec, initialContext)
        else
            h, e = self.contentHost:build(spec, initialContext)
        end
        if not h then
            error(tostring(e or self.contentHost.errorMessage or "CARDPANEL_BUILD_FAILED"), 0)
        end
        return h, e
    end)
    if not ok or not handles then
        if self.contentHost then self.contentHost:setVisible(false) end
        return nil, err or handles
    end
    self.contentHost:setVisible(not self.collapsed)
    if scope then
        self:setActivation(scope)
    elseif self.contentHost.isActivationValid and self.contentHost:isActivationValid() then
        self.contentHost:flushLayout()
    end
    self:syncContentBounds()
    return handles, nil
end

function CardPanel:setActivation(scope)
    if self.contentHost and not self.contentHost.closed and self.contentHost.built and scope and scope:isCurrent() then
        self.contentHost:setActivation(scope)
        self:syncContentBounds()
        self.contentHost:flushLayout()
    end
end

function CardPanel:setCollapsed(collapsed, silent)
    local nextState = collapsed == true
    if self.collapsed == nextState then return end
    self.collapsed = nextState
    if self._drawOpts then self._drawOpts.collapsed = nextState end
    if self.contentHost and not self.contentHost.closed then
        self.contentHost:setVisible(not nextState)
    end
    if not silent and self.onToggle then
        self.onToggle(nextState, self)
    end
end

function CardPanel:toggleCollapsed()
    self:setCollapsed(not self.collapsed, false)
end

function CardPanel:onMouseDown(x, y)
    if self.collapsible and self.headerHeight > 0 and y >= 0 and y <= self.headerHeight then
        self:toggleCollapsed()
        return true
    end
    return false
end

function CardPanel:setWidth(w)
    ISPanel.setWidth(self, w)
    self:syncContentBounds()
end

function CardPanel:setHeight(h)
    ISPanel.setHeight(self, h)
    self:syncContentBounds()
end

function CardPanel:onResize()
    ISPanel.onResize(self)
    self:syncContentBounds()
end

function CardPanel:dispose()
    if self.contentHost and not self.contentHost.closed then
        self.contentHost:dispose()
    end
    self.contentHost = nil
end

function CardPanel:setSelected(selected)
    self.selected = selected or false
    if self._drawOpts then self._drawOpts.selected = self.selected end
end

function CardPanel:prerender()
    ISPanel.prerender(self)
    local opts = self._drawOpts
    opts.title = self.title
    opts.titleColor = self.titleColor
    opts.icon = self.icon
    opts.iconSize = self.iconSize
    opts.badge = self.badge
    opts.badgeColor = self.badgeColor
    opts.selected = self.selected
    opts.hover = self.hover
    opts.statusColor = self.statusColor
    opts.headerHeight = self.headerHeight
    opts.collapsible = self.collapsible
    opts.collapsed = self.collapsed
    CardPanel.draw(self, 0, 0, self.width, self.height, opts)
    if not self.collapsed and self._guardKey and Failsafe.hasFailed(self._guardKey) then
        local cb = self.contentBounds
        if cb and cb.width > 0 and cb.height > 0 then
            Failsafe.drawFallback(self, cb.x, cb.y, cb.width, cb.height, self._guardKey)
        end
    end
end

return CardPanel
