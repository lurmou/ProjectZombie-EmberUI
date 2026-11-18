--[[
    Chrome.lua - EmberUI Core
    Zero-GC 9-slice rounded surfaces, crisp antialiased corner borders,
    title-bar horizontal gradient washes, and slot radial glows.
    Falls back to flat drawRect/drawRectBorder when textures are unavailable
    (e.g. headless Kahlua tests or tiny bounds < 12px).
]]

local Chrome = {}

local activeBackend = nil
local DEFAULT_CAPS = {
    name = "lua-ssaa-9p",
    roundedRect = true,
    pill = true,
    shadow = true,
    titleBar = true,
    vector = false,
    roundedClip = false,
}

---Optional RenderBackend SPI (e.g., future GLSL/ZombieBuddy vector acceleration).
---@param backend table? Pass nil to restore built-in Lua SSAA 9-slice backend.
function Chrome.registerBackend(backend)
    assert(backend == nil or type(backend) == "table", "CHROME_BACKEND_INVALID")
    activeBackend = backend
end

---@return table?
function Chrome.getBackend()
    return activeBackend
end

---@return table
function Chrome.getCaps()
    if activeBackend and type(activeBackend.caps) == "table" then
        return activeBackend.caps
    end
    return DEFAULT_CAPS
end

local CORNER_R = 6
local NP_MIN_SIZE = 14
local NP_MIN_SIZE_LG = 22
local CHROME_DIR = "media/ui/EmberUI/CHROME/"

local texCache = {}
local ninePatchCache = {}

local function getChromeTex(name)
    local cached = texCache[name]
    if cached ~= nil then return cached or nil end
    local tex = false
    if type(getTexture) == "function" then
        local res = getTexture(CHROME_DIR .. name .. ".png")
        if res then tex = res end
    end
    texCache[name] = tex
    return tex or nil
end

local function getNinePatch(name)
    local cached = ninePatchCache[name]
    if cached then return cached end
    if not NinePatchTexture or type(NinePatchTexture.getSharedTexture) ~= "function" then
        return nil
    end
    -- PZ NinePatchTexture.getSharedTexture returns nil on its first call while async loading; never cache nil/false.
    local np = NinePatchTexture.getSharedTexture(CHROME_DIR .. name .. ".png")
    if np then
        ninePatchCache[name] = np
        return np
    end
    return nil
end

local function drawNinePatch(owner, name, x, y, w, h, r, g, b, a, minSize)
    local minDim = minSize or NP_MIN_SIZE
    if w < minDim or h < minDim or owner.isCollapsed then return false end
    if type(owner.getAbsoluteX) ~= "function" or type(owner.getAbsoluteY) ~= "function" then
        return false
    end
    local np = getNinePatch(name)
    if not np then return false end
    np:render(owner:getAbsoluteX() + x, owner:getAbsoluteY() + y, w, h, r, g, b, a)
    return true
end

function Chrome.shadow(owner, x, y, w, h, alpha)
    if not owner or w <= 0 or h <= 0 then return false end
    if activeBackend and activeBackend.shadow then return activeBackend.shadow(owner, x, y, w, h, alpha) end
    return drawNinePatch(owner, "9p_shadow", x - 5, y - 3, w + 10, h + 10, 1, 1, 1, alpha or 0.45, NP_MIN_SIZE_LG)
end

function Chrome.pill(owner, x, y, w, h, color)
    if not owner or not color or w <= 0 or h <= 0 then return false end
    if activeBackend and activeBackend.pill then return activeBackend.pill(owner, x, y, w, h, color) end
    local a = color.a or 1
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    if w == h and w >= 8 and w <= 32 and owner.drawTextureScaled then
        local circleTex = getChromeTex("circle_solid")
        if circleTex then
            owner:drawTextureScaled(circleTex, x, y, w, h, a, r, g, b)
            return true
        end
    end
    if w >= 20 and h >= 18 and drawNinePatch(owner, "9p_pill_lg", x, y, w, h, r, g, b, a, 18) then
        return true
    end
    if w >= 5 and h >= 5 and drawNinePatch(owner, "9p_pill", x, y, w, h, r, g, b, a, 5) then
        return true
    end
    owner:drawRect(x, y, w, h, a, r, g, b)
    return false
end

function Chrome.patternOverlay(owner, x, y, w, h, patternName, alpha, color)
    if not owner or w <= 2 or h <= 2 or not owner.drawTextureTiled then return end
    local tex = getChromeTex(patternName or "pattern_hex")
    if not tex then return end
    local c = color
    owner:drawTextureTiled(tex, x, y, w, h, c and (c.r or 1) or 1, c and (c.g or 1) or 1, c and (c.b or 1) or 1, alpha or 0.045)
end

local function hasCornerSet(prefix)
    return getChromeTex(prefix .. "_tl") ~= nil
        and getChromeTex(prefix .. "_tr") ~= nil
        and getChromeTex(prefix .. "_bl") ~= nil
        and getChromeTex(prefix .. "_br") ~= nil
