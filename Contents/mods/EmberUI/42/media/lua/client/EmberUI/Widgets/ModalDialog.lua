-- ModalDialog.lua - EmberUI Widgets
-- Full-screen blocking modal overlay with centered card powered by LayoutHost + PageLifecycle.
-- Fixes B42 keyboard/ESC consumption, disposes ActivationScope & LifetimeScope symmetrically,
-- unfocuses child text entries on close, and recenters automatically on resolution change.

require "ISUI/ISPanel"
require "ISUI/ISButton"
local LayoutHost = require "EmberUI/Core/LayoutHost"
local PageLifecycle = require "EmberUI/Core/PageLifecycle"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local Text = require "EmberUI/Core/Text"
local FocusManager = require "EmberUI/Core/FocusManager"
local Runtime = require "EmberUI/Core/Runtime"

---@class EmberRoutesModalDialog:ISPanel
local ModalDialog = ISPanel:derive("EmberRoutesModalDialog")

local function modalText(emberKey, vanillaKey, enFallback)
    if type(getTextOrNull) == "function" then
        local v = getTextOrNull("IGUI_EmberUI_UI_" .. emberKey)
        if v and v ~= "" then return v end
        if vanillaKey then
            local vv = getTextOrNull(vanillaKey)
            if vv and vv ~= "" then return vv end
        end
    end
    return enFallback
end

local function relayoutModal(modal, sw, sh)
    if not modal or modal.disposed then return end
    modal:setX(0)
    modal:setY(0)
    modal:setWidth(sw)
    modal:setHeight(sh)

    modal.cardWidth = math.min(sw - 40, modal.requestedCardW or 480)
    modal.cardHeight = math.min(sh - 40, modal.requestedCardH or 320)
    modal.cardX = math.floor((sw - modal.cardWidth) / 2)
    modal.cardY = math.floor((sh - modal.cardHeight) / 2)

    local cx, cy, cw, ch = modal.cardX, modal.cardY, modal.cardWidth, modal.cardHeight
    local titleH = 28
    local footerH = modal.showFooter and 38 or 0
    local p = 12
    local btnSize = 20

    if modal.closeButton then
        modal.closeButton:setX(cx + cw - btnSize - 6)
        modal.closeButton:setY(cy + 4)
    end
    if modal.showFooter then
        local btnW = 84
        local btnH = 26
        local btnY = cy + ch - btnH - 6
        local btnGap = 8
        if modal.confirmButton then
            modal.confirmButton:setX(cx + cw - btnW - p)
            modal.confirmButton:setY(btnY)
        end
        if modal.cancelButton then
            modal.cancelButton:setX(cx + cw - btnW * 2 - p - btnGap)
            modal.cancelButton:setY(btnY)
        end
    end
    if modal.contentHost and not modal.contentHost.closed then
        modal.contentHost:setX(cx + p)
        modal.contentHost:setY(cy + titleH + math.floor(p / 2))
        modal.contentHost:setWidth(cw - p * 2)
        modal.contentHost:setHeight(math.max(0, ch - titleH - footerH - p))
        modal.contentHost:requestLayout()
    end
end

function ModalDialog:new(cardW, cardH, opts)
    local core = type(getCore) == "function" and getCore() or nil
    local sw = (core and core.getScreenWidth and core:getScreenWidth()) or 1280
    local sh = (core and core.getScreenHeight and core:getScreenHeight()) or 720
    local o = ISPanel.new(self, 0, 0, sw, sh)
    setmetatable(o, self)
    self.__index = self

    opts = opts or {}
    o.opts = opts
    o.title = opts.title or ""
    o.requestedCardW = cardW or 480
    o.requestedCardH = cardH or 320
    o.cardWidth = math.min(sw - 40, o.requestedCardW)
    o.cardHeight = math.min(sh - 40, o.requestedCardH)
    o.cardX = math.floor((sw - o.cardWidth) / 2)
    o.cardY = math.floor((sh - o.cardHeight) / 2)
    o.closeOnBackdropClick = opts.closeOnBackdropClick == true
    o.closeOnEscape = opts.closeOnEscape ~= false
    o.showFooter = opts.showFooter ~= false and (opts.onConfirm ~= nil or opts.onCancel ~= nil or opts.showFooter == true)
    o.confirmText = opts.confirmText or modalText("Ok", "UI_Ok", "OK")
    o.cancelText = opts.cancelText or modalText("Cancel", "UI_Cancel", "Cancel")
    o.owner = opts.owner
    o.disposed = false
    o.background = false
    o.keepOnScreen = false
    o.wantKeyEvents = true
    if o.setWantKeyEvents then o:setWantKeyEvents(true) end

    local life = PageLifecycle.createLifetimeScope(o)
    local surfHandle = Runtime.trackSurface(o, { onResolutionChange = relayoutModal })
    if life then
        life:own(surfHandle, function(h) h:release() end)
    end
    if opts.scope then
        PageLifecycle.attachExternalScope(o, opts.scope)
    end

    return o
