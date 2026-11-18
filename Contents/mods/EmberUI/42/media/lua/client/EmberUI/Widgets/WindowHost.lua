-- WindowHost.lua - EmberUI Widgets
-- Standard draggable window shell powered by LayoutHost + PageLifecycle + FocusManager + Runtime.
-- Native B42 keyboard/ESC/Tab contract:
--   - Enables setWantKeyEvents(true) + implements onKeyPress & isKeyConsumed with eatKeyPress
--     so ESC closes cleanly without leaking OnKeyPressed(KEY_ESCAPE) to the B42 pause menu.
--   - Bridges external Cordis scopes (`opts.scope` / `attachScope`) and Runtime session teardown.

require 'ISUI/ISCollapsableWindow'
local LayoutHost = require 'EmberUI/Core/LayoutHost'
local PageLifecycle = require 'EmberUI/Core/PageLifecycle'
local Theme = require 'EmberUI/Core/Theme'
local Chrome = require 'EmberUI/Core/Chrome'
local Text = require 'EmberUI/Core/Text'
local Tooltip = require 'EmberUI/Core/TooltipManager'
local Failsafe = require 'EmberUI/Core/Failsafe'
local FocusManager = require 'EmberUI/Core/FocusManager'
local Runtime = require 'EmberUI/Core/Runtime'

---@class EmberRoutesWindowHost:ISCollapsableWindow
---@field contentHost EmberRoutesLayoutHost
---@field disposed boolean
local WindowHost = ISCollapsableWindow:derive('EmberRoutesWindowHost')

local function clampWindowToScreen(win, newW, newH)
    if not win or win.disposed then return end
    local maxW = math.max(120, newW or 1280)
    local maxH = math.max(80, newH or 720)
    if win.width > maxW then win:setWidth(maxW) end
    if win.height > maxH then win:setHeight(maxH) end
    local nx = math.max(0, math.min(win.x or 0, maxW - win.width))
    local ny = math.max(0, math.min(win.y or 0, maxH - win.height))
    if nx ~= win.x then win:setX(nx) end
    if ny ~= win.y then win:setY(ny) end
end

function WindowHost:new(x, y, width, height, opts)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    opts = opts or {}
    o.title = opts.title or ''
    o.resizable = opts.resizable == true
    o.minimumWidth = opts.minWidth or 220
    o.minimumHeight = opts.minHeight or 120
    o.closeOnEscape = opts.closeOnEscape ~= false
    o.onClose = opts.onClose
    o.drawFrame = false
    o.backgroundColor = opts.backgroundColor or Theme.window
    o.borderColor = opts.borderColor or Theme.border
    o._hostProps = opts.hostProps or { direction = 'column' }
    o.disposed = false
    o.contentHost = nil
    o.handles = nil
    o.wantKeyEvents = true
    if o.setWantKeyEvents then
        o:setWantKeyEvents(true)
    end

    local life = PageLifecycle.createLifetimeScope(o)
    local surfHandle = Runtime.trackSurface(o, { onResolutionChange = clampWindowToScreen })
    if life then
        life:own(surfHandle, function(h) h:release() end)
    end
    if opts.scope then
        PageLifecycle.attachExternalScope(o, opts.scope)
    end
    return o
end

function WindowHost:initialise()
    ISCollapsableWindow.initialise(self)
end

function WindowHost:attachScope(extScope)
    return PageLifecycle.attachExternalScope(self, extScope)
end

function WindowHost:createChildren()
    ISCollapsableWindow.createChildren(self)
    if self.setWantKeyEvents then
        self:setWantKeyEvents(true)
    end
    local th = self:titleBarHeight()
    if self.collapseButton then self.collapseButton:setVisible(false) end
    if self.pinButton then self.pinButton:setVisible(false) end
    if self.closeButton then
        self.closeButton:setX(self.width - th + 2)
        self.closeButton:setY(2)
        self.closeButton:setWidth(th - 4)
        self.closeButton:setHeight(th - 4)
    end
    local rh = (self.resizable and self.resizeWidgetHeight and self:resizeWidgetHeight()) or 0
    self.contentHost = LayoutHost:new(0, th, self.width, math.max(0, self.height - th - rh), self._hostProps)
    self.contentHost:initialise()
    self:addChild(self.contentHost)
    -- Keep resize grips above contentHost when resizable
    if self.resizable then
        if self.resizeWidget2 and self.resizeWidget2.bringToTop then self.resizeWidget2:bringToTop() end
        if self.resizeWidget and self.resizeWidget.bringToTop then self.resizeWidget:bringToTop() end
    end
    if self.closeButton and self.closeButton.bringToTop then
        self.closeButton:bringToTop()
    end
end

