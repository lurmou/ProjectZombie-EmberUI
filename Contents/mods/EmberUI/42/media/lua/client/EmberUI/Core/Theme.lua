local Clock = require 'EmberUI/Core/Clock'
local Chrome = require 'EmberUI/Core/Chrome'
local FocusManager = require 'EmberUI/Core/FocusManager'

local Theme = {
    -- Avatar palette is registered once; moving it out of drawing preserves its appearance.
    avatarSurface = { r = .04, g = .06, b = .08, a = .95 },
    avatarHead = { r = .28, g = .35, b = .42, a = .85 },
    avatarBody = { r = .18, g = .25, b = .32, a = .85 },
    avatarEdge = { r = 1, g = 1, b = 1, a = .9 },
    avatarInk = { r = 1, g = 1, b = 1, a = 1 },
}

local function text(key, fallback)
    local value = type(getTextOrNull) == "function" and getTextOrNull("IGUI_EmberUI_" .. key) or nil
    return value or fallback or key
end

-- Exact case parity with Translate/CN/IG_UI.json & Translate/EN/IG_UI.json
local PRESET_LABEL_KEYS = {
    github = "Theme_Github",
    ae2 = "Theme_Ae2",
    classic = "Theme_Classic",
}

local PRESETS = {
    github = {
        id = "github",
        name = "Primer Dark",
        labelKey = PRESET_LABEL_KEYS.github,
        window = { r = 0.055, g = 0.072, b = 0.100, a = 0.98 },
        panel = { r = 0.098, g = 0.122, b = 0.162, a = 0.96 },
        card = { r = 0.128, g = 0.157, b = 0.204, a = 0.97 },
        well = { r = 0.032, g = 0.043, b = 0.064, a = 0.98 },
        titleBar = { r = 0.078, g = 0.100, b = 0.136, a = 1.0 },
        titleAccent = { r = 0.255, g = 0.765, b = 0.365, a = 1.0 },
        badgeBg = { r = 0.032, g = 0.043, b = 0.064, a = 0.88 },
        border = { r = 0.235, g = 0.278, b = 0.335, a = 0.92 },
        borderSubtle = { r = 0.165, g = 0.198, b = 0.242, a = 0.88 },
        borderFocus = { r = 0.380, g = 0.680, b = 1.000, a = 1.0 },
        control = { r = 0.148, g = 0.180, b = 0.228, a = 1.0 },
        primary = { r = 0.145, g = 0.545, b = 0.235, a = 1.0 },
        primaryBorder = { r = 0.28, g = 0.74, b = 0.38, a = 1.0 },
        primaryHover = { r = 0.195, g = 0.655, b = 0.295, a = 1.0 },
        primaryHoverBorder = { r = 0.36, g = 0.84, b = 0.46, a = 1.0 },
        accent = { r = 0.380, g = 0.680, b = 1.000, a = 1.0 },
        info = { r = 0.380, g = 0.680, b = 1.000, a = 1.0 },
        gold = { r = 0.855, g = 0.640, b = 0.180, a = 1.0 },
        selected = { r = 0.185, g = 0.235, b = 0.310, a = 1.0 },
        selectedBorder = { r = 0.450, g = 0.680, b = 0.980, a = 1.0 },
        hover = { r = 0.205, g = 0.250, b = 0.318, a = 1.0 },
        hoverBorder = { r = 0.480, g = 0.680, b = 0.960, a = 1.0 },
        textColor = { r = 0.918, g = 0.942, b = 0.968, a = 1.0 },
        muted = { r = 0.580, g = 0.630, b = 0.690, a = 1.0 },
        status = {
            READY = { r = 0.265, g = 0.775, b = 0.385, a = 1.0 },
            UPDATING = { r = 0.855, g = 0.640, b = 0.180, a = 1.0 },
            ERROR = { r = 0.973, g = 0.350, b = 0.320, a = 1.0 },
        },
    },
    ae2 = {
        id = "ae2",
        name = "AE2 Cyan",
        labelKey = PRESET_LABEL_KEYS.ae2,
        window = { r = 0.04, g = 0.06, b = 0.08, a = 0.96 },
        panel = { r = 0.06, g = 0.09, b = 0.13, a = 0.95 },
        card = { r = 0.08, g = 0.12, b = 0.17, a = 0.96 },
        well = { r = 0.028, g = 0.042, b = 0.062, a = 0.96 },
        titleBar = { r = 0.08, g = 0.12, b = 0.18, a = 1.0 },
        titleAccent = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        badgeBg = { r = 0.02, g = 0.03, b = 0.05, a = 0.84 },
        border = { r = 0.22, g = 0.38, b = 0.52, a = 0.90 },
        borderSubtle = { r = 0.14, g = 0.24, b = 0.34, a = 0.85 },
        borderFocus = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        control = { r = 0.09, g = 0.14, b = 0.20, a = 1.0 },
        primary = { r = 0.14, g = 0.36, b = 0.55, a = 1.0 },
        primaryBorder = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        primaryHover = { r = 0.20, g = 0.45, b = 0.68, a = 1.0 },
        accent = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        info = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        gold = { r = 1.0, g = 0.78, b = 0.25, a = 1.0 },
        selected = { r = 0.14, g = 0.32, b = 0.48, a = 0.95 },
        selectedBorder = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        hover = { r = 0.18, g = 0.30, b = 0.44, a = 1.0 },
        hoverBorder = { r = 0.25, g = 0.75, b = 1.0, a = 1.0 },
        textColor = { r = 0.94, g = 0.97, b = 1.0, a = 1.0 },
        muted = { r = 0.50, g = 0.64, b = 0.75, a = 1.0 },
        status = {
            READY = { r = 0.35, g = 0.88, b = 0.60, a = 1.0 },
            UPDATING = { r = 1.0, g = 0.78, b = 0.25, a = 1.0 },
            ERROR = { r = 1.0, g = 0.42, b = 0.38, a = 1.0 },
        },
    },
    classic = {
        id = "classic",
        name = "Classic Slate",
        labelKey = PRESET_LABEL_KEYS.classic,
        window = { r = 0.045, g = 0.055, b = 0.06, a = 0.97 },
        panel = { r = 0.065, g = 0.08, b = 0.085, a = 0.94 },
        card = { r = 0.085, g = 0.10, b = 0.11, a = 0.96 },
        well = { r = 0.032, g = 0.040, b = 0.045, a = 0.96 },
        titleBar = { r = 0.085, g = 0.10, b = 0.11, a = 1.0 },
        titleAccent = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        badgeBg = { r = 0.02, g = 0.025, b = 0.03, a = 0.82 },
        border = { r = 0.30, g = 0.34, b = 0.36, a = 0.85 },
        borderSubtle = { r = 0.20, g = 0.24, b = 0.26, a = 0.80 },
        borderFocus = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        control = { r = 0.11, g = 0.13, b = 0.14, a = 1.0 },
        primary = { r = 0.22, g = 0.22, b = 0.16, a = 1.0 },
        primaryBorder = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        primaryHover = { r = 0.28, g = 0.28, b = 0.20, a = 1.0 },
        accent = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        info = { r = 0.52, g = 0.74, b = 0.88, a = 1.0 },
        gold = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        selected = { r = 0.19, g = 0.29, b = 0.31, a = 0.95 },
        selectedBorder = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        hover = { r = 0.16, g = 0.22, b = 0.24, a = 1.0 },
        hoverBorder = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
        textColor = { r = 0.91, g = 0.93, b = 0.91, a = 1.0 },
        muted = { r = 0.59, g = 0.66, b = 0.68, a = 1.0 },
        status = {
            READY = { r = 0.65, g = 0.82, b = 0.65, a = 1.0 },
            UPDATING = { r = 0.81, g = 0.72, b = 0.46, a = 1.0 },
            ERROR = { r = 1.0, g = 0.50, b = 0.40, a = 1.0 },
        },
    },
}