end

function ModalDialog:initialise()
    ISPanel.initialise(self)
end

function ModalDialog:createChildren()
    ISPanel.createChildren(self)
    if self.setWantKeyEvents then self:setWantKeyEvents(true) end

    local cx, cy = self.cardX, self.cardY
    local cw, ch = self.cardWidth, self.cardHeight
    local titleH = 28
    local footerH = self.showFooter and 38 or 0
    local p = 12

    local btnSize = 20
    self.closeButton = ISButton:new(cx + cw - btnSize - 6, cy + 4, btnSize, btnSize, "X", self, function()
        self:close("CLOSE_BUTTON")
    end)
    self.closeButton:initialise()
    Theme.button(self.closeButton, false)
    self:addChild(self.closeButton)

    if self.showFooter then
        local btnW = 84
        local btnH = 26
        local btnY = cy + ch - btnH - 6
        local btnGap = 8

        self.confirmButton = ISButton:new(cx + cw - btnW - p, btnY, btnW, btnH, self.confirmText, self, function()
            self:onConfirmClicked()
        end)
        self.confirmButton:initialise()
        Theme.button(self.confirmButton, not self.opts.danger)
        if self.opts.danger then
            self.confirmButton.borderColor = { r = 0.95, g = 0.35, b = 0.30, a = 1.0 }
            self.confirmButton.emberNormalBorder = self.confirmButton.borderColor
            self.confirmButton.textColor = { r = 0.95, g = 0.35, b = 0.30, a = 1.0 }
            self.confirmButton.emberNormalText = self.confirmButton.textColor
        end
        self:addChild(self.confirmButton)

        self.cancelButton = ISButton:new(cx + cw - btnW * 2 - p - btnGap, btnY, btnW, btnH, self.cancelText, self, function()
            self:close("CANCEL")
        end)
        self.cancelButton:initialise()
        Theme.button(self.cancelButton, false)
        self:addChild(self.cancelButton)
    end

    local msg = self.opts.message or self.opts.prompt
    if msg and msg ~= "" then
        self.messageLines = Text.wrapLimited(msg, cw - p * 2, UIFont.Small, 6)
    end

    local contentX = cx + p
    local contentY = cy + titleH + math.floor(p / 2)
    local contentW = cw - p * 2
    local contentH = math.max(0, ch - titleH - footerH - p)

    self.contentHost = LayoutHost:new(contentX, contentY, contentW, contentH, { direction = "column" })
    self.contentHost:initialise()
    self:addChild(self.contentHost)

    if self.opts.content then
        local spec = self.opts.content(self.contentHost, self)
        if spec then
            local handles, err = self.contentHost:build(spec, self.opts.initialContext)
            assert(handles, err or "MODAL_BUILD_FAILED")
            self.handles = handles
        end
    end

    self.activationScope = PageLifecycle.createActivationScope(self)
    if self.activationScope then
        local modalSelf = self
        local sh = FocusManager.pushShortcutScope(modalSelf, {
            onEscape = function()
                if modalSelf.closeOnEscape then
                    modalSelf:close("CANCEL")
                    return true
                end
                return true
            end,
            onKey = function(_, key)
                local retKey = (Keyboard and Keyboard.KEY_RETURN) or 28
                if key == retKey and modalSelf.showFooter and not FocusManager.isTextInputActive() then
                    modalSelf:onConfirmClicked()
                    return true
                end
                return false
            end,
        })
        self.activationScope:own(sh, function(h) h:release() end)
        self.contentHost:setActivation(self.activationScope)
    end
end

function ModalDialog:onConfirmClicked()
    if self.opts.onConfirm then
        local keepOpen = self.opts.onConfirm(self)
        if keepOpen == true then return end
    end
    self:close("CONFIRM")