end

local GRADIENT_STEPS = 24
local CORNER_INSETS = {
    [6] = { 4, 2, 1, 1, 0, 0 },
    [9] = { 6, 4, 3, 2, 1, 1, 0, 0, 0 },
}

function Chrome.hGradient(owner, x, y, w, h, color, alphaScale, topRadius)
    if not owner or not color or w <= 0 or h <= 0 then return end
    local baseA = (color.a or 1) * (alphaScale or 1)
    if baseA <= 0.001 then return end
    local r, g, b = color.r or 1, color.g or 1, color.b or 1
    local steps = math.min(GRADIENT_STEPS, math.max(1, math.floor(w / 3)))
    local bandW = w / steps
    local cornerRows = topRadius and (CORNER_INSETS[topRadius] or (topRadius >= 8 and CORNER_INSETS[9] or CORNER_INSETS[6])) or nil
    local bodyStartRow = 0

    if cornerRows then
        local maxCorner = math.min(h, #cornerRows)
        for dy = 1, maxCorner do
            local inset = cornerRows[dy]
            if inset and inset > 0 then
                local startX = x + inset
                local rowY = y + dy - 1
                for i = 1, steps do
                    local bx = math.floor(x + (i - 1) * bandW)
                    local nx = math.floor(x + i * bandW)
                    if nx > startX then
                        local drawX = math.max(bx, startX)
                        local bw = nx - drawX
                        if bw > 0 then
                            local t = 1.0 - (i - 1) / steps
                            owner:drawRect(drawX, rowY, bw, 1, baseA * t * t, r, g, b)
                        end
                    end
                end
                bodyStartRow = dy
            else
                break
            end
        end
    end

    local bodyY = y + bodyStartRow
    local bodyH = h - bodyStartRow
    if bodyH <= 0 then return end
    for i = 1, steps do
        local bx = math.floor(x + (i - 1) * bandW)
        local nx = math.floor(x + i * bandW)
        local bw = nx - bx
        if bw > 0 then
            local t = 1.0 - (i - 1) / steps
            owner:drawRect(bx, bodyY, bw, bodyH, baseA * t * t, r, g, b)
        end
    end
end

function Chrome.vGradient(owner, x, y, w, h, color, alphaScale)
    if not owner or not color or w <= 0 or h <= 0 then return end
    local a = (color.a or 1) * (alphaScale or 1)
    if a <= 0.001 then return end
    local tex = owner.drawTextureScaled and getChromeTex("vgradient")
    if tex then
        owner:drawTextureScaled(tex, x, y, w, h, a, color.r or 1, color.g or 1, color.b or 1)
    else
        owner:drawRect(x, y, w, h, a * 0.25, color.r or 1, color.g or 1, color.b or 1)
    end
end

function Chrome.slotGlow(owner, x, y, w, h, color, alphaScale)
    if not owner or not color or w <= 0 or h <= 0 then return end
    local a = (color.a or 1) * (alphaScale or 1)
    if a <= 0.001 then return end
    local tex = owner.drawTextureScaled and getChromeTex("slot_glow")
    if tex then
        owner:drawTextureScaled(tex, x, y, w, h, a, color.r or 1, color.g or 1, color.b or 1)
    end
end

function Chrome.roundedFill(owner, x, y, w, h, color, topOnly, radius)
    if not owner or not color or w <= 0 or h <= 0 then return end
    local a = color.a or 1
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1

    local useLarge = radius and radius >= 8 and w >= NP_MIN_SIZE_LG and h >= NP_MIN_SIZE_LG
    local npName = useLarge
        and (topOnly and "9p_fill_top_lg" or "9p_fill_lg")
        or (topOnly and "9p_fill_top" or "9p_fill")
    if drawNinePatch(owner, npName, x, y, w, h, r, g, b, a, useLarge and NP_MIN_SIZE_LG or NP_MIN_SIZE) then
        return
    end

    local cornerR = CORNER_R
    if not owner.drawTextureScaled or w < cornerR * 2 or h < cornerR * 2 or not hasCornerSet("round_fill") then
        owner:drawRect(x, y, w, h, a, r, g, b)
        return
    end

    local tl = getChromeTex("round_fill_tl")
    local tr = getChromeTex("round_fill_tr")
    owner:drawTextureScaled(tl, x, y, cornerR, cornerR, a, r, g, b)
    owner:drawTextureScaled(tr, x + w - cornerR, y, cornerR, cornerR, a, r, g, b)
    if w > cornerR * 2 then
        owner:drawRect(x + cornerR, y, w - cornerR * 2, cornerR, a, r, g, b)
    end

    if topOnly then
        if h > cornerR then
            owner:drawRect(x, y + cornerR, w, h - cornerR, a, r, g, b)
        end
        return
    end

    if h > cornerR * 2 then
        owner:drawRect(x, y + cornerR, w, h - cornerR * 2, a, r, g, b)
    end

    local bl = getChromeTex("round_fill_bl")
    local br = getChromeTex("round_fill_br")
    owner:drawTextureScaled(bl, x, y + h - cornerR, cornerR, cornerR, a, r, g, b)
    owner:drawTextureScaled(br, x + w - cornerR, y + h - cornerR, cornerR, cornerR, a, r, g, b)
    if w > cornerR * 2 then
        owner:drawRect(x + cornerR, y + h - cornerR, w - cornerR * 2, cornerR, a, r, g, b)
    end
end

function Chrome.roundedBorder(owner, x, y, w, h, color, topOnly, radius)
    if not owner or not color or w <= 0 or h <= 0 then return end
    local a = color.a or 1
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1

    local useLarge = radius and radius >= 8 and w >= NP_MIN_SIZE_LG and h >= NP_MIN_SIZE_LG
    local npName = useLarge
        and (topOnly and "9p_border_top_lg" or "9p_border_lg")
        or (topOnly and "9p_border_top" or "9p_border")
    if drawNinePatch(owner, npName, x, y, w, h, r, g, b, a, useLarge and NP_MIN_SIZE_LG or NP_MIN_SIZE) then
        return
    end

    local cornerR = CORNER_R
    if not owner.drawTextureScaled or w < cornerR * 2 or h < cornerR * 2 or not hasCornerSet("round_border") then
        owner:drawRectBorder(x, y, w, h, a, r, g, b)
        return
    end

    local tl = getChromeTex("round_border_tl")
    local tr = getChromeTex("round_border_tr")
    owner:drawTextureScaled(tl, x, y, cornerR, cornerR, a, r, g, b)
    owner:drawTextureScaled(tr, x + w - cornerR, y, cornerR, cornerR, a, r, g, b)
    if w > cornerR * 2 then
        owner:drawRect(x + cornerR, y, w - cornerR * 2, 1, a, r, g, b)
    end

    if topOnly then
        if h > cornerR then
            owner:drawRect(x, y + cornerR, 1, h - cornerR, a, r, g, b)
            owner:drawRect(x + w - 1, y + cornerR, 1, h - cornerR, a, r, g, b)
        end
        owner:drawRect(x, y + h - 1, w, 1, a, r, g, b)
        return
    end

    if h > cornerR * 2 then
        owner:drawRect(x, y + cornerR, 1, h - cornerR * 2, a, r, g, b)
        owner:drawRect(x + w - 1, y + cornerR, 1, h - cornerR * 2, a, r, g, b)
    end

    local bl = getChromeTex("round_border_bl")
    local br = getChromeTex("round_border_br")
    owner:drawTextureScaled(bl, x, y + h - cornerR, cornerR, cornerR, a, r, g, b)
    owner:drawTextureScaled(br, x + w - cornerR, y + h - cornerR, cornerR, cornerR, a, r, g, b)
    if w > cornerR * 2 then
        owner:drawRect(x + cornerR, y + h - 1, w - cornerR * 2, 1, a, r, g, b)
    end
end

function Chrome.roundedRect(owner, x, y, w, h, bg, border, topOnly, radius)
    if activeBackend and activeBackend.roundedRect then
        return activeBackend.roundedRect(owner, x, y, w, h, bg, border, topOnly, radius)
    end
    if bg then Chrome.roundedFill(owner, x, y, w, h, bg, topOnly, radius) end
    if border then Chrome.roundedBorder(owner, x, y, w, h, border, topOnly, radius) end
end

function Chrome.titleBar(owner, x, y, w, h, fill, accent, divider, radius)
    if not owner or w <= 0 or h <= 0 then return end
    if activeBackend and activeBackend.titleBar then
        return activeBackend.titleBar(owner, x, y, w, h, fill, accent, divider, radius)
    end
    if fill then
        Chrome.roundedFill(owner, x, y, w, h, fill, true, radius)
    end
    local insetX = (radius and radius >= 8) and 6 or 4
    local insetTop = (radius and radius >= 8) and 4 or 3
    Chrome.patternOverlay(owner, x + insetX, y + insetTop, math.max(0, w - insetX * 2), math.max(0, h - insetTop - 1), "pattern_diag", 0.045, accent)
    if accent then
        local glowW = math.min(w, math.max(110, math.floor(w * 0.60)))
        Chrome.hGradient(owner, x, y, glowW, h, accent, 0.22, radius or 6)
        owner:drawRect(x, y + h - 1, w, 1, (accent.a or 1) * 0.72, accent.r or 1, accent.g or 1, accent.b or 1)
    elseif divider then
        owner:drawRect(x, y + h - 1, w, 1, divider.a or 0.85, divider.r or 1, divider.g or 1, divider.b or 1)
    end
end

function Chrome.clearCache()
    texCache = {}
    ninePatchCache = {}
end

return Chrome