local DOSSIER = {
    background = { r = .045, g = .055, b = .06, a = .97 },
    panel = { r = .065, g = .08, b = .085, a = .94 },
    control = { r = .11, g = .13, b = .14, a = 1 },
    separator = { r = .30, g = .34, b = .36, a = .35 },
    gold = { r = .81, g = .72, b = .46, a = 1 },
    alert = { r = 1, g = .50, b = .40, a = 1 },
    text = { r = .91, g = .93, b = .91, a = 1 },
    muted = { r = .59, g = .66, b = .68, a = 1 },
    active = { r = .46, g = .60, b = .49, a = 1 },
}

local presetOrder = { "github", "ae2", "classic" }
local currentPreset = "github"
local listeners = {}

local function copyColor(c)
    if not c then return nil end
    return { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
end

---Mutates `dstTbl[key]` in-place if already a table so widgets holding direct color
---references update live on Theme switches with zero table allocations.
local function assignColor(dstTbl, key, src, overrideAlpha)
    if not src then return nil end
    local existing = dstTbl[key]
    local a = overrideAlpha ~= nil and overrideAlpha or (src.a or 1)
    if type(existing) == "table" then
        existing.r = src.r
        existing.g = src.g
        existing.b = src.b
        existing.a = a
        return existing
    end
    local created = { r = src.r, g = src.g, b = src.b, a = a }
    dstTbl[key] = created
    return created
end

local function notifyThemeListeners(preset)
    for _, callback in ipairs(listeners) do
        pcall(callback, preset)
    end
end

function Theme.applyPreset(id)
    local preset = PRESETS[id] or PRESETS.github
    local fallback = PRESETS.github
    currentPreset = preset.id
    Theme.presetName = preset.name
    Theme.presetLabel = preset.label or (preset.labelKey and text(preset.labelKey, preset.name)) or preset.name
    for k, v in pairs(fallback) do
        if type(v) == "table" then
            local src = preset[k] or v
            if k == "status" then
                Theme.status = Theme.status or {}
                for sk, sv in pairs(v) do
                    assignColor(Theme.status, sk, (type(src) == "table" and src[sk]) or sv)
                end
            else
                assignColor(Theme, k, src)
            end
        end
    end
    for k, v in pairs(preset) do
        if type(v) == "table" and k ~= "status" and fallback[k] == nil then
            assignColor(Theme, k, v)
        end
    end
    Theme.dossier = Theme.dossier or {}
    for role, color in pairs(DOSSIER) do
        assignColor(Theme.dossier, role, color)
    end
    assignColor(Theme, "danger", (Theme.status and Theme.status.ERROR) or { r = 0.973, g = 0.318, b = 0.286, a = 1.0 })
    Theme.revision = (Theme.revision or 0) + 1
    notifyThemeListeners(preset)
end

---Registers or updates a theme preset; missing tokens inherit from the base dark preset.
---@param id string
---@param def table
function Theme.registerPreset(id, def)
    assert(type(id) == "string" and id ~= "", "INVALID_THEME_PRESET_ID")
    assert(type(def) == "table", "INVALID_THEME_PRESET_DEF")
    local base = PRESETS.github
    local entry = {
        id = id,
        name = def.name or id,
        label = def.label or def.name or id,
        labelKey = def.labelKey,
    }
    for k, v in pairs(base) do
        if type(v) == "table" then
            if k == "status" then
                entry.status = {}
                local srcStatus = type(def.status) == "table" and def.status or nil
                for sk, sv in pairs(v) do
                    entry.status[sk] = copyColor((srcStatus and srcStatus[sk]) or sv)
                end
            else
                entry[k] = copyColor(def[k] or v)
            end
        end
    end
    for k, v in pairs(def) do
        if type(v) == "table" and k ~= "status" and entry[k] == nil then
            entry[k] = copyColor(v)
        end
    end
    local existed = PRESETS[id] ~= nil
    PRESETS[id] = entry
    if not existed then
        presetOrder[#presetOrder + 1] = id
    end
    if currentPreset == id then
        Theme.applyPreset(id)
    end
    return entry
end

---Applies partial color/token overrides onto the currently active Theme palette (Zero-GC in-place).
---@param patch table
function Theme.customize(patch)
    if type(patch) ~= "table" then return end
    for k, v in pairs(patch) do
        if type(v) == "table" then
            if k == "status" then
                Theme.status = Theme.status or {}
                for sk, sv in pairs(v) do
                    if type(sv) == "table" then
                        assignColor(Theme.status, sk, sv)
                    end
                end
            else
                assignColor(Theme, k, v)
            end
        elseif k == "presetName" or k == "presetLabel" then
            Theme[k] = v
        end
    end
    if Theme.status and Theme.status.ERROR then
        assignColor(Theme, "danger", Theme.status.ERROR)
    end
    Theme.revision = (Theme.revision or 0) + 1
    notifyThemeListeners(PRESETS[currentPreset] or PRESETS.github)
end

---@return string
function Theme.getPreset()
    return currentPreset
end

---@return table[]
function Theme.presets()
    local out = {}
    for _, id in ipairs(presetOrder) do
        local p = PRESETS[id]
        if p then
            out[#out + 1] = {
                id = p.id,
                name = p.name,
                label = p.label or (p.labelKey and text(p.labelKey, p.name)) or p.name,
            }
        end
    end
    return out
end

-- Initialize default to GitHub Primer Dark
Theme.applyPreset("github")

function Theme.watch(callback)
    listeners[#listeners + 1] = callback
    local live = true
    return function()
        if not live then return end
        live = false
        for i = #listeners, 1, -1 do
            if listeners[i] == callback then
                table.remove(listeners, i)
                break
            end
        end
    end
end

function Theme.dossierList(list)
    assignColor(list, "backgroundColor", Theme.dossier.background)
    assignColor(list, "borderColor", Theme.dossier.separator)
    list.drawBorder = false
end

function Theme.dossierButton(button, primary)
    assignColor(button, "backgroundColor", Theme.dossier.control)
    assignColor(button, "backgroundColorMouseOver", Theme.dossier.panel)
    assignColor(button, "borderColor", Theme.dossier.separator)
    assignColor(button, "textColor", primary and Theme.dossier.text or Theme.dossier.muted)
    button.displayBackground = primary == true
    button.isBorderVisible = false
end

function Theme.getLabel()
    local preset = PRESETS[currentPreset]
    if preset and preset.labelKey then
        return text(preset.labelKey, preset.name)
    end
    return Theme.presetLabel or text("Theme_Github", "Primer Dark")
end

function Theme.toggle()
    local nextId = "github"
    if currentPreset == "github" then nextId = "ae2"
    elseif currentPreset == "ae2" then nextId = "classic"
    else nextId = "github" end
    Theme.applyPreset(nextId)
    return nextId
end

function Theme.rect(owner, x, y, width, height, color, border)
    if not owner or not color then return end
    local a = color.a or 1
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    if border then
        owner:drawRectBorder(x, y, width, height, a, r, g, b)
    else
        owner:drawRect(x, y, width, height, a, r, g, b)
    end
end

local TRANSPARENT_COLOR = { r = 0, g = 0, b = 0, a = 0 }
local WHITE_TEXT = { r = 1, g = 1, b = 1, a = 1 }
local LOADING_BG = { r = 0.08, g = 0.10, b = 0.14, a = 0.90 }
local SCROLL_TRACK_COLOR = { r = 0, g = 0, b = 0, a = 0.28 }
local SCROLL_THUMB_COLOR = { r = 0.5, g = 0.55, b = 0.62, a = 0.42 }
local TICK_CHECK_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local TICK_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local tickCheckTex
local function getTickCheckTex()
    if tickCheckTex ~= nil then return tickCheckTex or nil end
    if type(getTexture) == "function" then
        local tex = getTexture("media/ui/EmberUI/ICON/check.png")
        tickCheckTex = tex or false
        return tex
    end
    return nil
end

local btnFontHeightCache = {}
local function getBtnFontH(font)
    local key = font or UIFont.Small
    local h = btnFontHeightCache[key]
    if h == nil then
        local tm = type(getTextManager) == "function" and getTextManager() or nil
        h = (tm and tm.getFontHeight and tm:getFontHeight(key)) or 14
        btnFontHeightCache[key] = h
    end
    return h
end

local function hookTactileButton(button)
    if button._emberSkinned then return end
    button._emberSkinned = true
    button.yoffset = 0
    local origPrerender = button.prerender
    button.prerender = function(self)
        if self.getIsVisible and not self:getIsVisible() then
            if origPrerender then origPrerender(self) end
            return
        end
        local isDown = self.pressed and self.enable
        local isHover = ((self.mouseOver and self.isMouseOver and self:isMouseOver()) or self.joypadFocused) and self.enable and not isDown
        self.yoffset = isDown and 1 or 0

        if not self.enable then
            if self.emberNormalBorder then self.borderColor = Theme.borderSubtle or Theme.border end
            if self.emberNormalText then self.textColor = Theme.muted or self.emberNormalText end
        elseif self.isBorderVisible and self.enable then
            if isHover then
                if self.emberHoverBorder then self.borderColor = self.emberHoverBorder end
                if self.emberHoverText then self.textColor = self.emberHoverText end
            else
                if self.emberNormalBorder then self.borderColor = self.emberNormalBorder end
                if self.emberNormalText then self.textColor = self.emberNormalText end
            end
        end

        local drawRounded = self.displayBackground and not self.isJoypad
        if drawRounded then
            local bg = (not self.enable) and (Theme.panel or self.backgroundColor)
                or (isDown and (Theme.well or Theme.panel)
                or (isHover and (self.backgroundColorMouseOver or Theme.hover)
                or (self.backgroundColor or Theme.control)))
            local bc = self.isBorderVisible and ((not self.enable) and (Theme.borderSubtle or Theme.border) or (self.borderColor or Theme.border)) or nil
            Chrome.roundedRect(self, 0, 0, self.width, self.height, bg, bc)
            if self.enable and (isHover or self.emberActive or self.emberPrimary) then
                local washCol = self.emberPrimary and (Theme.primaryBorder or Theme.accent) or (bc or Theme.borderFocus or Theme.accent)
                Chrome.hGradient(self, 1, 1, math.max(0, self.width - 2), math.max(1, self.height - 2), washCol, isHover and 0.16 or 0.08)
            end
            if isDown and self.width > 6 then
                self:drawRect(3, 1, self.width - 6, 1, 0.50, 0, 0, 0)
            end
            self.displayBackground = false
            if origPrerender then origPrerender(self) end
            self.displayBackground = true
        else
            if origPrerender then origPrerender(self) end
        end

        local isFocused = (self.joypadFocused or self.isFocused == true) and self.enable
        if isFocused and self.isBorderVisible then
            Chrome.roundedBorder(self, -1, -1, self.width + 2, self.height + 2, Theme.borderFocus or Theme.accent)
        end

        if self.loading then
            local t = Clock.nowMs()
            local dotCount = (math.floor(t / 350) % 3) + 1
            local dots = (dotCount == 1 and '.') or (dotCount == 2 and '..') or '...'
            local lText = (self.loadingText or (self.origTitle or self.title or '')) .. dots
            local font = self.font or UIFont.Small
            local tm = type(getTextManager) == "function" and getTextManager() or nil
            local tw = tm and tm.MeasureStringX and tm:MeasureStringX(font, lText) or (#lText * 8)
            local th = getBtnFontH(font)
            local tx = math.floor((self.width - tw) / 2)
            local ty = math.floor((self.height - th) / 2) + self.yoffset
            Chrome.roundedRect(self, 0, 0, self.width, self.height, LOADING_BG, Theme.accent)
            Theme.text(self, lText, tx, ty, Theme.accent, font)
        end
    end

    function button:setLoading(isLoading, loadingText)
        if isLoading then
            if not self.origTitle then self.origTitle = self.title end
            self.loading = true
            self.loadingText = loadingText
            self.enable = false
        else
            self.loading = false
            self.enable = true
            if self.origTitle then
                self:setTitle(self.origTitle)
                self.origTitle = nil
            end
        end
    end
end

function Theme.focusRing(owner, x, y, width, height, color)
    local c = color or Theme.accent
    owner:drawRectBorder(x - 2, y - 2, width + 4, height + 4, 0.85, c.r, c.g, c.b)
end

function Theme.formHelper(owner, x, y, width, helperText, isError)
    if not owner or not helperText or helperText == '' then return end
    local c = isError and (Theme.status and Theme.status.ERROR or Theme.accent) or Theme.muted
    Theme.text(owner, helperText, x, y, c, UIFont.Small)
end

function Theme.styleButton(button, primary, active)
    if not button then return end
    local isPrimary = primary == true
    local isActive = active == true
    hookTactileButton(button)
    button.emberPrimary = isPrimary
    button.emberActive = isActive
    button.displayBackground = true
    button.isBorderVisible = true

    local bg = isActive and Theme.selected or (isPrimary and Theme.primary or Theme.control)
    local bc = isActive and (Theme.selectedBorder or Theme.muted) or (isPrimary and (Theme.primaryBorder or Theme.accent) or Theme.border)
    local hover = isActive and Theme.selected or (isPrimary and (Theme.primaryHover or Theme.hover) or Theme.hover)
    local hoverBc = isActive and (Theme.selectedBorder or Theme.muted) or (isPrimary and (Theme.primaryHoverBorder or Theme.status.READY) or (Theme.hoverBorder or Theme.selectedBorder))
    local textC = (isActive or isPrimary) and WHITE_TEXT or Theme.textColor

    local normBc = assignColor(button, "emberNormalBorder", bc)
    assignColor(button, "emberHoverBorder", hoverBc)
    local normTc = assignColor(button, "emberNormalText", textC)
    assignColor(button, "emberHoverText", WHITE_TEXT)

    local bgCol = assignColor(button, "backgroundColor", bg)
    assignColor(button, "borderColor", normBc)
    assignColor(button, "backgroundColorMouseOver", hover)
    assignColor(button, "borderColorEnabled", normBc)
    assignColor(button, "backgroundColorEnabled", bgCol)
    assignColor(button, "textColor", normTc)
    assignColor(button, "textureColor", normTc)
    if button.setBackgroundRGBA then button:setBackgroundRGBA(bgCol.r, bgCol.g, bgCol.b, bgCol.a or 1) end
    if button.setBorderRGBA then button:setBorderRGBA(normBc.r, normBc.g, normBc.b, normBc.a or 1) end
end

function Theme.button(button, primary, active)
    Theme.styleButton(button, primary == true, active == true)
end

function Theme.drawCard(panel, bounds, opts)
    if not panel or not bounds or bounds.visible == false then return end
    local x = bounds.x or 0
    local y = bounds.y or 0
    local w = bounds.width or 0
    local h = bounds.height or 0
    if w <= 0 or h <= 0 then return end

    local p = (opts and opts.surface) or Theme.card or Theme.panel
    local b = (opts and opts.border) or Theme.border
    Chrome.roundedRect(panel, x, y, w, h, p, b, false, 9)

    if opts and opts.headerHeight and opts.headerHeight > 0 then
        local hh = math.min(h, opts.headerHeight)
        Chrome.titleBar(panel, x + 1, y + 1, math.max(0, w - 2), hh, Theme.titleBar or Theme.panel, opts.accent or Theme.titleAccent, Theme.borderSubtle or b, 9)
    end
end

function Theme.drawTitleBar(panel, x, y, w, h, title, font, accent)
    if not panel or w <= 0 or h <= 0 then return end
    Chrome.titleBar(panel, x, y, w, h, Theme.titleBar or Theme.panel, accent or Theme.titleAccent, Theme.borderSubtle or Theme.border, 9)
    if title and title ~= '' then
        local f = font or UIFont.Small
        local fh = type(getTextManager) == "function" and getTextManager():getFontHeight(f) or 14
        Theme.text(panel, title, x + 8, y + math.floor((h - fh) / 2), Theme.textColor, f)
    end
end

function Theme.list(list)
    if not list then return end
    assignColor(list, "backgroundColor", Theme.panel)
    assignColor(list, "borderColor", Theme.border)
    if list.drawBorder ~= false and not list._emberWellStyled then
        list.drawBorder = true
    end
    if list.vscroll then Theme.scrollbar(list.vscroll) end
    if list.hscroll then Theme.scrollbar(list.hscroll) end
end

function Theme.scrollbar(bar)
    if not bar then return bar end
    if bar._emberScrollSkinned then return bar end
    bar._emberScrollSkinned = true
    bar.background = false
    bar.doSetStencil = false
    bar.render = function(self)
        local parent = self.parent
        if not parent then return end
        local mx = self.getMouseX and self:getMouseX() or -1
        local my = self.getMouseY and self:getMouseY() or -1
        if self.vertical ~= false then
            local sh = parent.getScrollHeight and parent:getScrollHeight() or 0
            local h = self:getHeight()
            if sh and sh > h and h > 0 then
                local del = h / sh
                local boxheight = math.min(h, math.max(18, math.ceil(del * h)))
                local dif = (h - boxheight) * (self.pos or 0)
                local thumbY = math.ceil(dif)
                local w = self.width or 6
                local thumbW = math.min(5, math.max(4, w - 1))
                local thumbX = w - thumbW - 1
                self.barx = thumbX
                self.bary = thumbY
                self.barwidth = thumbW
                self.barheight = boxheight
                local overSelf = self.isMouseOver and self:isMouseOver()
                local isHover = self.scrolling or (overSelf and self.isPointOverThumb and self:isPointOverThumb(mx, my))
                if overSelf or self.scrolling then
                    Chrome.pill(self, thumbX, 1, thumbW, math.max(1, h - 2), SCROLL_TRACK_COLOR)
                end
                local tc = self.scrolling and (Theme.borderFocus or Theme.accent)
                    or (isHover and (Theme.textColor or Theme.muted)
                    or (Theme.muted or Theme.textColor))
                SCROLL_THUMB_COLOR.r = tc.r or 0.6
                SCROLL_THUMB_COLOR.g = tc.g or 0.65
                SCROLL_THUMB_COLOR.b = tc.b or 0.7
                SCROLL_THUMB_COLOR.a = self.scrolling and 0.90 or (isHover and 0.72 or 0.36)
                Chrome.pill(self, thumbX, thumbY, thumbW, boxheight, SCROLL_THUMB_COLOR)
            else
                self.barx, self.bary, self.barwidth, self.barheight = 0, 0, 0, 0
            end
        else
            local sw = parent.getScrollWidth and parent:getScrollWidth() or 0
            local w = self:getWidth()
            if sw and sw > w and w > 0 then
                local del = w / sw
                local boxwidth = math.min(w, math.max(18, math.ceil(del * w)))
                local dif = (w - boxwidth) * (self.pos or 0)
                local thumbX = math.ceil(dif)
                local h = self.height or 6
                local thumbH = math.min(5, math.max(4, h - 1))
                local thumbY = h - thumbH - 1
                self.barx = thumbX
                self.bary = thumbY
                self.barwidth = boxwidth
                self.barheight = thumbH
                local overSelf = self.isMouseOver and self:isMouseOver()
                local isHover = self.scrolling or (overSelf and self.isPointOverThumb and self:isPointOverThumb(mx, my))
                if overSelf or self.scrolling then
                    Chrome.pill(self, 1, thumbY, math.max(1, w - 2), thumbH, SCROLL_TRACK_COLOR)
                end
                local tc = self.scrolling and (Theme.borderFocus or Theme.accent)
                    or (isHover and (Theme.textColor or Theme.muted)
                    or (Theme.muted or Theme.textColor))
                SCROLL_THUMB_COLOR.r = tc.r or 0.6
                SCROLL_THUMB_COLOR.g = tc.g or 0.65
                SCROLL_THUMB_COLOR.b = tc.b or 0.7
                SCROLL_THUMB_COLOR.a = self.scrolling and 0.90 or (isHover and 0.72 or 0.36)
                Chrome.pill(self, thumbX, thumbY, boxwidth, thumbH, SCROLL_THUMB_COLOR)
            else
                self.barx, self.bary, self.barwidth, self.barheight = 0, 0, 0, 0
            end
        end
    end
    return bar
end

function Theme.tickBox(tickBox)
    if not tickBox then return tickBox end
    assignColor(tickBox, "backgroundColor", Theme.well or Theme.panel)
    assignColor(tickBox, "borderColor", Theme.border)
    assignColor(tickBox, "choicesColor", Theme.textColor)
    if tickBox._emberTickSkinned then return tickBox end
    tickBox._emberTickSkinned = true
    tickBox.render = function(self)
        local options = self.options
        if not options then return end
        local spacing = UI_BORDER_SPACING or 4
        local itemHgt = self.itemHgt or math.max(self.boxSize or 16, self.fontHgt or 14)
        local boxSz = math.max(14, math.min(self.boxSize or 16, 18))
        local totalHgt = #options * (itemHgt + spacing) - spacing
        local y = (self.height - totalHgt) / 2
        local fontHgt = self.fontHgt or 14
        local textDY = math.floor((itemHgt - fontHgt) / 2)
        local boxDY = math.floor((itemHgt - boxSz) / 2)
        local leftMargin = self.leftMargin or 0
        local textGap = math.max(6, self.textGap or spacing)
        local disabledMap = self.disabledOptions
        local mouseOver = self.isMouseOver and self:isMouseOver()
        local overOpt = self.mouseOverOption
        local checkTex = getTickCheckTex()

        for i = 1, #options do
            local label = options[i]
            local optKey = (self.optionsIndex and self.optionsIndex[i]) or label
            local disabled = not self.enable or (disabledMap and (disabledMap[label] or disabledMap[optKey])) == true
            local checked = (self.selected and self.selected[i] == true)
            local isHover = mouseOver and (overOpt == i) and not disabled
            local isFocused = self.joypadFocused and self.joypadIndex == i
            local boxY = y + boxDY

            local bg = checked and (disabled and (Theme.selected or Theme.panel) or (isHover and (Theme.primaryHover or Theme.accent) or (Theme.primary or Theme.accent)))
                or (disabled and (Theme.well or Theme.panel) or (isHover and (Theme.hover or Theme.control) or (self.backgroundColor or Theme.well or Theme.panel)))
            local bc = checked and (disabled and (Theme.borderSubtle or Theme.border) or (isHover and (Theme.primaryHoverBorder or Theme.status.READY or Theme.accent) or (Theme.primaryBorder or Theme.accent)))
                or (disabled and (Theme.borderSubtle or Theme.border) or (isHover and (Theme.hoverBorder or Theme.borderFocus or Theme.accent) or (self.borderColor or Theme.border)))

            Chrome.roundedRect(self, leftMargin, boxY, boxSz, boxSz, bg, bc, false, 6)
            if isFocused then
                Chrome.roundedBorder(self, leftMargin - 2, boxY - 2, boxSz + 4, boxSz + 4, Theme.borderFocus or Theme.accent, false, 6)
            end

            if checked then
                local icCol = disabled and (Theme.muted or TICK_CHECK_WHITE) or TICK_CHECK_WHITE
                if checkTex and self.drawTextureScaled then
                    local pad = 3
                    self:drawTextureScaled(checkTex, leftMargin + pad, boxY + pad, math.max(8, boxSz - pad * 2), math.max(8, boxSz - pad * 2), icCol.a or 1, icCol.r or 1, icCol.g or 1, icCol.b or 1)
                elseif self.tickTexture and self.drawTextureScaled then
                    self:drawTextureScaled(self.tickTexture, leftMargin + 2, boxY + 2, math.max(8, boxSz - 4), math.max(8, boxSz - 4), icCol.a or 1, icCol.r or 1, icCol.g or 1, icCol.b or 1)
                else
                    Theme.rect(self, leftMargin + 4, boxY + math.floor(boxSz * 0.55), 3, 2, icCol)
                    Theme.rect(self, leftMargin + 6, boxY + math.floor(boxSz * 0.35), 4, 4, icCol)
                end
            end

            local tc = TICK_TEXT_COLOR
            if self.getTextColor then
                self:getTextColor(i, tc)
                if disabled then
                    local m = Theme.muted or tc
                    tc.r, tc.g, tc.b, tc.a = m.r, m.g, m.b, m.a or 1
                end
            else
                local src = disabled and (Theme.muted or Theme.textColor) or Theme.textColor
                tc.r, tc.g, tc.b, tc.a = src.r, src.g, src.b, src.a or 1
            end

            local tex = self.textures and self.textures[i]
            local labelX = leftMargin + boxSz + textGap
            if tex and self.drawTextureScaled then
                self:drawTextureScaled(tex, labelX, boxY, math.max(8, boxSz - 2), math.max(8, boxSz - 2), 1, 1, 1, 1)
                labelX = labelX + boxSz + 4
            end
            self:drawText(label, labelX, y + textDY, tc.r, tc.g, tc.b, tc.a or 1, self.font or UIFont.Small)

            y = y + itemHgt + spacing
        end

        if mouseOver and overOpt and overOpt ~= 0 and self.tooltip and ISToolTip then
            if not self.tooltipUI then
                self.tooltipUI = ISToolTip:new()
                self.tooltipUI:setOwner(self)
                self.tooltipUI:setVisible(false)
                self.tooltipUI:setAlwaysOnTop(true)
            end
            if not self.tooltipUI:getIsVisible() then
                self.tooltipUI.maxLineWidth = string.find(self.tooltip, "\n", 1, true) and 1000 or 300
                self.tooltipUI:addToUIManager()
                self.tooltipUI:setVisible(true)
            end
            self.tooltipUI.description = self.tooltip
            self.tooltipUI:setX(self:getMouseX() + 23)
            self.tooltipUI:setY(self:getMouseY() + 23)
        elseif self.tooltipUI and self.tooltipUI:getIsVisible() then
            self.tooltipUI:setVisible(false)
            self.tooltipUI:removeFromUIManager()
        end
    end
    return tickBox
end

function Theme.enable(button, enabled, primary)
    if not button then return end
    button:setEnable(enabled)
    Theme.button(button, primary == true and enabled == true)
    if not enabled then
        local bc = assignColor(button, "borderColor", Theme.border, 0.45)
        local bg = assignColor(button, "backgroundColor", Theme.panel, 0.70)
        assignColor(button, "textColor", Theme.muted)
        assignColor(button, "emberNormalBorder", bc)
        assignColor(button, "emberHoverBorder", bc)
        assignColor(button, "emberNormalText", Theme.muted)
        assignColor(button, "emberHoverText", Theme.muted)
        if button.setBorderRGBA then button:setBorderRGBA(bc.r, bc.g, bc.b, bc.a) end
        if button.setBackgroundRGBA then button:setBackgroundRGBA(bg.r, bg.g, bg.b, bg.a) end
    end
end

function Theme.combo(comboBox)
    if not comboBox then return end
    assignColor(comboBox, "backgroundColor", Theme.control)
    assignColor(comboBox, "borderColor", Theme.border)
    assignColor(comboBox, "backgroundColorMouseOver", Theme.hover or Theme.control)
    assignColor(comboBox, "textColor", Theme.textColor)
    if comboBox.popup then
        assignColor(comboBox.popup, "backgroundColor", Theme.panel)
        assignColor(comboBox.popup, "borderColor", Theme.border)
        comboBox.popup.drawBorder = true
    end
end

local function syncTextBoxColors(entry)
    local tc = Theme.textColor
    local mc = Theme.muted or tc
    if entry.setTextRGBA and entry.javaObject then
        entry:setTextRGBA(tc.r, tc.g, tc.b, tc.a or 1)
    end
    if entry.setPlaceholderTextRGBA and entry.javaObject then
        entry:setPlaceholderTextRGBA(mc.r, mc.g, mc.b, 0.78)
    end
    entry._emberThemeRev = Theme.revision
end

function Theme.input(entry, focusGroup)
    if not entry then return end
    assignColor(entry, "backgroundColor", Theme.well or Theme.panel)
    assignColor(entry, "borderColor", Theme.border)
    assignColor(entry, "textColor", Theme.textColor)
    syncTextBoxColors(entry)
    FocusManager.bindTextEntry(entry, focusGroup)

    if not entry._emberInputSkinned and type(entry.prerender) == 'function' then
        entry._emberInputSkinned = true
        local origPrerender = entry.prerender
        entry.prerender = function(self)
            if self._emberThemeRev ~= Theme.revision then
                syncTextBoxColors(self)
            end
            local bg = self.backgroundColor or Theme.well or Theme.panel
            local focused = (self.javaObject and self.javaObject.isFocused and self.javaObject:isFocused()) or self.focused or self.isFocused == true
            local bc = focused and (Theme.borderFocus or Theme.accent) or (self.borderColor or Theme.border)
            Chrome.roundedRect(self, 0, 0, self.width, self.height, bg, bc)
            if self.width > 8 then
                self:drawRect(3, 1, self.width - 6, 1, 0.35, 0, 0, 0)
            end
            local prevBg, prevBc = self.backgroundColor, self.borderColor
            self.backgroundColor = TRANSPARENT_COLOR
            self.borderColor = TRANSPARENT_COLOR
            origPrerender(self)
            self.backgroundColor = prevBg
            self.borderColor = prevBc
        end
    end
end

function Theme.text(owner, label, x, y, color, font)
    if not owner or not label then return end
    local c = color or Theme.textColor
    owner:drawText(label, x, y, c.r, c.g, c.b, c.a or 1, font or UIFont.Small)
end

return Theme