end

function ModalDialog:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.60, 0, 0, 0)

    local cx, cy, cw, ch = self.cardX, self.cardY, self.cardWidth, self.cardHeight
    Chrome.shadow(self, cx, cy, cw, ch, 0.50)
    Chrome.roundedRect(self, cx, cy, cw, ch, Theme.window, Theme.border, false, 9)

    local accent = self.opts.danger and Theme.danger or Theme.titleAccent
    Chrome.titleBar(self, cx + 1, cy + 1, math.max(0, cw - 2), 27, Theme.titleBar or Theme.panel, accent, Theme.border, 9)
    if self.title and #self.title > 0 then
        local clipped = Text.truncate(self.title, math.max(24, cw - 44), UIFont.Small)
        Theme.text(self, clipped, cx + 12, cy + 6, self.opts.danger and Theme.danger or Theme.gold)
    end

    if self.showFooter then
        Theme.rect(self, cx, cy + ch - 38, cw, 1, Theme.border)
    end

    if self.messageLines and #self.messageLines > 0 then
        local my = cy + 28 + 14
        local tm = type(getTextManager) == "function" and getTextManager() or nil
        local fontH = (tm and tm.getFontHeight and tm:getFontHeight(UIFont.Small)) or 14
        for _, line in ipairs(self.messageLines) do
            Theme.text(self, line, cx + 16, my, Theme.textColor, UIFont.Small)
            my = my + fontH + 4
        end
    end
end

function ModalDialog:onMouseDown(x, y)
    if self.disposed then return true end
    local cx, cy, cw, ch = self.cardX, self.cardY, self.cardWidth, self.cardHeight
    local inside = x >= cx and x <= cx + cw and y >= cy and y <= cy + ch
    if not inside and self.closeOnBackdropClick then
        self:close("BACKDROP")
    end
    return true
end

function ModalDialog:onMouseUp() return true end
function ModalDialog:onMouseMove() return true end
function ModalDialog:onRightMouseDown() return true end
function ModalDialog:onRightMouseUp() return true end

function ModalDialog:onKeyPress(key)
    local modalSelf = self
    return FocusManager.handleWindowKeyPress(self, key, self.closeOnEscape and function()
        modalSelf:close("CANCEL")
        return true
    end or nil)
end

function ModalDialog:isKeyConsumed(key)
    local retKey = (Keyboard and Keyboard.KEY_RETURN) or 28
    if key == retKey and self.showFooter then
        return true
    end
    return FocusManager.isWindowKeyConsumed(self, key, true)
end

function ModalDialog:close(reason)
    if self.disposed then return end
    self.disposed = true

    FocusManager.unfocusTree(self)
    FocusManager.clearGroup(self)

    if self.contentHost and not self.contentHost.closed then
        self.contentHost:dispose()
        self.contentHost = nil
    end

    PageLifecycle.unmount(self)
    PageLifecycle.dispose(self)

    self:setVisible(false)
    self:removeFromUIManager()

    if self.opts.onClose then
        self.opts.onClose(self, reason or "CLOSE")
    end
    if reason == "CANCEL" and self.opts.onCancel then
        self.opts.onCancel(self)
    end
end

function ModalDialog.show(opts)
    opts = opts or {}
    local modal = ModalDialog:new(opts.width, opts.height, opts)
    modal:initialise()
    modal:instantiate()
    modal:addToUIManager()
    if modal.setAlwaysOnTop then modal:setAlwaysOnTop(true) end
    if modal.bringToTop then modal:bringToTop() end
    return modal
end

function ModalDialog.confirm(actor, opts)
    opts = opts or {}
    opts.showFooter = true
    opts.width = opts.width or 420
    opts.height = opts.height or 170
    opts.title = opts.title or modalText("ConfirmTitle", "UI_Confirm", "Confirm Action")
    opts.confirmText = opts.confirmText or modalText("Confirm", "UI_Yes", "Confirm")
    opts.cancelText = opts.cancelText or modalText("Cancel", "UI_No", "Cancel")
    local modal = ModalDialog.show(opts)
    if actor and actor.getJoypadBind and actor:getJoypadBind() ~= -1 and setJoypadFocus then
        setJoypadFocus(actor:getIndex(), modal)
    end
    return modal
end

return ModalDialog
