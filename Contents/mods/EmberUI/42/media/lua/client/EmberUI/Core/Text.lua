-- PZ Kahlua strings are UTF-16 Java strings; desktop Lua uses UTF-8 bytes.
-- Do not use UTF-8 byte patterns against translated Kahlua strings.
local UICache = require "EmberUI/Core/UICache"

local Text = {}
local unicodeStrings = #"\228\187\147" == 1
local truncateCache = {}

local function nextCharacter(value, index)
    local code = value:byte(index)
    local length = 1
    if unicodeStrings then
        if code >= 55296 and code <= 56319 then length = 2 end
    elseif code >= 240 then length = 4
    elseif code >= 224 then length = 3
    elseif code >= 192 then length = 2 end
    return value:sub(index, index + length - 1), index + length
end

---Single-line UTF-16/UTF-8 safe ellipsis truncation with Zero-GC memoization.
---@param value string?
---@param width number
---@param font any?
---@return string
function Text.truncate(value, width, font)
    if value == nil or value == "" then return "" end
    local s = tostring(value)
    local f = font or (UIFont and UIFont.Small) or "Small"
    local limit = math.max(1, math.floor(width or 0))
    if UICache.measure(f, s) <= limit then
        return s
    end

    local byFont = truncateCache[f]
    if not byFont then
        byFont = {}
        truncateCache[f] = byFont
    end
    local byWidth = byFont[limit]
    if not byWidth then
        byWidth = {}
        byFont[limit] = byWidth
    end
    local cached = byWidth[s]
    if cached ~= nil then
        return cached
    end

    local suffix = "..."
    while #suffix > 0 and UICache.measure(f, suffix) > limit do
        suffix = suffix:sub(1, -2)
    end
    local suffixW = UICache.measure(f, suffix)
    local budget = math.max(0, limit - suffixW)

    local clipped, index = "", 1
    while index <= #s do
        local char
        char, index = nextCharacter(s, index)
        if char == "\n" or char == "\r" then break end
        local nextStr = clipped .. char
        if UICache.measure(f, nextStr) > budget then
            break
        end
        clipped = nextStr
    end

    local result = clipped .. suffix
    byWidth[s] = result
    return result
end

function Text.clearCache()
    truncateCache = {}
end

function Text.wrap(value, width, font)
    local lines, line = {}, ""
    local manager = getTextManager()
    local limit = math.max(1, width)
    local index = 1
    while index <= #value do
        local char
        char, index = nextCharacter(value, index)
        if char == "\n" then
            lines[#lines + 1] = line
            line = ""
        elseif char ~= "\r" then
            local candidate = line .. char
            if line ~= "" and manager:MeasureStringX(font, candidate) > limit then
                lines[#lines + 1] = line
                line = char
            else
                line = candidate
            end
        end
    end
    if line ~= "" or #lines == 0 then lines[#lines + 1] = line end
    return lines
end

function Text.wrapLimited(value, width, font, maxLines)
    local lines = Text.wrap(value, width, font)
    if #lines <= maxLines then return lines end
    while #lines > maxLines do table.remove(lines) end
    local manager = getTextManager()
    local suffix = "..."
    while #suffix > 0 and manager:MeasureStringX(font, suffix) > width do suffix = suffix:sub(1, -2) end
    local clipped, index = "", 1
    local last = lines[maxLines]
    while index <= #last do
        local char
        char, index = nextCharacter(last, index)
        if manager:MeasureStringX(font, clipped .. char .. suffix) > width then break end
        clipped = clipped .. char
    end
    lines[maxLines] = clipped .. suffix
    return lines
end

local WORD = {}
for i = 33, 126 do WORD[string.char(i)] = true end

-- Word-aware wrapping for dialogue and chat text: keeps ASCII words whole and
-- lets every other character (CJK, fullwidth punctuation, spaces) break on its
-- own, so wrapped lines neither split words nor start with a wrapped gap.
function Text.wrapWords(value, width, font)
    local lines, line = {}, ""
    local manager = getTextManager()
    local limit = math.max(1, width)
    local index = 1
    while index <= #value do
        local char
        char, index = nextCharacter(value, index)
        if char == "\n" then
            lines[#lines + 1] = line
            line = ""
        elseif char ~= "\r" then
            local unit = char
            if WORD[char] then
                while index <= #value do
                    local ch, nextIndex = nextCharacter(value, index)
                    if not WORD[ch] then break end
                    unit = unit .. ch
                    index = nextIndex
                end
            end
            if manager:MeasureStringX(font, line .. unit) <= limit then
                line = line .. unit
            else
                if line ~= "" then
                    if line:sub(-1) == " " then line = line:sub(1, -2) end
                    lines[#lines + 1] = line
                    line = ""
                end
                if unit ~= " " then
                    if manager:MeasureStringX(font, unit) <= limit then
                        line = unit
                    else
                        local unitIndex = 1
                        while unitIndex <= #unit do
                            local piece
                            piece, unitIndex = nextCharacter(unit, unitIndex)
                            if line ~= "" and manager:MeasureStringX(font, line .. piece) > limit then
                                lines[#lines + 1] = line
                                line = piece
                            else
                                line = line .. piece
                            end
                        end
                    end
                end
            end
        end
    end
    if line ~= "" or #lines == 0 then lines[#lines + 1] = line end
    return lines
end

function Text.wrapWordsLimited(value, width, font, maxLines)
    local lines = Text.wrapWords(value, width, font)
    if #lines <= maxLines then return lines end
    while #lines > maxLines do table.remove(lines) end
    local manager = getTextManager()
    local suffix = "..."
    while #suffix > 0 and manager:MeasureStringX(font, suffix) > width do suffix = suffix:sub(1, -2) end
    local clipped, index = "", 1
    local last = lines[maxLines]
    while index <= #last do
        local char
        char, index = nextCharacter(last, index)
        if manager:MeasureStringX(font, clipped .. char .. suffix) > width then break end
        clipped = clipped .. char
    end
    lines[maxLines] = clipped .. suffix
    return lines
end

return Text
