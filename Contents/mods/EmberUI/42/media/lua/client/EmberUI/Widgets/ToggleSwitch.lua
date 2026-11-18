--[[
    ToggleSwitch.lua - EmberRoutes UI Core
    Animated LFS-style pill toggle switch backed by SpringDriver and Chrome.pill.
    Replaces bulky full-width boolean buttons and square tickboxes with tactile
    on/off semantics, optional right-side label, keyboard toggling, and Zero-GC render.
]]

require "ISUI/ISPanel"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local SpringDriver = require "EmberUI/Core/SpringDriver"

---@class EmberRoutesToggleSwitch:ISPanel
---@field checked boolean
---@field enable boolean
---@field label string?
---@field target any?
---@field onChange fun(target:any, checked:boolean, switch:EmberRoutesToggleSwitch)?
local ToggleSwitch = ISPanel:derive("EmberRoutesToggleSwitch")

local KNOB_ACTIVE = { r = 0.96, g = 0.98, b = 1.00, a = 1.0 }
local KNOB_IDLE = { r = 0.72, g = 0.77, b = 0.84, a = 1.0 }
local KNOB_DISABLED = { r = 0.45, g = 0.48, b = 0.54, a = 0.85 }
local TRACK_BUF = { r = 0, g = 0, b = 0, a = 1 }
local BORDER_BUF = { r = 0, g = 0, b = 0, a = 1 }

local function lerpColor(dst, a, b, t)
    local inv = 1 - t
    dst.r = (a.r or 0) * inv + (b.r or 0) * t
    dst.g = (a.g or 0) * inv + (b.g or 0) * t
    dst.b = (a.b or 0) * inv + (b.b or 0) * t
    dst.a = (a.a or 1) * inv + (b.a or 1) * t
end

---@param x number
---@param y number
---@param width number?
---@param height number?
---@param checked boolean?
---@param target any?
---@param onChange fun(target:any, checked:boolean, switch:EmberRoutesToggleSwitch)?
---@param opts table? { label:string?, font:any?, enable:boolean?, tooltip:string? }
---@return EmberRoutesToggleSwitch
function ToggleSwitch:new(x, y, width, height, checked, target, onChange, opts)
    opts = opts or {}
    local tm = getTextManager and getTextManager()
    local fh = (tm and tm.getFontHeight and tm:getFontHeight(opts.font or UIFont.Small)) or 14
    local h = height or math.max(22, fh + 6)
    local trackW = opts.trackWidth or 38
    local labelW = 0
    if opts.label and opts.label ~= "" then
        labelW = (tm and tm.MeasureStringX and tm:MeasureStringX(opts.font or UIFont.Small, opts.label)) or (#opts.label * 7)
    end
    local w = width or (labelW > 0 and (trackW + 8 + labelW) or trackW)

    local o = ISPanel.new(self, x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.checked = checked == true
    o.enable = opts.enable ~= false
    o.label = opts.label
    o.font = opts.font or UIFont.Small
    o.fontHeight = fh
    o.trackWidth = trackW
    o.trackHeight = math.min(20, math.max(16, h - 4))
    o.target = target
    o.onChange = onChange
    o.tooltip = opts.tooltip
    o.spring = SpringDriver.create(o.checked and 1.0 or 0.0, { stiffness = 380, damping = 28, precision = 0.01 })
    o:initialise()
    return o
end

function ToggleSwitch:initialise()
    ISPanel.initialise(self)
end

function ToggleSwitch:isChecked()
    return self.checked == true
end

function ToggleSwitch:setChecked(checked, silent)
    local nextVal = checked == true
    local changed = self.checked ~= nextVal
    self.checked = nextVal
    if changed and not silent and self.onChange then
        self.onChange(self.target, self.checked, self)
    end
end

function ToggleSwitch:toggle()
    if not self.enable then return false end
    self:setChecked(not self.checked, false)
    if getSoundManager then
        pcall(function() getSoundManager():playUISound("UIToggleTickBox") end)
    end
    return true
end

function ToggleSwitch:setEnable(enabled)
    self.enable = enabled ~= false
end

function ToggleSwitch:onMouseDown()
    if not self.enable then return false end
    self._pressed = true
    return true
end

function ToggleSwitch:onMouseUp(x, y)
    local wasPressed = self._pressed
    self._pressed = false
    if not self.enable then return false end
    if wasPressed and x >= 0 and x <= self.width and y >= 0 and y <= self.height then
        self:toggle()
        return true
    end
    return false
end

function ToggleSwitch:onMouseUpOutside()
    self._pressed = false
end

function ToggleSwitch:onKeyPress(key)
    if not self.enable then return false end
    if key == Keyboard.KEY_SPACE or key == Keyboard.KEY_RETURN then
        self:toggle()
        return true
    end
    return false
end

function ToggleSwitch:prerender()
    ISPanel.prerender(self)
    local dt = 0.016
    if UIManager and UIManager.getMillisSinceLastRender then
        dt = UIManager.getMillisSinceLastRender() / 1000.0
    end
    local progress = SpringDriver.update(self.spring, self.checked and 1.0 or 0.0, dt)
    if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

    local tw = math.min(self.trackWidth or 38, self.width)
    local th = math.min(self.trackHeight or 18, self.height)
    local ty = math.floor((self.height - th) / 2)
    local isHover = self.enable and self.isMouseOver and self:isMouseOver()
    local isFocused = self.enable and (self.joypadFocused or self.isFocused == true)

    local offBg = self.enable and (Theme.well or Theme.panel) or Theme.panel
    local onBg = self.enable and (Theme.primary or Theme.accent) or (Theme.selected or Theme.panel)
    lerpColor(TRACK_BUF, offBg, onBg, progress)
    if isHover then
        TRACK_BUF.r = math.min(1, TRACK_BUF.r + 0.04)
        TRACK_BUF.g = math.min(1, TRACK_BUF.g + 0.04)
        TRACK_BUF.b = math.min(1, TRACK_BUF.b + 0.04)
    end

    local offBc = self.enable and (isHover and (Theme.hoverBorder or Theme.borderFocus or Theme.accent) or Theme.border) or (Theme.borderSubtle or Theme.border)
    local onBc = self.enable and (isHover and (Theme.primaryHoverBorder or Theme.status.READY or Theme.accent) or (Theme.primaryBorder or Theme.accent)) or (Theme.borderSubtle or Theme.border)
    lerpColor(BORDER_BUF, offBc, onBc, progress)

    Chrome.pill(self, 0, ty, tw, th, BORDER_BUF)
    Chrome.pill(self, 1, ty + 1, math.max(1, tw - 2), math.max(1, th - 2), TRACK_BUF)
    if isFocused then
        Chrome.roundedBorder(self, -2, ty - 2, tw + 4, th + 4, Theme.borderFocus or Theme.accent)
    end

    local knobSize = math.max(8, th - 6)
    local travel = math.max(0, tw - knobSize - 6)
    local knobX = math.floor(3 + travel * progress + 0.5)
    local knobY = ty + math.floor((th - knobSize) / 2)
    local knobColor = (not self.enable) and KNOB_DISABLED or (self.checked and KNOB_ACTIVE or KNOB_IDLE)
    Chrome.pill(self, knobX, knobY, knobSize, knobSize, knobColor)

    if self.label and self.label ~= "" then
        local textY = math.floor((self.height - (self.fontHeight or 14)) / 2)
        local textCol = self.enable and Theme.textColor or Theme.muted
        Theme.text(self, self.label, tw + 8, textY, textCol, self.font)
    end
end

return ToggleSwitch