function WindowHost:prerender()
    local th = self:titleBarHeight()
    local winW, winH = self.width, self.height

    Chrome.shadow(self, 0, 0, winW, winH, 0.42)
    Chrome.roundedFill(self, 0, 0, winW, winH, self.backgroundColor, false, 9)
    Chrome.patternOverlay(self, 2, th, math.max(0, winW - 4), math.max(0, winH - th - 5), "pattern_hex", 0.032, Theme.border)

    Chrome.titleBar(self, 0, 0, winW, th, Theme.titleBar or Theme.panel, Theme.titleAccent, Theme.borderSubtle or self.borderColor, 9)
    Chrome.roundedBorder(self, 0, 0, winW, winH, self.borderColor, false, 9)

    if self.title and self.title ~= '' then
        local fh = type(getTextManager) == "function" and getTextManager():getFontHeight(UIFont.Small) or 14
        local maxTitleW = math.max(24, winW - th - 16)
        local clipped = Text.truncate(self.title, maxTitleW, UIFont.Small)
        Theme.text(self, clipped, 8, math.floor((th - fh) / 2), Theme.textColor)
    end

    if self._guardKey and Failsafe.hasFailed(self._guardKey) then
        Failsafe.drawFallback(self, 8, th + 8, math.max(0, winW - 16), math.max(0, winH - th - 16), self._guardKey)
    end
end

function WindowHost:ensureActivation()
    if not self.activationScope or not self.activationScope:isCurrent() then
        self.activationScope = PageLifecycle.createActivationScope(self)
        if self.activationScope and self.closeOnEscape then
            local win = self
            local sh = FocusManager.pushShortcutScope(win, {
                onEscape = function()
                    win:close()
                    return true
                end,
            })
            self.activationScope:own(sh, function(h) h:release() end)
        end
    end
    return self.activationScope
end

function WindowHost:getScope()
    return self:ensureActivation()
end

function WindowHost:registerFocusable(widget)
    local h = FocusManager.register(self, widget)
    local scope = self:ensureActivation()
    if scope then
        scope:own(h, function(handle) handle:release() end)
    end
    return h
end

function WindowHost:setContentSpec(spec, initialContext)
    assert(self.contentHost and not self.disposed, 'WINDOW_HOST_NOT_READY')
    self._guardKey = self._guardKey or ('WindowHost:' .. tostring(self.title ~= '' and self.title or self))
    Failsafe.reset(self._guardKey)
    if not self.contentHost._emberFailsafeWrapped then
        self.contentHost._emberFailsafeWrapped = true
        local hostSelf = self
        for _, method in ipairs({ 'prerender', 'render', 'update' }) do
            local orig = self.contentHost[method]
            if type(orig) == 'function' then
                self.contentHost[method] = function(chSelf, ...)
                    local ok = Failsafe.guard(hostSelf._guardKey, orig, chSelf, ...)
                    if not ok and chSelf.setVisible then
                        chSelf:setVisible(false)
                    end
                end
            end
        end
    end
    local ok, handles, err = Failsafe.guard(self._guardKey, function()
        return self.contentHost:build(spec, initialContext)
    end)
    if not ok then
        self.contentHost:setVisible(false)
        return nil, handles
    end
    if not handles then return nil, err end
    self.contentHost:setVisible(true)
    self.handles = handles
    local scope = self:ensureActivation()
    self.contentHost:setActivation(scope)
    return handles, nil
end

function WindowHost:rebuildContent(spec, context)
    assert(self.contentHost and not self.disposed, 'WINDOW_HOST_NOT_READY')
    local handles, err = self.contentHost:rebuild(spec, context)
    if not handles then return nil, err end
    self.handles = handles
    return handles, nil
end

function WindowHost:onResize()
    if self.minimumWidth and self.width < self.minimumWidth then
        self:setWidth(self.minimumWidth)
    end
    if self.minimumHeight and self.height < self.minimumHeight then
        self:setHeight(self.minimumHeight)
    end
    ISCollapsableWindow.onResize(self)
    local th = self:titleBarHeight()
    local rh = (self.resizable and self.resizeWidgetHeight and self:resizeWidgetHeight()) or 0
    if self.closeButton then
        self.closeButton:setX(self.width - th + 2)
        self.closeButton:setY(2)
        self.closeButton:setWidth(th - 4)
        self.closeButton:setHeight(th - 4)
    end
    if self.contentHost and not self.contentHost.closed and not self.disposed then
        self.contentHost:setX(0)
        self.contentHost:setY(th)
        self.contentHost:setWidth(self.width)
        self.contentHost:setHeight(math.max(0, self.height - th - rh))
        self.contentHost:requestLayout()
    end
end

function WindowHost:close()
    if self.disposed then return end
    self.disposed = true
    FocusManager.unfocusTree(self)
    FocusManager.clearGroup(self)
    if self.contentHost and not self.contentHost.closed then
        self.contentHost:dispose()
    end
    PageLifecycle.unmount(self)
    PageLifecycle.dispose(self)
    Tooltip.unregisterOwner(self)
    self:setVisible(false)
    self:removeFromUIManager()
    if self.onClose then
        pcall(self.onClose, self)
    end
end

function WindowHost:bindStore(store, callback)
    return self:ensureActivation():bindStore(store, callback)
end

function WindowHost:onKeyPress(key)
    local win = self
    return FocusManager.handleWindowKeyPress(self, key, self.closeOnEscape and function()
        win:close()
        return true
    end or nil)
end

function WindowHost:isKeyConsumed(key)
    return FocusManager.isWindowKeyConsumed(self, key, self.closeOnEscape)
end

return WindowHost
